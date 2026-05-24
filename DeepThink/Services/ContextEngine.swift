import Foundation

@Observable
final class ContextEngine {
    static let shared = ContextEngine()

    private(set) var isIndexing = false
    private(set) var indexedCount = 0
    private(set) var lastIndexedAt: Date?

    // TF-IDF index (in-memory for fast BM25)
    private var documentFrequency: [String: Int] = [:]
    private var documentTerms: [String: [String: Double]] = [:]
    private var documentCount = 0

    var vocabularySize: Int {
        documentFrequency.count
    }

    private var conversationSummaries: [UUID: String] = [:]
    private var contentFingerprints: Set<UInt64> = []

    private let store = VectorStore.shared
    let indexQueue = DispatchQueue(label: "com.deepthink.contextengine.index")

    private init() {}

    // MARK: - Index Building

    func rebuildIndex(with entries: [KnowledgeEntry]? = nil) {
        let allEntries = entries ?? KnowledgeService.shared.entries

        var newDocFreq: [String: Int] = [:]
        var newDocTerms: [String: [String: Double]] = [:]
        var newFingerprints: Set<UInt64> = []

        for entry in allEntries {
            let docID = entry.id
            let allText = "\(entry.title) \(entry.tags.joined(separator: " ")) \(entry.content)"
            let terms = tokenize(allText)
            let tf = computeTF(terms)
            newDocTerms[docID] = tf

            for term in tf.keys {
                newDocFreq[term, default: 0] += 1
            }

            newFingerprints.insert(fingerprint(entry.content))
        }

        DispatchQueue.main.async { [self] in
            documentFrequency = newDocFreq
            documentTerms = newDocTerms
            contentFingerprints = newFingerprints
            documentCount = allEntries.count
            indexedCount = allEntries.count
            lastIndexedAt = Date()
        }
    }

    // MARK: - Smart Retrieval (BM25 on VectorStore chunks)

    func retrieveContext(
        for query: String,
        maxTokens: Int = 4000,
        projectScope: String? = nil,
        agentScope: [String]? = nil
    ) -> ContextBundle {
        let queryTerms = tokenize(query)
        guard !queryTerms.isEmpty else { return ContextBundle.empty }

        let chunks = store.allChunks(entryType: "knowledge", scope: agentScope, excludeArchive: true)
        guard !chunks.isEmpty else { return ContextBundle.empty }

        let queryTF = computeTF(queryTerms)
        let querySet = Set(queryTerms)
        var scoredChunks: [(chunk: VectorChunk, score: Double)] = []

        let k1 = 1.5
        let b = 0.75
        let avgDocLen = Double(chunks.map(\.content.count).reduce(0, +)) / Double(chunks.count)

        for chunk in chunks {
            let docID = chunk.entryID
            guard let docTF = documentTerms[docID] else { continue }

            var score = 0.0
            let docLen = Double(chunk.content.count)

            for (term, queryFreq) in queryTF {
                let df = Double(documentFrequency[term] ?? 0)
                let idf = log((Double(documentCount) - df + 0.5) / (df + 0.5) + 1.0)
                let tf = docTF[term] ?? 0
                let tfNorm = (tf * (k1 + 1)) / (tf + k1 * (1 - b + b * docLen / avgDocLen))
                score += idf * tfNorm * queryFreq
            }

            let titleTerms = Set(tokenize(chunk.title))
            let titleOverlap = Double(titleTerms.intersection(querySet).count)
            if titleOverlap > 0 { score *= (1.0 + titleOverlap * 0.5) }

            let tagTerms = Set(chunk.tags.flatMap { tokenize($0) })
            let tagOverlap = Double(tagTerms.intersection(querySet).count)
            if tagOverlap > 0 { score *= (1.0 + tagOverlap * 0.3) }

            let daysSince = Date().timeIntervalSince(chunk.importedAt) / 86400
            let recencyMultiplier = exp(-daysSince / 90.0) * 0.3 + 0.7
            score *= recencyMultiplier

            if let project = projectScope {
                if chunk.title.localizedCaseInsensitiveContains(project) ||
                    chunk.tags.contains(where: { $0.caseInsensitiveCompare(project) == .orderedSame }) {
                    score *= 1.5
                }
            }

            if score > 0.1 { scoredChunks.append((chunk, score)) }
        }

        scoredChunks.sort { $0.score > $1.score }

        var usedEntries: Set<String> = []
        var selectedChunks: [(chunk: VectorChunk, score: Double)] = []

        let topScore = scoredChunks.first?.score ?? 0
        for item in scoredChunks {
            if usedEntries.contains(item.chunk.entryID) {
                if item.score > topScore * 0.7 {
                    selectedChunks.append(item)
                }
            } else {
                selectedChunks.append(item)
                usedEntries.insert(item.chunk.entryID)
            }
        }

        var charBudget = maxTokens * 4
        var contextParts: [ContextPart] = []

        for item in selectedChunks {
            let compressed = extractRelevantWindow(item.chunk.content, queryTerms: querySet, maxLen: min(800, charBudget))
            let partSize = compressed.count + item.chunk.title.count + 20
            if charBudget - partSize < 0 { break }

            contextParts.append(ContextPart(
                id: item.chunk.entryID,
                title: item.chunk.title,
                content: compressed,
                tags: item.chunk.tags,
                source: item.chunk.source,
                relevanceScore: item.score,
                chunkInfo: item.chunk.totalChunks > 1 ? "part \(item.chunk.chunkIndex + 1)/\(item.chunk.totalChunks)" : nil
            ))
            charBudget -= partSize
        }

        return ContextBundle(parts: contextParts, totalTokensEstimate: (maxTokens * 4 - charBudget) / 4)
    }

