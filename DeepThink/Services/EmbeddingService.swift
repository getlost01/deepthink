import Foundation
import NaturalLanguage
import SwiftData

@Observable
final class EmbeddingService {
    static let shared = EmbeddingService()

    private(set) var isIndexing = false
    private(set) var indexedCount = 0
    private(set) var progress: Double = 0

    private let nlEmbedding: NLEmbedding?
    private let store = VectorStore.shared
    private let embedQueue = DispatchQueue(label: "com.deepthink.embedding.nlp")
    private let drainQueue = DispatchQueue(label: "com.deepthink.embedding.drain", qos: .utility)
    private var reconcilerTask: Task<Void, Never>?

    private init() {
        nlEmbedding = NLEmbedding.sentenceEmbedding(for: .english)
        indexedCount = store.embeddedCount()
    }

    // MARK: - Embedding

    func embed(_ text: String) -> [Double]? {
        guard let nlEmbedding else { return nil }
        return embedQueue.sync {
            guard let vector = nlEmbedding.vector(for: text) else { return nil }
            guard !vector.contains(where: { $0.isNaN || $0.isInfinite }) else { return nil }
            return vector
        }
    }

    // MARK: - Knowledge Indexing

    func indexEntries(_ entries: [KnowledgeEntry]) {
        DispatchQueue.main.async { self.isIndexing = true }
        defer {
            let count = store.embeddedCount()
            DispatchQueue.main.async { self.isIndexing = false; self.indexedCount = count }
        }

        let total = entries.count
        for (i, entry) in entries.enumerated() {
            indexSingleEntry(entry)
            let p = Double(i + 1) / Double(total)
            DispatchQueue.main.async { self.progress = p }
        }

        store.pruneStaleEntries(
            validIDs: Set(entries.map(\.id)),
            entryType: "knowledge"
        )
    }

    func indexSingleEntry(_ entry: KnowledgeEntry) {
        let hash = simpleHash(entry.content)
        if let existing = store.contentHash(forEntry: entry.id), existing == hash {
            return
        }

        let chunks = SemanticChunker.chunk(
            text: entry.content,
            entryID: entry.id,
            entryType: "knowledge",
            title: entry.title,
            tags: entry.tags,
            source: entry.source,
            importedAt: entry.importedAt,
            contentHash: hash
        )

        let vectorChunks = chunks.map { chunk -> VectorChunk in
            let text = "\(entry.title). \(String(chunk.content.prefix(500)))"
            let embedding = embed(text)
            return VectorChunk(
                id: chunk.id, entryID: chunk.entryID, entryType: chunk.entryType,
                title: chunk.title, content: chunk.content, tags: chunk.tags,
                source: chunk.source, importedAt: chunk.importedAt,
                chunkIndex: chunk.chunkIndex, totalChunks: chunk.totalChunks,
                contentHash: chunk.contentHash, embedding: embedding
            )
        }

        store.replaceChunksForEntry(entry.id, with: vectorChunks)
    }

    func removeEntry(_ entryID: String) {
        store.deleteChunksForEntry(entryID)
        indexedCount = store.embeddedCount()
    }

    // MARK: - Workspace Indexing (Tasks, Notes, Reminders)

    func indexWorkspaceItem(
        id: String,
        type: String,
        title: String,
        content: String,
        tags: [String] = [],
        modifiedAt: Date = Date()
    ) throws {
        let hash = simpleHash(content)
        if let existing = store.contentHash(forEntry: id), existing == hash {
            return
        }

        let fullText = "\(title). \(content)"
        let chunks = SemanticChunker.chunk(
            text: fullText.count > 200 ? content : fullText,
            entryID: id,
            entryType: type,
            title: title,
            tags: tags,
            source: type,
            importedAt: modifiedAt,
            contentHash: hash
        )

        let vectorChunks = chunks.map { chunk -> VectorChunk in
            let embedding = embed("\(title). \(String(chunk.content.prefix(500)))")
            return VectorChunk(
                id: chunk.id, entryID: chunk.entryID, entryType: chunk.entryType,
                title: chunk.title, content: chunk.content, tags: chunk.tags,
                source: chunk.source, importedAt: chunk.importedAt,
                chunkIndex: chunk.chunkIndex, totalChunks: chunk.totalChunks,
                contentHash: chunk.contentHash, embedding: embedding
            )
        }

        if vectorChunks.allSatisfy({ $0.embedding == nil }) {
            throw EmbeddingError.allChunksFailed
        }

        store.replaceChunksForEntry(id, with: vectorChunks)
    }

