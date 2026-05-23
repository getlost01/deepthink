import Foundation
import SQLite3

final class VectorStore {
    static let shared = VectorStore()

    private var db: OpaquePointer?
    private let dbPath: String
    private let queue = DispatchQueue(label: "com.deepthink.vectorstore", attributes: .concurrent)

    private init() {
        dbPath = StorageService.shared.dataURL
            .appendingPathComponent("vectors.db").path
        openDatabase()
        createTables()
        migrate()
    }

    deinit {
        sqlite3_close(db)
    }

    // MARK: - Setup

    private func openDatabase() {
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(dbPath, &db, flags, nil) != SQLITE_OK {
            let err = String(cString: sqlite3_errmsg(db))
            StorageService.shared.writeLog("VectorStore open failed: \(err)", to: "vectorstore")
        }
        exec("PRAGMA journal_mode=WAL")
        exec("PRAGMA synchronous=NORMAL")
        exec("PRAGMA cache_size=-8000")
        exec("PRAGMA busy_timeout=5000")
    }

    private func createTables() {
        exec("""
            CREATE TABLE IF NOT EXISTS chunks (
                id TEXT PRIMARY KEY,
                entry_id TEXT NOT NULL,
                entry_type TEXT NOT NULL DEFAULT 'knowledge',
                title TEXT NOT NULL,
                content TEXT NOT NULL,
                tags TEXT DEFAULT '[]',
                source TEXT DEFAULT '',
                imported_at REAL NOT NULL,
                chunk_index INTEGER NOT NULL DEFAULT 0,
                total_chunks INTEGER NOT NULL DEFAULT 1,
                content_hash INTEGER NOT NULL DEFAULT 0,
                embedding BLOB
            )
        """)
        exec("CREATE INDEX IF NOT EXISTS idx_chunks_entry_id ON chunks(entry_id)")
        exec("CREATE INDEX IF NOT EXISTS idx_chunks_entry_type ON chunks(entry_type)")
        exec("CREATE INDEX IF NOT EXISTS idx_chunks_source ON chunks(source)")
        exec("CREATE INDEX IF NOT EXISTS idx_chunks_hash ON chunks(content_hash)")

        exec("""
            CREATE TABLE IF NOT EXISTS meta (
                key TEXT PRIMARY KEY,
                value TEXT
            )
        """)

        exec("""
            CREATE TABLE IF NOT EXISTS pending_reindex (
                entry_id    TEXT PRIMARY KEY,
                entry_type  TEXT NOT NULL,
                operation   TEXT NOT NULL DEFAULT 'upsert',
                queued_at   INTEGER NOT NULL,
                retry_count INTEGER NOT NULL DEFAULT 0
            )
        """)
    }

    private func migrate() {
        let version = getMeta("schema_version").flatMap(Int.init) ?? 0
        if version < 1 {
            setMeta("schema_version", "1")
            setMeta("created_at", ISO8601DateFormatter().string(from: Date()))
        }
    }

    // MARK: - Chunk CRUD