    // MARK: - Hybrid Retrieval (BM25 + Semantic via RRF)

    func retrieveContextHybrid(
        for query: String,
        maxTokens: Int = 4000,
        projectScope: String? = nil,
        agentScope: [String]? = nil
    ) -> ContextBundle {
        let bm25Bundle = retrieveContext(for: query, maxTokens: maxTokens * 2, projectScope: projectScope, agentScope: agentScope)
        let semanticResults = EmbeddingService.shared.search(query: query, topK: 20, scope: agentScope)

        guard !semanticResults.isEmpty else {
            return retrieveContext(for: query, maxTokens: maxTokens, projectScope: projectScope, agentScope: agentScope)
        }

        let chunks = store.allChunks(entryType: "knowledge", scope: agentScope, excludeArchive: true)
        var chunkByEntryID: [String: VectorChunk] = [:]
        for c in chunks where chunkByEntryID[c.entryID] == nil {
            chunkByEntryID[c.entryID] = c
        }

        let k = 60.0
        var fusedScores: [String: Double] = [:]
        var bm25PartByEntryID: [String: ContextPart] = [:]

        for (rank, part) in bm25Bundle.parts.enumerated() {
            let rrf = 1.0 / (k + Double(rank + 1))
            fusedScores[part.id, default: 0] += rrf
            if bm25PartByEntryID[part.id] == nil { bm25PartByEntryID[part.id] = part }
        }

        for (rank, result) in semanticResults.enumerated() {
            let rrf = 1.0 / (k + Double(rank + 1))
            fusedScores[result.entryID, default: 0] += rrf
        }

        let sorted = fusedScores.sorted { $0.value > $1.value }
        let queryTerms = Set(tokenize(query))

        var charBudget = maxTokens * 4
        var contextParts: [ContextPart] = []

        for (entryID, score) in sorted {
            if let existing = bm25PartByEntryID[entryID] {
                let partSize = existing.content.count + existing.title.count + 20
                if charBudget - partSize < 0 { break }
                contextParts.append(ContextPart(
                    id: existing.id,
                    title: existing.title,
                    content: existing.content,
                    tags: existing.tags,
                    source: existing.source,
                    relevanceScore: score * 100,
                    chunkInfo: existing.chunkInfo
                ))
                charBudget -= partSize
            } else if let chunk = chunkByEntryID[entryID] {
                let compressed = extractRelevantWindow(chunk.content, queryTerms: queryTerms, maxLen: min(800, charBudget))
                let partSize = compressed.count + chunk.title.count + 20
                if charBudget - partSize < 0 { break }
                contextParts.append(ContextPart(
                    id: chunk.entryID,
                    title: chunk.title,
                    content: compressed,
                    tags: chunk.tags,
                    source: chunk.source,
                    relevanceScore: score * 100,
                    chunkInfo: chunk.totalChunks > 1 ? "part \(chunk.chunkIndex + 1)/\(chunk.totalChunks)" : nil
                ))
                charBudget -= partSize
            }
        }

        return ContextBundle(parts: contextParts, totalTokensEstimate: (maxTokens * 4 - charBudget) / 4)
    }

