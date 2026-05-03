import Foundation

@Observable
final class MCPCatalogService {
    static let shared = MCPCatalogService()

    var packages: [MCPPackage] = []
    var isLoading = false
    var lastFetchedAt: Date?

    private let cacheFile = StorageService.shared.claudeCacheURL.appendingPathComponent("mcp-catalog-cache.json")
    private let searchQueries = [
        "keywords:mcp-server",
        "@modelcontextprotocol",
        "@anthropic-ai/mcp",
        "mcp-server-",
    ]

    private init() {
        loadCache()
    }

    // MARK: - Fetch

    func fetchCatalog() async {
        await MainActor.run { isLoading = true }

        var allPackages: [String: MCPPackage] = [:]

        for query in searchQueries {
            let results = await searchNPM(query: query)
            for pkg in results {
                allPackages[pkg.name] = pkg
            }
        }

        let sorted = Array(allPackages.values).sorted { $0.score > $1.score }

        await MainActor.run {
            packages = sorted
            lastFetchedAt = Date()
            isLoading = false
        }

        saveCache()
        StorageService.shared.writeLog("Fetched \(sorted.count) MCP packages from npm", to: "catalog")
    }

    private func searchNPM(query: String) async -> [MCPPackage] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://registry.npmjs.org/-/v1/search?text=\(encoded)&size=50") else { return [] }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return [] }

            let result = try JSONDecoder().decode(NPMSearchResult.self, from: data)
            return result.objects.compactMap { obj -> MCPPackage? in
                let pkg = obj.package
                let isMCP = pkg.name.contains("mcp") ||
                    (pkg.keywords ?? []).contains(where: { $0.lowercased().contains("mcp") }) ||
                    pkg.name.contains("modelcontextprotocol")
                guard isMCP else { return nil }

                return MCPPackage(
                    name: pkg.name,
                    version: pkg.version,
                    description: pkg.description ?? "",
                    keywords: pkg.keywords ?? [],
                    author: pkg.publisher?.username ?? pkg.author?.name ?? "",
                    category: inferCategory(from: pkg),
                    installCommand: "npx",
                    installArgs: "-y \(pkg.name)",
                    score: obj.score?.final ?? 0,
                    downloads: obj.score?.detail?.popularity ?? 0
                )
            }
        } catch {
            StorageService.shared.writeLog("npm search failed for '\(query)': \(error.localizedDescription)", to: "catalog")
            return []
        }
    }

    private func inferCategory(from pkg: NPMPackageInfo) -> String {
        let text = (pkg.name + " " + (pkg.description ?? "") + " " + (pkg.keywords ?? []).joined(separator: " ")).lowercased()
        if text.contains("slack") || text.contains("discord") || text.contains("email") || text.contains("telegram") { return "Communication" }
        if text.contains("github") || text.contains("gitlab") || text.contains("git") || text.contains("sentry") { return "Dev" }
        if text.contains("postgres") || text.contains("sqlite") || text.contains("mysql") || text.contains("mongo") || text.contains("redis") || text.contains("database") { return "Data" }
        if text.contains("file") || text.contains("drive") || text.contains("storage") || text.contains("s3") { return "Files" }
        if text.contains("search") || text.contains("brave") || text.contains("google") { return "Search" }
        if text.contains("web") || text.contains("fetch") || text.contains("scrape") || text.contains("browser") || text.contains("puppeteer") { return "Web" }
        if text.contains("memory") || text.contains("knowledge") || text.contains("rag") || text.contains("vector") { return "Knowledge" }
        if text.contains("linear") || text.contains("jira") || text.contains("notion") || text.contains("asana") || text.contains("trello") { return "Project Management" }
        return "General"
    }

    // MARK: - Cache

    private func loadCache() {
        guard let data = try? Data(contentsOf: cacheFile),
              let cached = try? JSONDecoder().decode(CatalogCache.self, from: data) else { return }

        packages = cached.packages
        lastFetchedAt = cached.fetchedAt

        if let fetched = lastFetchedAt, Date().timeIntervalSince(fetched) > 86400 {
            Task { await fetchCatalog() }
        }
    }

    private func saveCache() {
        let cache = CatalogCache(packages: packages, fetchedAt: lastFetchedAt ?? Date())
        if let data = try? JSONEncoder().encode(cache) {
            try? data.write(to: cacheFile)
        }
    }

    var needsRefresh: Bool {
        guard let fetched = lastFetchedAt else { return true }
        return Date().timeIntervalSince(fetched) > 3600
    }
}

// MARK: - Models

struct MCPPackage: Codable, Identifiable, Hashable {
    var id: String { name }
    var name: String
    var version: String
    var description: String
    var keywords: [String]
    var author: String
    var category: String
    var installCommand: String
    var installArgs: String
    var score: Double
    var downloads: Double

    var displayName: String {
        name
            .replacingOccurrences(of: "@modelcontextprotocol/server-", with: "")
            .replacingOccurrences(of: "@anthropic-ai/mcp-server-", with: "")
            .replacingOccurrences(of: "mcp-server-", with: "")
            .replacingOccurrences(of: "mcp-", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    var iconName: String {
        switch category {
        case "Communication": return "message"
        case "Dev": return "chevron.left.forwardslash.chevron.right"
        case "Data": return "cylinder"
        case "Files": return "folder"
        case "Search": return "magnifyingglass"
        case "Web": return "globe"
        case "Knowledge": return "brain"
        case "Project Management": return "list.bullet.rectangle"
        default: return "puzzlepiece.extension"
        }
    }
}

private struct CatalogCache: Codable {
    var packages: [MCPPackage]
    var fetchedAt: Date
}

// MARK: - npm API Response

private struct NPMSearchResult: Codable {
    let objects: [NPMSearchObject]
}

private struct NPMSearchObject: Codable {
    let package: NPMPackageInfo
    let score: NPMScore?
}

private struct NPMPackageInfo: Codable {
    let name: String
    let version: String
    let description: String?
    let keywords: [String]?
    let author: NPMAuthor?
    let publisher: NPMPublisher?
}

private struct NPMAuthor: Codable {
    let name: String?
}

private struct NPMPublisher: Codable {
    let username: String?
}

private struct NPMScore: Codable {
    let final: Double?
    let detail: NPMScoreDetail?

    enum CodingKeys: String, CodingKey {
        case final = "final"
        case detail
    }
}

private struct NPMScoreDetail: Codable {
    let popularity: Double?
}