    func upsertChunk(_ chunk: VectorChunk) {
        queue.sync(flags: .barrier) {
            let sql = """
                INSERT OR REPLACE INTO chunks
                (id, entry_id, entry_type, title, content, tags, source, imported_at, chunk_index, total_chunks, content_hash, embedding)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, chunk.id.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_text(stmt, 2, chunk.entryID.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_text(stmt, 3, chunk.entryType.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_text(stmt, 4, chunk.title.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_text(stmt, 5, chunk.content.cString, -1, SQLITE_TRANSIENT_PTR)

            let tagsJSON = (try? JSONSerialization.data(withJSONObject: chunk.tags))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            sqlite3_bind_text(stmt, 6, tagsJSON.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_text(stmt, 7, chunk.source.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_double(stmt, 8, chunk.importedAt.timeIntervalSince1970)
            sqlite3_bind_int(stmt, 9, Int32(chunk.chunkIndex))
            sqlite3_bind_int(stmt, 10, Int32(chunk.totalChunks))
            sqlite3_bind_int64(stmt, 11, Int64(bitPattern: chunk.contentHash))

            if let embedding = chunk.embedding {
                bindEmbedding(embedding, to: stmt, at: 12)
            } else {
                sqlite3_bind_null(stmt, 12)
            }

            sqlite3_step(stmt)
        }
    }

    func upsertChunks(_ chunks: [VectorChunk]) {
        queue.sync(flags: .barrier) {
            exec("BEGIN TRANSACTION")
            for chunk in chunks {
                upsertChunkUnsafe(chunk)
            }
            exec("COMMIT")
        }
    }

    private func upsertChunkUnsafe(_ chunk: VectorChunk) {
        let sql = """
            INSERT OR REPLACE INTO chunks
            (id, entry_id, entry_type, title, content, tags, source, imported_at, chunk_index, total_chunks, content_hash, embedding)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, chunk.id.cString, -1, SQLITE_TRANSIENT_PTR)
        sqlite3_bind_text(stmt, 2, chunk.entryID.cString, -1, SQLITE_TRANSIENT_PTR)
        sqlite3_bind_text(stmt, 3, chunk.entryType.cString, -1, SQLITE_TRANSIENT_PTR)
        sqlite3_bind_text(stmt, 4, chunk.title.cString, -1, SQLITE_TRANSIENT_PTR)
        sqlite3_bind_text(stmt, 5, chunk.content.cString, -1, SQLITE_TRANSIENT_PTR)

        let tagsJSON = (try? JSONSerialization.data(withJSONObject: chunk.tags))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        sqlite3_bind_text(stmt, 6, tagsJSON.cString, -1, SQLITE_TRANSIENT_PTR)
        sqlite3_bind_text(stmt, 7, chunk.source.cString, -1, SQLITE_TRANSIENT_PTR)
        sqlite3_bind_double(stmt, 8, chunk.importedAt.timeIntervalSince1970)
        sqlite3_bind_int(stmt, 9, Int32(chunk.chunkIndex))
        sqlite3_bind_int(stmt, 10, Int32(chunk.totalChunks))
        sqlite3_bind_int64(stmt, 11, Int64(bitPattern: chunk.contentHash))

        if let embedding = chunk.embedding {
            bindEmbedding(embedding, to: stmt, at: 12)
        } else {
            sqlite3_bind_null(stmt, 12)
        }

        sqlite3_step(stmt)
    }

    private func bindEmbedding(_ embedding: [Double], to stmt: OpaquePointer?, at index: Int32) {
        let data = embeddingToBlob(embedding)
        _ = data.withUnsafeBytes { ptr in
            sqlite3_bind_blob(stmt, index, ptr.baseAddress, Int32(data.count), SQLITE_TRANSIENT_PTR)
        }
    }