    // MARK: - Format for Prompt

    func formatForPrompt(_ bundle: ContextBundle) -> String? {
        guard !bundle.parts.isEmpty else { return nil }

        var result = "# Relevant Knowledge\n\n"
        for part in bundle.parts {
            result += "## \(part.title)"
            if let chunk = part.chunkInfo { result += " (\(chunk))" }
            result += "\n"
            if !part.tags.isEmpty { result += "_Tags: \(part.tags.joined(separator: ", "))_\n" }
            result += part.content + "\n\n"
        }
        return result
    }

    // MARK: - In-memory BM25 search (no VectorStore required)

    func scoreEntries(for query: String) -> [String: Double] {
        let queryTerms = tokenize(query)
        guard !queryTerms.isEmpty, documentCount > 0 else { return [:] }
        let queryTF = computeTF(queryTerms)
        var scores: [String: Double] = [:]
        for (docID, docTF) in documentTerms {
            var score = 0.0
            for (term, queryFreq) in queryTF {
                let df = Double(documentFrequency[term] ?? 0)
                let idf = log((Double(documentCount) - df + 0.5) / (df + 0.5) + 1.0)
                let tf = docTF[term] ?? 0
                score += idf * tf * queryFreq
            }
            if score > 0 { scores[docID] = score }
        }
        return scores
    }

    // MARK: - Similarity Graph

    func similarityEdges(threshold: Double = 0.15) -> [(String, String, Double)] {
        let entries = Array(documentTerms)
        let n = Double(documentCount)

        func tfidfVec(_ tf: [String: Double]) -> [String: Double] {
            tf.reduce(into: [String: Double]()) { result, kv in
                let df = Double(documentFrequency[kv.key] ?? 1)
                result[kv.key] = kv.value * log((n + 1) / (df + 1))
            }
        }

        func magnitude(_ vec: [String: Double]) -> Double {
            sqrt(vec.values.reduce(0) { $0 + $1 * $1 })
        }

        var edges: [(String, String, Double)] = []
        let vecs = entries.map { (id: $0.0, vec: tfidfVec($0.1)) }

        for i in 0..<vecs.count {
            let a = vecs[i]
            let magA = magnitude(a.vec)
            guard magA > 0 else { continue }

            for j in (i + 1)..<vecs.count {
                let b = vecs[j]
                let magB = magnitude(b.vec)
                guard magB > 0 else { continue }

                var dot = 0.0
                for (term, valA) in a.vec {
                    if let valB = b.vec[term] { dot += valA * valB }
                }
                let sim = dot / (magA * magB)
                if sim >= threshold {
                    edges.append((a.id, b.id, sim))
                }
            }
        }
        return edges
    }

    // MARK: - Deduplication

    func isDuplicate(content: String) -> Bool {
        let fp = fingerprint(content)
        return contentFingerprints.contains(fp)
    }

    func isDuplicateOrSimilar(content: String, threshold: Double = 0.8) -> Bool {
        if isDuplicate(content: content) { return true }

        let newTerms = Set(tokenize(content))
        guard !newTerms.isEmpty else { return false }

        let chunks = store.allChunks(entryType: "knowledge")
        var checkedEntries: Set<String> = []
        for chunk in chunks {
            guard !checkedEntries.contains(chunk.entryID) else { continue }
            checkedEntries.insert(chunk.entryID)

            let existingTerms = Set(tokenize(chunk.content))
            guard !existingTerms.isEmpty else { continue }

            let intersection = Double(newTerms.intersection(existingTerms).count)
            let union = Double(newTerms.union(existingTerms).count)
            let jaccard = intersection / union

            if jaccard > threshold { return true }
        }
        return false
    }

