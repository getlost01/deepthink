import Foundation
import SwiftUI

extension Date {
    var relativeFormatted: String {
        let interval = Date().timeIntervalSince(self)
        if interval < 60 { return "just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "\(Int(interval / 3600))h ago" }
        if interval < 86400 * 30 { return "\(Int(interval / 86400))d ago" }
        if interval < 86400 * 365 { return "\(Int(interval / (86400 * 30)))mo ago" }
        return "\(Int(interval / (86400 * 365)))y ago"
    }

    var shortFormatted: String {
        formatted(date: .abbreviated, time: .omitted)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

extension String {
    var wordCount: Int {
        split(whereSeparator: \.isWhitespace).count
    }
}

@Observable
final class DebouncedText {
    var text: String = ""
    var debouncedText: String = ""
    private var task: Task<Void, Never>?

    func update(_ newValue: String, delay: Duration = .milliseconds(200)) {
        text = newValue
        task?.cancel()
        task = Task { @MainActor in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            debouncedText = newValue
        }
    }
}