    func indexWorkspaceItems(_ items: [(id: String, type: String, title: String, content: String, tags: [String], modifiedAt: Date)]) {
        DispatchQueue.main.async { self.isIndexing = true }
        defer {
            let count = store.embeddedCount()
            DispatchQueue.main.async { self.isIndexing = false; self.indexedCount = count }
        }

        let total = items.count
        for (i, item) in items.enumerated() {
            do {
                try indexWorkspaceItem(
                    id: item.id, type: item.type, title: item.title,
                    content: item.content, tags: item.tags, modifiedAt: item.modifiedAt
                )
            } catch {
                VectorStore.shared.enqueuePendingReindex(entryID: item.id, entryType: item.type)
            }
            let p = Double(i + 1) / Double(total)
            DispatchQueue.main.async { self.progress = p }
        }
    }

    // MARK: - Pending Reindex Drain

    func drainPendingReindex(container: ModelContainer) {
        drainQueue.async {
            let pending = VectorStore.shared.fetchPendingReindex(maxRetries: 3)
            guard !pending.isEmpty else { return }

            let context = ModelContext(container)

            for row in pending {
                do {
                    if row.operation == "delete" {
                        VectorStore.shared.deleteChunksForEntry(row.entryID)
                        VectorStore.shared.deletePendingReindex(entryID: row.entryID)
                        continue
                    }

                    let parts = row.entryID.split(separator: ":", maxSplits: 1)
                    guard parts.count == 2, let uuid = UUID(uuidString: String(parts[1])) else {
                        VectorStore.shared.deletePendingReindex(entryID: row.entryID)
                        continue
                    }

                    switch row.entryType {
                    case "task":
                        let tasks = (try? context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == uuid }))) ?? []
                        guard let task = tasks.first else {
                            // Item deleted — clean up any orphaned chunks
                            VectorStore.shared.deleteChunksForEntry(row.entryID)
                            VectorStore.shared.deletePendingReindex(entryID: row.entryID)
                            continue
                        }
                        try self.indexWorkspaceItem(
                            id: row.entryID, type: "task",
                            title: task.title,
                            content: Self.taskContent(title: task.title, detail: task.detail, status: task.statusRaw, isArchived: task.isArchived),
                            tags: task.tags.map(\.name), modifiedAt: task.modifiedAt
                        )
                    case "note":
                        let notes = (try? context.fetch(FetchDescriptor<Note>(predicate: #Predicate { $0.id == uuid }))) ?? []
                        guard let note = notes.first else {
                            VectorStore.shared.deleteChunksForEntry(row.entryID)
                            VectorStore.shared.deletePendingReindex(entryID: row.entryID)
                            continue
                        }
                        try self.indexWorkspaceItem(
                            id: row.entryID, type: "note",
                            title: note.title,
                            content: Self.noteContent(title: note.title, content: note.content, isArchived: note.isArchived),
                            tags: note.tags.map(\.name), modifiedAt: note.modifiedAt
                        )
                    case "reminder":
                        let reminders = (try? context.fetch(FetchDescriptor<Reminder>(predicate: #Predicate { $0.id == uuid }))) ?? []
                        guard let reminder = reminders.first else {
                            VectorStore.shared.deleteChunksForEntry(row.entryID)
                            VectorStore.shared.deletePendingReindex(entryID: row.entryID)
                            continue
                        }
                        try self.indexWorkspaceItem(
                            id: row.entryID, type: "reminder",
                            title: reminder.title,
                            content: Self.reminderContent(title: reminder.title, notes: reminder.notes, isCompleted: reminder.isCompleted),
                            modifiedAt: reminder.modifiedAt
                        )
                    default:
                        VectorStore.shared.deletePendingReindex(entryID: row.entryID)
                        continue
                    }
                    VectorStore.shared.deletePendingReindex(entryID: row.entryID)
                } catch {
                    VectorStore.shared.incrementPendingRetry(entryID: row.entryID)
                }
            }

            let count = VectorStore.shared.embeddedCount()
            DispatchQueue.main.async { self.indexedCount = count }
        }
    }

    func startReconcilerTimer(container: ModelContainer) {
        reconcilerTask?.cancel()
        reconcilerTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { break }
                drainPendingReindex(container: container)
            }
        }
    }

    // MARK: - Content String Builders (canonical — keep in sync with TypeScript side)

    static func taskContent(title: String, detail: String, status: String, isArchived: Bool) -> String {
        "\(title)\n\(detail)\nstatus:\(status)\narchived:\(isArchived)"
    }

    static func noteContent(title: String, content: String, isArchived: Bool) -> String {
        "\(title)\n\(content)\narchived:\(isArchived)"
    }

    static func reminderContent(title: String, notes: String, isCompleted: Bool) -> String {
        "\(title)\n\(notes)\ncompleted:\(isCompleted)"
    }

    // MARK: - Search

    func search(query: String, topK: Int = 10, scope: [String]? = nil, entryType: String? = nil) -> [(entryID: String, score: Double)] {
        guard let queryVector = embed(query) else { return [] }

        let entries = store.chunksWithEmbeddings(entryType: entryType, scope: scope)
        var bestScores: [String: Double] = [:]

        for (chunk, embedding) in entries {
            let similarity = cosineSimilarity(queryVector, embedding)
            if similarity > 0.3 {
                let current = bestScores[chunk.entryID] ?? 0
                if similarity > current {
                    bestScores[chunk.entryID] = similarity
                }
            }
        }

        return bestScores
            .map { (entryID: $0.key, score: $0.value) }
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map(\.self)
    }

    // MARK: - Stats

    var stats: (total: Int, embedded: Int, knowledge: Int, tasks: Int, notes: Int, reminders: Int) {
        (
            total: store.chunkCount(),
            embedded: store.embeddedCount(),
            knowledge: store.entryCount(entryType: "knowledge"),
            tasks: store.entryCount(entryType: "task"),
            notes: store.entryCount(entryType: "note"),
            reminders: store.entryCount(entryType: "reminder")
        )
    }

    // MARK: - Private

    private func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot = 0.0, normA = 0.0, normB = 0.0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        return denom > 0 ? dot / denom : 0
    }

