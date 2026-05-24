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
        "mcp-server-"
    ]

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    private init() {
        loadCache()
    }

    // MARK: - Auth inference

    static let knownEnvVars: [String: [String]] = [
        "@modelcontextprotocol/server-github": ["GITHUB_TOKEN"],
        "@modelcontextprotocol/server-gitlab": ["GITLAB_PERSONAL_ACCESS_TOKEN", "GITLAB_API_URL"],
        "@modelcontextprotocol/server-slack": ["SLACK_BOT_TOKEN", "SLACK_TEAM_ID"],
        "@modelcontextprotocol/server-brave-search": ["BRAVE_API_KEY"],
        "@modelcontextprotocol/server-google-maps": ["GOOGLE_MAPS_API_KEY"],
        "@modelcontextprotocol/server-aws-kb-retrieval": ["AWS_ACCESS_KEY_ID", "AWS_SECRET_ACCESS_KEY", "AWS_REGION"],
        "@modelcontextprotocol/server-gdrive": ["GDRIVE_CLIENT_ID", "GDRIVE_CLIENT_SECRET"],
        "@modelcontextprotocol/server-linear": ["LINEAR_API_KEY"],
        "@modelcontextprotocol/server-notion": ["NOTION_API_KEY"],
        "@modelcontextprotocol/server-jira": ["JIRA_API_TOKEN", "JIRA_BASE_URL", "JIRA_USER_EMAIL"],
        "@modelcontextprotocol/server-sentry": ["SENTRY_AUTH_TOKEN"],
        "@modelcontextprotocol/server-stripe": ["STRIPE_SECRET_KEY"],
        "@modelcontextprotocol/server-sendgrid": ["SENDGRID_API_KEY"],
        "@modelcontextprotocol/server-twilio": ["TWILIO_ACCOUNT_SID", "TWILIO_AUTH_TOKEN"],
        "@modelcontextprotocol/server-openai": ["OPENAI_API_KEY"],
        "mcp-server-openai": ["OPENAI_API_KEY"],
        "mcp-server-perplexity": ["PERPLEXITY_API_KEY"],
        "mcp-server-anthropic": ["ANTHROPIC_API_KEY"],
        "@anthropic-ai/mcp-server-claude": ["ANTHROPIC_API_KEY"],
        "mcp-server-airtable": ["AIRTABLE_API_KEY", "AIRTABLE_BASE_ID"],
        "mcp-server-hubspot": ["HUBSPOT_API_KEY"],
        "mcp-server-zendesk": ["ZENDESK_API_TOKEN", "ZENDESK_SUBDOMAIN", "ZENDESK_EMAIL"],
        "mcp-server-pagerduty": ["PAGERDUTY_API_KEY"],
        "mcp-server-datadog": ["DATADOG_API_KEY", "DATADOG_APP_KEY"],
        "mcp-server-firebase": ["FIREBASE_PROJECT_ID", "GOOGLE_APPLICATION_CREDENTIALS"],
        "mcp-server-supabase": ["SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY"],
        "mcp-server-planetscale": ["PLANETSCALE_SERVICE_TOKEN", "PLANETSCALE_ORG"],
        "mcp-server-shopify": ["SHOPIFY_ACCESS_TOKEN", "SHOPIFY_STORE_DOMAIN"],
        "mcp-server-asana": ["ASANA_ACCESS_TOKEN"],
        "mcp-server-trello": ["TRELLO_API_KEY", "TRELLO_TOKEN"],
        "mcp-server-clickup": ["CLICKUP_API_TOKEN"],
        "@modelcontextprotocol/server-postgres": ["POSTGRES_CONNECTION_STRING"],
        "mcp-server-neon": ["NEON_API_KEY"],
        "mcp-server-upstash": ["UPSTASH_REDIS_REST_URL", "UPSTASH_REDIS_REST_TOKEN"]
    ]

    static func envVarKeys(for package: MCPPackage) -> [String] {
        knownEnvVars[package.name] ?? []
    }

    static func requiresAuth(_ package: MCPPackage) -> Bool {
        if knownEnvVars[package.name] != nil { return true }
        let text = (package.name + " " + package.description + " " + package.keywords.joined(separator: " ")).lowercased()
        return text.contains("api key") || text.contains("api_key") ||
            text.contains("token") || text.contains("oauth") ||
            text.contains("secret") || text.contains("credential") ||
            text.contains("auth") || text.contains("bearer")
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
        guard let url = URL(string: "https://registry.npmjs.org/-/v1/search?text=\(encoded)&size=100") else { return [] }

        do {
            let (data, response) = try await Self.session.data(from: url)
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
        if text.contains("postgres") || text.contains("sqlite") || text.contains("mysql") || text.contains("mongo") || text.contains("redis") || text
            .contains("database") { return "Data" }
        if text.contains("file") || text.contains("drive") || text.contains("storage") || text.contains("s3") { return "Files" }
        if text.contains("search") || text.contains("brave") || text.contains("google") { return "Search" }
        if text.contains("web") || text.contains("fetch") || text.contains("scrape") || text.contains("browser") || text.contains("puppeteer") { return "Web" }
        if text.contains("memory") || text.contains("knowledge") || text.contains("rag") || text.contains("vector") { return "Knowledge" }
        if text.contains("linear") || text.contains("jira") || text.contains("notion") || text.contains("asana") || text
            .contains("trello") { return "Project Management" }
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

    func searchLive(query: String, from: Int = 0) async -> (packages: [MCPPackage], hasMore: Bool) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "https://registry.npmjs.org/-/v1/search?text=\(encoded)&size=30&from=\(from)") else { return ([], false) }
        do {
            let (data, response) = try await Self.session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return ([], false) }
            let result = try JSONDecoder().decode(NPMSearchResult.self, from: data)
            let rawCount = result.objects.count
            let filtered = result.objects.compactMap { obj -> MCPPackage? in
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
            return (filtered, rawCount >= 30)
        } catch {
            return ([], false)
        }
    }

    var needsRefresh: Bool {
        guard let fetched = lastFetchedAt else { return true }
        return Date().timeIntervalSince(fetched) > 3600
    }
}

// MARK: - Models

struct MCPPackage: Codable, Identifiable, Hashable {
    var id: String {
        name
    }

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
        case "Communication": "message"
        case "Dev": "chevron.left.forwardslash.chevron.right"
        case "Data": "cylinder"
        case "Files": "folder"
        case "Search": "magnifyingglass"
        case "Web": "globe"
        case "Knowledge": "brain"
        case "Project Management": "list.bullet.rectangle"
        default: "puzzlepiece.extension"
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
        case final
        case detail
    }
}

private struct NPMScoreDetail: Codable {
    let popularity: Double?
}