    // MARK: - Conversation Summarization

    func summarizeConversation(messages: [AIMessage], maxTokens: Int = 500) async -> String? {
        let conversationText = messages
            .filter { $0.role != .error }
            .map { "\($0.role == .user ? "Q" : "A"): \($0.content.prefix(300))" }
            .joined(separator: "\n")

        guard !conversationText.isEmpty else { return nil }

        do {
            return try await ClaudeService.shared.query(
                "Summarize this conversation in under \(maxTokens / 4) words. " +
                    "Focus on: decisions made, questions asked, key facts discussed. Be extremely concise." +
                    "\n\n\(String(conversationText.prefix(4000)))",
                systemPrompt: "Output only a concise summary. No preamble. Use bullet points."
            )
        } catch {
            return nil
        }
    }

    func getCachedSummary(for conversationID: UUID) -> String? {
        conversationSummaries[conversationID]
    }

    func cacheSummary(_ summary: String, for conversationID: UUID) {
        conversationSummaries[conversationID] = summary
    }

    // MARK: - Smart Workspace Context

    func buildWorkspaceContext(notes: [any WorkspaceItem], tasks: [any WorkspaceItem], query: String, maxTokens: Int = 800) -> String {
        let queryTerms = Set(tokenize(query))
        var parts: [String] = []
        var budget = maxTokens * 4

        let scoredNotes = notes.prefix(20).map { note -> (any WorkspaceItem, Double) in
            let noteTerms = Set(tokenize("\(note.wsTitle) \(note.wsContent)"))
            let overlap = Double(queryTerms.intersection(noteTerms).count)
            let recency = max(0, 1.0 - Date().timeIntervalSince(note.wsModifiedAt) / (86400 * 7))
            return (note, overlap * 2.0 + recency)
        }.sorted { $0.1 > $1.1 }

        let relevantNotes = scoredNotes.prefix(3)
        if !relevantNotes.isEmpty {
            var noteCtx = "Recent Notes:\n"
            for (note, _) in relevantNotes {
                let line = "- \(note.wsTitle): \(String(note.wsContent.prefix(150)))\n"
                if budget - line.count < 0 { break }
                noteCtx += line
                budget -= line.count
            }
            parts.append(noteCtx)
        }

        let activeTasks = tasks.prefix(8)
        if !activeTasks.isEmpty {
            var taskCtx = "Active Tasks:\n"
            for task in activeTasks {
                let line = "- \(task.wsTitle)\n"
                if budget - line.count < 0 { break }
                taskCtx += line
                budget -= line.count
            }
            parts.append(taskCtx)
        }

        return parts.joined(separator: "\n")
    }

    // MARK: - Private Helpers

    private func stem(_ word: String) -> String {
        var w = word
        if w.count > 4, w.hasSuffix("sses") { return String(w.dropLast(2)) }
        if w.count > 4, w.hasSuffix("ies") { return String(w.dropLast(2)) }
        if w.count > 2, w.hasSuffix("s"), !w.hasSuffix("ss") { w = String(w.dropLast()) }
        if w.count > 6, w.hasSuffix("ational") { return String(w.dropLast(7)) + "ate" }
        if w.count > 5, w.hasSuffix("ation") { return String(w.dropLast(5)) + "ate" }
        if w.count > 4, w.hasSuffix("ness") { return String(w.dropLast(4)) }
        if w.count > 4, w.hasSuffix("ment") { return String(w.dropLast(4)) }
        if w.count > 4, w.hasSuffix("ting") { return String(w.dropLast(3)) }
        if w.count > 3, w.hasSuffix("ing") { return String(w.dropLast(3)) }
        if w.count > 3, w.hasSuffix("ely") { return String(w.dropLast(3)) }
        if w.count > 2, w.hasSuffix("ed") { return String(w.dropLast(2)) }
        if w.count > 2, w.hasSuffix("er") { return String(w.dropLast(2)) }
        if w.count > 2, w.hasSuffix("ly") { return String(w.dropLast(2)) }
        return w
    }