    func deleteChunksForEntry(_ entryID: String) {
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            let sql = "DELETE FROM chunks WHERE entry_id = ?"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, entryID.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_step(stmt)
        }
    }

    func replaceChunksForEntry(_ entryID: String, with chunks: [VectorChunk]) {
        queue.sync(flags: .barrier) {
            exec("BEGIN TRANSACTION")
            var delStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "DELETE FROM chunks WHERE entry_id = ?", -1, &delStmt, nil) == SQLITE_OK {
                sqlite3_bind_text(delStmt, 1, entryID.cString, -1, SQLITE_TRANSIENT_PTR)
                sqlite3_step(delStmt)
                sqlite3_finalize(delStmt)
            }
            for chunk in chunks { upsertChunkUnsafe(chunk) }
            exec("COMMIT")
        }
    }

    func deleteChunksByType(_ entryType: String) {
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            let sql = "DELETE FROM chunks WHERE entry_type = ?"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, entryType.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_step(stmt)
        }
    }

    func pruneStaleEntries(validIDs: Set<String>, entryType: String) {
        let existing = allEntryIDs(forType: entryType)
        let stale = existing.subtracting(validIDs)
        guard !stale.isEmpty else { return }

        queue.sync(flags: .barrier) {
            exec("BEGIN TRANSACTION")
            for id in stale {
                var stmt: OpaquePointer?
                let sql = "DELETE FROM chunks WHERE entry_id = ? AND entry_type = ?"
                guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { continue }
                sqlite3_bind_text(stmt, 1, id.cString, -1, SQLITE_TRANSIENT_PTR)
                sqlite3_bind_text(stmt, 2, entryType.cString, -1, SQLITE_TRANSIENT_PTR)
                sqlite3_step(stmt)
                sqlite3_finalize(stmt)
            }
            exec("COMMIT")
        }
    }

    // MARK: - Pending Reindex Queue

    func enqueuePendingReindex(entryID: String, entryType: String, operation: String = "upsert") {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            let sql = "INSERT OR REPLACE INTO pending_reindex (entry_id, entry_type, operation, queued_at, retry_count) VALUES (?, ?, ?, ?, 0)"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, entryID.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_text(stmt, 2, entryType.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_text(stmt, 3, operation.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_bind_int64(stmt, 4, Int64(Date().timeIntervalSince1970 * 1000))
            sqlite3_step(stmt)
        }
    }

    func fetchPendingReindex(maxRetries: Int = 3) -> [PendingReindexRow] {
        var results: [PendingReindexRow] = []
        queue.sync {
            let sql = "SELECT entry_id, entry_type, operation, queued_at, retry_count FROM pending_reindex WHERE retry_count < ? ORDER BY queued_at ASC"
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_int(stmt, 1, Int32(maxRetries))
            while sqlite3_step(stmt) == SQLITE_ROW {
                let entryID = String(cString: sqlite3_column_text(stmt, 0))
                let entryType = String(cString: sqlite3_column_text(stmt, 1))
                let operation = String(cString: sqlite3_column_text(stmt, 2))
                let retryCount = Int(sqlite3_column_int(stmt, 4))
                results.append(PendingReindexRow(entryID: entryID, entryType: entryType, operation: operation, retryCount: retryCount))
            }
        }
        return results
    }

    func deletePendingReindex(entryID: String) {
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "DELETE FROM pending_reindex WHERE entry_id = ?", -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, entryID.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_step(stmt)
        }
    }

    func incrementPendingRetry(entryID: String) {
        queue.sync(flags: .barrier) {
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, "UPDATE pending_reindex SET retry_count = retry_count + 1 WHERE entry_id = ?", -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }
            sqlite3_bind_text(stmt, 1, entryID.cString, -1, SQLITE_TRANSIENT_PTR)
            sqlite3_step(stmt)
        }
    }

    // MARK: - Query

    func contentHash(forEntry entryID: String) -> UInt64? {
        var stmt: OpaquePointer?
        let sql = "SELECT content_hash FROM chunks WHERE entry_id = ? LIMIT 1"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, entryID.cString, -1, SQLITE_TRANSIENT_PTR)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return UInt64(bitPattern: sqlite3_column_int64(stmt, 0))
    }

    func allChunks(
        entryType: String? = nil,
        source: String? = nil,
        scope: [String]? = nil,
        excludeArchive: Bool = false
    ) -> [VectorChunk] {
        var conditions: [String] = []
        var params: [String] = []

        if let entryType {
            conditions.append("entry_type = ?")
            params.append(entryType)
        }
        if let source {
            conditions.append("source = ?")
            params.append(source)
        }
        if excludeArchive {
            conditions.append("source != ?")
            params.append("archive")
        }

        var sql = "SELECT id, entry_id, entry_type, title, content, tags, source, imported_at, chunk_index, total_chunks, content_hash, embedding FROM chunks"
        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        for (i, param) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), param.cString, -1, SQLITE_TRANSIENT_PTR)
        }

        var results: [VectorChunk] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let chunk = readChunkRow(stmt)

            if let scope, !scope.isEmpty {
                let matches = scope.contains { s in
                    let sl = s.lowercased()
                    return chunk.source.lowercased().contains(sl) ||
                        chunk.tags.contains { $0.lowercased().contains(sl) } ||
                        chunk.title.lowercased().contains(sl)
                }
                if !matches { continue }
            }

            results.append(chunk)
        }
        return results
    }

    func chunksWithEmbeddings(
        entryType: String? = nil,
        scope: [String]? = nil
    ) -> [(chunk: VectorChunk, embedding: [Double])] {
        var conditions = ["embedding IS NOT NULL"]
        var params: [String] = []

        if let entryType {
            conditions.append("entry_type = ?")
            params.append(entryType)
        }

        let sql =
            "SELECT id, entry_id, entry_type, title, content, tags, source, imported_at, chunk_index, total_chunks, content_hash, embedding FROM chunks WHERE " +
            conditions.joined(separator: " AND ")

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }

        for (i, param) in params.enumerated() {
            sqlite3_bind_text(stmt, Int32(i + 1), param.cString, -1, SQLITE_TRANSIENT_PTR)
        }

        var results: [(chunk: VectorChunk, embedding: [Double])] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            let chunk = readChunkRow(stmt)

            guard let embedding = chunk.embedding else { continue }

            if let scope, !scope.isEmpty {
                let matches = scope.contains { s in
                    let sl = s.lowercased()
                    return chunk.source.lowercased().contains(sl) ||
                        chunk.tags.contains { $0.lowercased().contains(sl) } ||
                        chunk.title.lowercased().contains(sl)
                }
                if !matches { continue }
            }

            results.append((chunk, embedding))
        }
        return results
    }

    func chunkCount(entryType: String? = nil) -> Int {
        let sql = entryType != nil
            ? "SELECT COUNT(*) FROM chunks WHERE entry_type = ?"
            : "SELECT COUNT(*) FROM chunks"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        if let entryType { sqlite3_bind_text(stmt, 1, entryType.cString, -1, SQLITE_TRANSIENT_PTR) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    func entryCount(entryType: String? = nil) -> Int {
        let sql = entryType != nil
            ? "SELECT COUNT(DISTINCT entry_id) FROM chunks WHERE entry_type = ?"
            : "SELECT COUNT(DISTINCT entry_id) FROM chunks"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        if let entryType { sqlite3_bind_text(stmt, 1, entryType.cString, -1, SQLITE_TRANSIENT_PTR) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    func embeddedCount() -> Int {
        var stmt: OpaquePointer?
        let sql = "SELECT COUNT(DISTINCT entry_id) FROM chunks WHERE embedding IS NOT NULL"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    // MARK: - Meta

    func getMeta(_ key: String) -> String? {
        var stmt: OpaquePointer?
        let sql = "SELECT value FROM meta WHERE key = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, key.cString, -1, SQLITE_TRANSIENT_PTR)
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        return String(cString: sqlite3_column_text(stmt, 0))
    }

    func setMeta(_ key: String, _ value: String) {
        var stmt: OpaquePointer?
        let sql = "INSERT OR REPLACE INTO meta (key, value) VALUES (?, ?)"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, key.cString, -1, SQLITE_TRANSIENT_PTR)
        sqlite3_bind_text(stmt, 2, value.cString, -1, SQLITE_TRANSIENT_PTR)
        sqlite3_step(stmt)
    }

    // MARK: - Helpers

    private func allEntryIDs(forType entryType: String) -> Set<String> {
        var stmt: OpaquePointer?
        let sql = "SELECT DISTINCT entry_id FROM chunks WHERE entry_type = ?"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, entryType.cString, -1, SQLITE_TRANSIENT_PTR)

        var ids: Set<String> = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            ids.insert(String(cString: sqlite3_column_text(stmt, 0)))
        }
        return ids
    }

    private func readChunkRow(_ stmt: OpaquePointer?) -> VectorChunk {
        let id = String(cString: sqlite3_column_text(stmt, 0))
        let entryID = String(cString: sqlite3_column_text(stmt, 1))
        let entryType = String(cString: sqlite3_column_text(stmt, 2))
        let title = String(cString: sqlite3_column_text(stmt, 3))
        let content = String(cString: sqlite3_column_text(stmt, 4))

        let tagsStr = String(cString: sqlite3_column_text(stmt, 5))
        let tags = (try? JSONSerialization.jsonObject(with: Data(tagsStr.utf8)) as? [String]) ?? []

        let source = String(cString: sqlite3_column_text(stmt, 6))
        let importedAt = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 7))
        let chunkIndex = Int(sqlite3_column_int(stmt, 8))
        let totalChunks = Int(sqlite3_column_int(stmt, 9))
        let contentHash = UInt64(bitPattern: sqlite3_column_int64(stmt, 10))

        var embedding: [Double]?
        if sqlite3_column_type(stmt, 11) != SQLITE_NULL {
            let blobSize = Int(sqlite3_column_bytes(stmt, 11))
            if let blobPtr = sqlite3_column_blob(stmt, 11), blobSize > 0 {
                embedding = blobToEmbedding(Data(bytes: blobPtr, count: blobSize))
            }
        }

        return VectorChunk(
            id: id, entryID: entryID, entryType: entryType,
            title: title, content: content, tags: tags, source: source,
            importedAt: importedAt, chunkIndex: chunkIndex, totalChunks: totalChunks,
            contentHash: contentHash, embedding: embedding
        )
    }

    private func embeddingToBlob(_ embedding: [Double]) -> Data {
        var floats = embedding.map { Float($0) }
        return Data(bytes: &floats, count: floats.count * MemoryLayout<Float>.size)
    }

    private func blobToEmbedding(_ data: Data) -> [Double] {
        let count = data.count / MemoryLayout<Float>.size
        var floats = [Float](repeating: 0, count: count)
        _ = floats.withUnsafeMutableBytes { data.copyBytes(to: $0) }
        return floats.map { Double($0) }
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }
}

// MARK: - Model

struct VectorChunk {
    let id: String
    let entryID: String
    let entryType: String
    let title: String
    let content: String
    let tags: [String]
    let source: String
    let importedAt: Date
    let chunkIndex: Int
    let totalChunks: Int
    let contentHash: UInt64
    let embedding: [Double]?
}

// MARK: - Pending Reindex Model

struct PendingReindexRow {
    let entryID: String
    let entryType: String
    let operation: String
    let retryCount: Int
}

// MARK: - SQLite Helpers

private let SQLITE_TRANSIENT_PTR = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private extension String {
    var cString: UnsafePointer<CChar>? {
        (self as NSString).utf8String
    }
}
