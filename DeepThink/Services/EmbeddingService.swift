import Foundation
import NaturalLanguage

/// Semantic search via Apple NaturalLanguage sentence embeddings.
/// Provides vector similarity search to complement ContextEngine's BM25 keyword search.
@Observable
final class EmbeddingService {
    static let shared = EmbeddingService()

    private(set) var isIndexing = false
    private(set) var indexedCount = 0
    private(set) var progress: Double = 0

    private var embeddings: [String: [Double]] = [:]   // entryID -> embedding vector
    private var contentHashes: [String: UInt64] = [:]   // entryID -> content hash for change detection
    private let embedding: NLEmbedding?
    private let persistURL: URL
    private let embeddingsURL: URL

    private init() {
        self.embedding = NLEmbedding.sentenceEmbedding(for: .english)
        self.persistURL = StorageService.shared.dataURL.appendingPathComponent("embedding_hashes.json")
        self.embeddingsURL = StorageService.shared.dataURL.appendingPathComponent("embeddings.json")
        loadFromDisk()
    }

    // MARK: - Embedding

    /// Generate embedding vector for text. Returns nil if NLEmbedding model is unavailable.
    func embed(_ text: String) -> [Double]? {
        guard let embedding else { return nil }
        return embedding.vector(for: text)
    }

    // MARK: - Indexing

    /// Index all knowledge entries incrementally (skip unchanged content).
    func indexEntries(_ entries: [KnowledgeEntry]) {
        isIndexing = true
        defer { isIndexing = false }

        var newCount = 0
        let total = entries.count

        for (i, entry) in entries.enumerated() {
            let hash = simpleHash(entry.content)

            // Skip if already indexed and content unchanged
            if let existingHash = contentHashes[entry.id], existingHash == hash {
                progress = Double(i + 1) / Double(total)
                continue
            }

            // Embed combined title + content (truncate for sentence embedding quality)
            let text = "\(entry.title). \(String(entry.content.prefix(500)))"
            if let vector = embed(text) {
                embeddings[entry.id] = vector
                contentHashes[entry.id] = hash
                newCount += 1
            }

            progress = Double(i + 1) / Double(total)
        }

        indexedCount = embeddings.count
        if newCount > 0 { saveToDisk() }
    }

    /// Remove entries no longer present in the knowledge base.
    func pruneStaleEntries(validIDs: Set<String>) {
        let stale = Set(embeddings.keys).subtracting(validIDs)
        for id in stale {
            embeddings.removeValue(forKey: id)
            contentHashes.removeValue(forKey: id)
        }
        if !stale.isEmpty { saveToDisk() }
    }

    // MARK: - Search

    /// Find entries most similar to query by cosine similarity.
    func search(query: String, topK: Int = 10, scope: [String]? = nil) -> [(entryID: String, score: Double)] {
        guard let queryVector = embed(query) else { return [] }

        var results: [(entryID: String, score: Double)] = []

        for (entryID, vector) in embeddings {
            // Optional scope filtering: if scope provided, entryID must contain one of the scope terms
            if let scope, !scope.isEmpty {
                let matchesScope = scope.contains { entryID.lowercased().contains($0.lowercased()) }
                if !matchesScope { continue }
            }

            let similarity = cosineSimilarity(queryVector, vector)
            if similarity > 0.3 {  // minimum relevance threshold
                results.append((entryID, similarity))
            }
        }

        return results
            .sorted { $0.score > $1.score }
            .prefix(topK)
            .map { $0 }
    }

    // MARK: - Math

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

    private func simpleHash(_ text: String) -> UInt64 {
        var hash: UInt64 = 5381
        for char in text.prefix(1000).utf8 {
            hash = hash &* 33 &+ UInt64(char)
        }
        return hash
    }

    // MARK: - Persistence

    private func saveToDisk() {
        // Save content hashes
        let hashStrings = contentHashes.mapValues { String($0) }
        if let hashData = try? JSONEncoder().encode(hashStrings) {
            try? hashData.write(to: persistURL)
        }

        // Save embeddings as JSON array of {id, v} pairs
        let pairs = embeddings.map { ["id": $0.key, "v": $0.value.map { String($0) }.joined(separator: ",")] }
        if let data = try? JSONSerialization.data(withJSONObject: pairs) {
            try? data.write(to: embeddingsURL)
        }
    }

    private func loadFromDisk() {
        // Load hashes
        if let data = try? Data(contentsOf: persistURL),
           let hashes = try? JSONDecoder().decode([String: String].self, from: data) {
            contentHashes = hashes.compactMapValues { UInt64($0) }
        }

        // Load embeddings
        guard let data = try? Data(contentsOf: embeddingsURL),
              let pairs = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            indexedCount = 0
            return
        }

        for pair in pairs {
            guard let id = pair["id"], let vStr = pair["v"] else { continue }
            let values = vStr.split(separator: ",").compactMap { Double($0) }
            if !values.isEmpty {
                embeddings[id] = values
            }
        }
        indexedCount = embeddings.count
    }
}