    private func tokenize(_ text: String) -> [String] {
        let stopWords: Set = [
            "the",
            "a",
            "an",
            "is",
            "are",
            "was",
            "were",
            "be",
            "been",
            "being",
            "have",
            "has",
            "had",
            "do",
            "does",
            "did",
            "will",
            "would",
            "could",
            "should",
            "may",
            "might",
            "shall",
            "can",
            "to",
            "of",
            "in",
            "for",
            "on",
            "with",
            "at",
            "by",
            "from",
            "as",
            "into",
            "through",
            "during",
            "before",
            "after",
            "above",
            "below",
            "between",
            "out",
            "off",
            "over",
            "under",
            "again",
            "further",
            "then",
            "once",
            "here",
            "there",
            "when",
            "where",
            "why",
            "how",
            "all",
            "each",
            "every",
            "both",
            "few",
            "more",
            "most",
            "other",
            "some",
            "such",
            "no",
            "nor",
            "not",
            "only",
            "own",
            "same",
            "so",
            "than",
            "too",
            "very",
            "just",
            "because",
            "but",
            "and",
            "or",
            "if",
            "while",
            "about",
            "up",
            "its",
            "it",
            "this",
            "that",
            "these",
            "those",
            "am",
            "what",
            "which",
            "who",
            "whom",
            "i",
            "me",
            "my",
            "we",
            "our",
            "you",
            "your",
            "he",
            "him",
            "his",
            "she",
            "her",
            "they",
            "them",
            "their",
            "need",
            "dare",
            "ought",
            "yet",
            "either",
            "neither",
            "any",
            "until",
            "down",
            "against",
            "myself",
            "ours",
            "ourselves",
            "yours",
            "yourself",
            "yourselves",
            "himself",
            "hers",
            "herself",
            "itself",
            "theirs",
            "themselves"
        ]

        return text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }
            .map { stem($0) }
    }

    private func computeTF(_ terms: [String]) -> [String: Double] {
        var freq: [String: Double] = [:]
        for term in terms {
            freq[term, default: 0] += 1
        }
        let maxFreq = freq.values.max() ?? 1
        for (key, val) in freq {
            freq[key] = val / maxFreq
        }
        return freq
    }

    private func extractRelevantWindow(_ content: String, queryTerms: Set<String>, maxLen: Int) -> String {
        if content.count <= maxLen { return content }

        let words = content.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let windowSize = max(1, maxLen / 5)

        if words.count <= windowSize { return String(content.prefix(maxLen)) }

        let hits = words.map { w -> Int in
            let t = stem(w.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).joined())
            return queryTerms.contains(t) ? 1 : 0
        }

        var windowScore = hits.prefix(windowSize).reduce(0, +)
        var bestStart = 0
        var bestScore = windowScore

        for i in 1...(words.count - windowSize) {
            windowScore += hits[i + windowSize - 1] - hits[i - 1]
            if windowScore > bestScore {
                bestScore = windowScore
                bestStart = i
            }
        }

        let selected = words[bestStart..<min(bestStart + windowSize, words.count)].joined(separator: " ")
        return selected.count > maxLen ? String(selected.prefix(maxLen)) : selected
    }

    private func fingerprint(_ text: String) -> UInt64 {
        var hash: UInt64 = 5381
        let normalized = text.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .prefix(1000)

        for char in normalized.utf8 {
            hash = hash &* 33 &+ UInt64(char)
        }
        return hash
    }
}

// MARK: - Models

struct ContextPart {
    let id: String
    let title: String
    let content: String
    let tags: [String]
    let source: String
    let relevanceScore: Double
    let chunkInfo: String?
}

struct ContextBundle {
    let parts: [ContextPart]
    let totalTokensEstimate: Int

    static let empty = ContextBundle(parts: [], totalTokensEstimate: 0)
}

protocol WorkspaceItem {
    var wsTitle: String { get }
    var wsContent: String { get }
    var wsModifiedAt: Date { get }
}
