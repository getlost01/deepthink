import Foundation

/// Smart context engine with TF-IDF indexing, chunking, token budgeting, and deduplication.
/// Replaces naive keyword matching with proper relevance scoring.
@Observable
final class ContextEngine {
    static let shared = ContextEngine()

    private(set) var isIndexing = false
    private(set) var indexedCount = 0
    private(set) var lastIndexedAt: Date?

    // TF-IDF index
    private var documentFrequency: [String: Int] = [:]
    private var documentTerms: [String: [String: Double]] = [:] // docID -> term -> TF
    private var documentCount = 0

    // Chunk index for large entries
    private var chunks: [ContentChunk] = []

    // Conversation summaries cache
    private var conversationSummaries: [UUID: String] = [:]

    // Dedup fingerprints
    private var contentFingerprints: Set<UInt64> = []

    private let chunkSize = 600
    private let chunkOverlap = 100
    let indexQueue = DispatchQueue(label: "com.deepthink.contextengine.index")

    private init() {}

    // MARK: - Index Building

    func rebuildIndex(with entries: [KnowledgeEntry]? = nil) {
        let allEntries = entries ?? KnowledgeService.shared.entries

        var newDocFreq: [String: Int] = [:]
        var newDocTerms: [String: [String: Double]] = [:]
        var newChunks: [ContentChunk] = []
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

            if entry.content.count > chunkSize {
                let entryChunks = chunkContent(entry)
                newChunks.append(contentsOf: entryChunks)
            } else {
                newChunks.append(ContentChunk(
                    entryID: docID,
                    entryTitle: entry.title,
                    content: entry.content,
                    tags: entry.tags,
                    source: entry.source,
                    importedAt: entry.importedAt,
                    chunkIndex: 0,
                    totalChunks: 1
                ))
            }

            newFingerprints.insert(fingerprint(entry.content))
        }