    // 32-bit djb2 addition over UTF-8 bytes — matches TypeScript's simpleHash exactly.
    private func simpleHash(_ text: String) -> UInt64 {
        var hash: UInt32 = 5381
        for byte in text.utf8 {
            hash = hash &* 33 &+ UInt32(byte)
        }
        return UInt64(hash)
    }
}

// MARK: - Errors

enum EmbeddingError: Error {
    case allChunksFailed
}

// MARK: - Semantic Chunker

enum SemanticChunker {
    static let maxChunkSize = 500
    static let minChunkSize = 100

    static func chunk(
        text: String,
        entryID: String,
        entryType: String,
        title: String,
        tags: [String],
        source: String,
        importedAt: Date,
        contentHash: UInt64
    ) -> [VectorChunk] {
        let sentences = splitSentences(text)
        guard !sentences.isEmpty else {
            return [VectorChunk(
                id: "\(entryID):0", entryID: entryID, entryType: entryType,
                title: title, content: text, tags: tags, source: source,
                importedAt: importedAt, chunkIndex: 0, totalChunks: 1,
                contentHash: contentHash, embedding: nil
            )]
        }

        var groups: [[String]] = []
        var current: [String] = []
        var currentLen = 0

        for sentence in sentences {
            if currentLen + sentence.count > maxChunkSize, !current.isEmpty {
                groups.append(current)
                // Overlap: keep last sentence
                let last = current.last ?? ""
                current = last.count < maxChunkSize / 2 ? [last] : []
                currentLen = current.reduce(0) { $0 + $1.count }
            }
            current.append(sentence)
            currentLen += sentence.count
        }

        if !current.isEmpty {
            if currentLen < minChunkSize, let last = groups.last {
                groups[groups.count - 1] = last + current
            } else {
                groups.append(current)
            }
        }

        let totalChunks = groups.count
        return groups.enumerated().map { index, group in
            VectorChunk(
                id: "\(entryID):\(index)",
                entryID: entryID, entryType: entryType,
                title: title, content: group.joined(separator: " "),
                tags: tags, source: source, importedAt: importedAt,
                chunkIndex: index, totalChunks: totalChunks,
                contentHash: contentHash, embedding: nil
            )
        }
    }

    private static func splitSentences(_ text: String) -> [String] {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: [.bySentences, .localized]) { substring, _, _, _ in
            if let s = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
                sentences.append(s)
            }
        }
        if sentences.isEmpty, !text.isEmpty {
            return text.components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }
        return sentences
    }
}
