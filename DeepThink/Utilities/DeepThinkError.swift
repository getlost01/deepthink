import Foundation

enum DeepThinkError: LocalizedError {
    case notFound(String)
    case alreadyExists(String)
    case archiveConflict(String)
    case encodingFailed(String)
    case filesystemError(String, underlying: Error? = nil)
    case claudeUnavailable
    case rateLimited
    case insufficientCredits
    case invalidInput(String)

    var errorDescription: String? {
        switch self {
        case let .notFound(item): return "Not found: \(item)"
        case let .alreadyExists(item): return "Already exists: \(item)"
        case let .archiveConflict(item): return "Cannot modify archived item: \(item)"
        case let .encodingFailed(detail): return "Encoding failed: \(detail)"
        case let .filesystemError(op, underlying):
            if let err = underlying { return "File system error during \(op): \(err.localizedDescription)" }
            return "File system error during: \(op)"
        case .claudeUnavailable: return "Claude CLI not found or unavailable"
        case .rateLimited: return "Claude API rate limit reached"
        case .insufficientCredits: return "Insufficient Claude API credits"
        case let .invalidInput(detail): return "Invalid input: \(detail)"
        }
    }
}