        DispatchQueue.main.async { [self] in
            documentFrequency = newDocFreq
            documentTerms = newDocTerms
            chunks = newChunks
            contentFingerprints = newFingerprints
            documentCount = allEntries.count
            indexedCount = allEntries.count
            lastIndexedAt = Date()
        }
    }

    // MARK: - Smart Retrieval (TF-IDF + BM25-inspired)

    func retrieveContext(
        for query: String,
        maxTokens: Int = 4000,
        projectScope: String? = nil,
        agentScope: [String]? = nil
    ) -> ContextBundle {
        let queryTerms = tokenize(query)
        guard !queryTerms.isEmpty else { return ContextBundle.empty }

        let queryTF = computeTF(queryTerms)
        var scoredChunks: [(chunk: ContentChunk, score: Double)] = []

        let k1 = 1.5
        let b = 0.75
        let avgDocLen = chunks.isEmpty ? 1.0 : Double(chunks.map(\.content.count).reduce(0, +)) / Double(chunks.count)

        for chunk in chunks {
            // Apply scope filters
            if let scope = agentScope, !scope.isEmpty {
                let matchesScope = scope.contains { s in
                    chunk.source.contains(s) || chunk.tags.contains(s) || chunk.entryTitle.lowercased().contains(s.lowercased())
                }
                if !matchesScope { continue }
            }

            if let project = projectScope {
                if !chunk.entryTitle.lowercased().contains(project.lowercased()) &&
                   !chunk.tags.contains(where: { $0.lowercased() == project.lowercased() }) {
                    // Soft filter — reduce score but don't exclude
                }
            }

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

            // Title boost
            let titleTerms = Set(tokenize(chunk.entryTitle))
            let querySet = Set(queryTerms)
            let titleOverlap = Double(titleTerms.intersection(querySet).count)
            if titleOverlap > 0 {
                score *= (1.0 + titleOverlap * 0.5)
            }

            // Tag boost
            let tagTerms = Set(chunk.tags.flatMap { tokenize($0) })
            let tagOverlap = Double(tagTerms.intersection(querySet).count)
            if tagOverlap > 0 {
                score *= (1.0 + tagOverlap * 0.3)
            }

            // Recency boost (exponential decay)
            let daysSince = Date().timeIntervalSince(chunk.importedAt) / 86400
            let recencyMultiplier = exp(-daysSince / 90.0) * 0.3 + 0.7 // decays from 1.0 to 0.7 over ~90 days
            score *= recencyMultiplier

            // Project scope boost
            if let project = projectScope {
                if chunk.entryTitle.lowercased().contains(project.lowercased()) ||
                   chunk.tags.contains(where: { $0.lowercased() == project.lowercased() }) {
                    score *= 1.5
                }
            }

            if score > 0.1 {
                scoredChunks.append((chunk, score))
            }
        }

        scoredChunks.sort { $0.score > $1.score }

        // Deduplicate: don't include multiple chunks from same entry unless very relevant
        var usedEntries: Set<String> = []
        var selectedChunks: [(chunk: ContentChunk, score: Double)] = []

        for item in scoredChunks {
            if usedEntries.contains(item.chunk.entryID) {
                if item.score > scoredChunks.first!.score * 0.7 {
                    selectedChunks.append(item)
                }
            } else {
                selectedChunks.append(item)
                usedEntries.insert(item.chunk.entryID)
            }
        }

        // Token budget
        var charBudget = maxTokens * 4
        var contextParts: [ContextPart] = []

        for item in selectedChunks {
            let compressed = compressChunk(item.chunk, budget: min(800, charBudget))
            let partSize = compressed.count + item.chunk.entryTitle.count + 20
            if charBudget - partSize < 0 { break }

            contextParts.append(ContextPart(
                title: item.chunk.entryTitle,
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
        // 1. Get BM25 results (existing keyword search)
        let bm25Bundle = retrieveContext(for: query, maxTokens: maxTokens * 2, projectScope: projectScope, agentScope: agentScope)

        // 2. Get semantic results
        let semanticResults = EmbeddingService.shared.search(query: query, topK: 20)

        // 3. If no semantic results, fall back to BM25 only
        guard !semanticResults.isEmpty else {
            return retrieveContext(for: query, maxTokens: maxTokens, projectScope: projectScope, agentScope: agentScope)
        }

        // 4. Reciprocal Rank Fusion
        let k = 60.0
        var fusedScores: [String: Double] = [:]     // entryTitle -> fused score
        var titleToChunk: [String: ContentChunk] = [:]

        // BM25 rankings
        for (rank, part) in bm25Bundle.parts.enumerated() {
            let rrf = 1.0 / (k + Double(rank + 1))
            fusedScores[part.title, default: 0] += rrf
        }

        // Semantic rankings - map entryID back to chunks
        for (rank, result) in semanticResults.enumerated() {
            if let chunk = chunks.first(where: { $0.entryID == result.entryID }) {
                let rrf = 1.0 / (k + Double(rank + 1))
                fusedScores[chunk.entryTitle, default: 0] += rrf
                if titleToChunk[chunk.entryTitle] == nil {
                    titleToChunk[chunk.entryTitle] = chunk
                }
            }
        }

        // 5. Sort by fused score, build ContextBundle within token budget
        let sorted = fusedScores.sorted { $0.value > $1.value }

        var charBudget = maxTokens * 4
        var contextParts: [ContextPart] = []

        for (title, score) in sorted {
            // Prefer BM25 result (already has compressed content)
            if let existing = bm25Bundle.parts.first(where: { $0.title == title }) {
                let partSize = existing.content.count + title.count + 20
                if charBudget - partSize < 0 { break }
                contextParts.append(ContextPart(
                    title: existing.title,
                    content: existing.content,
                    tags: existing.tags,
                    source: existing.source,
                    relevanceScore: score * 100,
                    chunkInfo: existing.chunkInfo
                ))
                charBudget -= partSize
            } else if let chunk = titleToChunk[title] {
                // Semantic-only result (not in BM25 top results)
                let compressed = compressChunk(chunk, budget: min(800, charBudget))
                let partSize = compressed.count + title.count + 20
                if charBudget - partSize < 0 { break }
                contextParts.append(ContextPart(
                    title: chunk.entryTitle,
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

    // MARK: - Deduplication

    func isDuplicate(content: String) -> Bool {
        let fp = fingerprint(content)
        return contentFingerprints.contains(fp)
    }

    func isDuplicateOrSimilar(content: String, threshold: Double = 0.8) -> Bool {
        if isDuplicate(content: content) { return true }

        let newTerms = Set(tokenize(content))
        guard !newTerms.isEmpty else { return false }

        // Compare against indexed chunks (already in memory, no Observable access)
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
                "Summarize this conversation in under \(maxTokens / 4) words. Focus on: decisions made, questions asked, key facts discussed. Be extremely concise.\n\n\(String(conversationText.prefix(4000)))",
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

        // Score notes by query relevance instead of just recency
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

    private func tokenize(_ text: String) -> [String] {
        let stopWords: Set<String> = ["the", "a", "an", "is", "are", "was", "were", "be", "been", "being",
            "have", "has", "had", "do", "does", "did", "will", "would", "could", "should",
            "may", "might", "shall", "can", "to", "of", "in", "for", "on", "with", "at",
            "by", "from", "as", "into", "through", "during", "before", "after", "above",
            "below", "between", "out", "off", "over", "under", "again", "further", "then",
            "once", "here", "there", "when", "where", "why", "how", "all", "each", "every",
            "both", "few", "more", "most", "other", "some", "such", "no", "nor", "not",
            "only", "own", "same", "so", "than", "too", "very", "just", "because", "but",
            "and", "or", "if", "while", "about", "up", "its", "it", "this", "that", "these",
            "those", "am", "what", "which", "who", "whom", "i", "me", "my", "we", "our", "you", "your",
            "he", "him", "his", "she", "her", "they", "them", "their"]

        return text.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count > 2 && !stopWords.contains($0) }
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

    private func chunkContent(_ entry: KnowledgeEntry) -> [ContentChunk] {
        let text = entry.content
        var result: [ContentChunk] = []
        var start = text.startIndex

        var index = 0
        while start < text.endIndex {
            let endOffset = text.index(start, offsetBy: chunkSize, limitedBy: text.endIndex) ?? text.endIndex

            // Try to break at sentence boundary
            var end = endOffset
            if end < text.endIndex {
                let searchRange = text.index(end, offsetBy: -100, limitedBy: start) ?? start
                if let sentenceEnd = text[searchRange..<endOffset].lastIndex(where: { $0 == "." || $0 == "\n" }) {
                    end = text.index(after: sentenceEnd)
                }
            }

            let chunk = String(text[start..<end])
            result.append(ContentChunk(
                entryID: entry.id,
                entryTitle: entry.title,
                content: chunk,
                tags: entry.tags,
                source: entry.source,
                importedAt: entry.importedAt,
                chunkIndex: index,
                totalChunks: 0 // will fix after
            ))

            // Move start with overlap
            let overlapOffset = text.index(end, offsetBy: -chunkOverlap, limitedBy: start) ?? start
            start = max(overlapOffset, text.index(after: start))
            if start >= text.endIndex { break }
            index += 1
        }

        let total = result.count
        return result.map {
            ContentChunk(entryID: $0.entryID, entryTitle: $0.entryTitle, content: $0.content,
                        tags: $0.tags, source: $0.source, importedAt: $0.importedAt,
                        chunkIndex: $0.chunkIndex, totalChunks: total)
        }
    }

    private func compressChunk(_ chunk: ContentChunk, budget: Int) -> String {
        let content = chunk.content
        if content.count <= budget { return content }

        // Smart truncation: prefer complete sentences
        let truncated = String(content.prefix(budget))
        if let lastSentence = truncated.lastIndex(where: { $0 == "." || $0 == "\n" }) {
            return String(truncated[...lastSentence])
        }
        return truncated + "..."
    }

    private func fingerprint(_ text: String) -> UInt64 {
        // Simple hash fingerprint for dedup
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

struct ContentChunk {
    let entryID: String
    let entryTitle: String
    let content: String
    let tags: [String]
    let source: String
    let importedAt: Date
    let chunkIndex: Int
    let totalChunks: Int
}

struct ContextPart {
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
