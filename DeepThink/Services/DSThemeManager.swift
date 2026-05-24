import AppKit
import SwiftUI
import WebKit

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String {
        rawValue
    }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

struct DSThemePalette {
    let page: Color
    let surface: Color
    let surfaceElevated: Color
    let modal: Color
    let card: Color
    let fill: Color
    let fillSecondary: Color

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let onAccent: Color

    let border: Color
    let borderHover: Color
    let borderFocused: Color

    let cardShadow: Color
    let modalShadow: Color
    let subtleShadow: Color
    let overlayBg: Color

    let scrollMaskOpaque: Color
    let scrollMaskFade: Color
    let gridDot: Color

    let terminal: Color
    let terminalNS: NSColor
    let terminalForegroundNS: NSColor

    let accent: Color
    let accentFill: Color
    let accentGradient: LinearGradient

    let success: Color
    let warning: Color
    let warningFill: Color
    let danger: Color
    let knowledge: Color
    let info: Color
    let teal: Color
    let purple: Color
    let amber: Color
    let lime: Color
    let slate: Color
    let gold: Color
    let sunrise: Color

    var editorCSSVariables: [String: String] {
        let isLight = (NSColor(textPrimary).usingColorSpace(.sRGB)?.brightnessComponent ?? 0) < 0.5
        return [
            "color-scheme": isLight ? "light" : "dark",
            "text": textPrimary.hexString,
            "text-dim": textTertiary.hexString,
            "border": border.cssRGBA,
            "accent": accent.hexString,
            "on-accent": onAccent.hexString,
            "code-bg": fillSecondary.cssRGBA,
            "code-text": gold.hexString,
            "block-bg": fill.cssRGBA,
            "toolbar-bg": page.hexString,
            "toolbar-border": borderHover.cssRGBA,
            "highlight": isLight ? gold.opacity(0.32).cssRGBA : gold.opacity(0.24).cssRGBA,
            "accent-subtle": accentFill.cssRGBA,
            "accent-subtle-hover": accent.opacity(0.24).cssRGBA,
            "accent-dashed": borderFocused.cssRGBA,
            "selection": accent.opacity(0.28).cssRGBA,
            "shadow": modalShadow.cssRGBA,
            "success": success.hexString
        ]
    }

    var chatMarkdownCSSVariables: [String: String] {
        var vars: [String: String] = [
            "text": textPrimary.hexString,
            "text2": textTertiary.hexString,
            "bg-code": fillSecondary.cssRGBA,
            "border": border.cssRGBA,
            "accent": accent.hexString,
            "bg-hover": fill.cssRGBA,
            "bg-inline": fillSecondary.cssRGBA,
            "on-accent": onAccent.hexString,
            "success": success.hexString,
            "warning": warning.hexString,
            "danger": danger.hexString,
            "warning-subtle": warningFill.cssRGBA,
            "danger-subtle": danger.opacity(DS.Opacity.dangerFill).cssRGBA,
            "success-subtle": success.opacity(DS.Opacity.successFill).cssRGBA
        ]
        let isLight = (NSColor(textPrimary).usingColorSpace(.sRGB)?.brightnessComponent ?? 0) < 0.5
        vars["color-scheme"] = isLight ? "light" : "dark"
        return vars
    }

    func cssRootBlock(from variables: [String: String]) -> String {
        let lines = variables
            .filter { $0.key != "color-scheme" }
            .sorted { $0.key < $1.key }
            .map { "    --\($0.key): \($0.value);" }
        return ":root {\n" + lines.joined(separator: "\n") + "\n}"
    }

    func editorThemeJavaScript() -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: editorCSSVariables),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return "window.setTheme && window.setTheme(\(json));"
    }

    func chatThemeJavaScript(isLight: Bool) -> String? {
        guard let data = try? JSONSerialization.data(withJSONObject: chatMarkdownCSSVariables),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return "window.setChatTheme && window.setChatTheme(\(json), \(isLight));"
    }

    func editorThemeUserScript() -> WKUserScript? {
        guard let source = editorThemeJavaScript() else { return nil }
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    func chatThemeUserScript(isLight: Bool) -> WKUserScript? {
        guard let source = chatThemeJavaScript(isLight: isLight) else { return nil }
        return WKUserScript(source: source, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }
}

// MARK: - Color primitives (internal)

private enum DSColor {
    static func srgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> Color {
        Color(NSColor(srgbRed: r, green: g, blue: b, alpha: a))
    }

    static func nsrgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    /// Muted GitHub Primer accents — readable but not neon against the neutral ramp.
    struct Semantic {
        let accent: Color
        let success: Color
        let warning: Color
        let danger: Color
        let knowledge: Color
        let info: Color
        let teal: Color
        let purple: Color
        let amber: Color
        let lime: Color
        let slate: Color
        let gold: Color
        let sunrise: Color

        static let light = Semantic(
            accent: srgb(0.047, 0.412, 0.843),
            success: srgb(0.118, 0.525, 0.235),
            warning: srgb(0.580, 0.420, 0.050),
            danger: srgb(0.780, 0.165, 0.195),
            knowledge: srgb(0.435, 0.280, 0.520),
            info: srgb(0.047, 0.412, 0.843),
            teal: srgb(0.055, 0.565, 0.545),
            purple: srgb(0.435, 0.280, 0.520),
            amber: srgb(0.580, 0.420, 0.050),
            lime: srgb(0.325, 0.585, 0.135),
            slate: srgb(0.390, 0.430, 0.490),
            gold: srgb(0.580, 0.420, 0.050),
            sunrise: srgb(0.780, 0.320, 0.110)
        )

        static let dark = Semantic(
            accent: srgb(0.400, 0.620, 0.950),
            success: srgb(0.290, 0.680, 0.360),
            warning: srgb(0.760, 0.580, 0.200),
            danger: srgb(0.920, 0.380, 0.360),
            knowledge: srgb(0.600, 0.460, 0.880),
            info: srgb(0.400, 0.620, 0.950),
            teal: srgb(0.320, 0.660, 0.660),
            purple: srgb(0.600, 0.460, 0.880),
            amber: srgb(0.760, 0.580, 0.200),
            lime: srgb(0.290, 0.680, 0.360),
            slate: srgb(0.520, 0.555, 0.595),
            gold: srgb(0.760, 0.580, 0.200),
            sunrise: srgb(0.920, 0.500, 0.340)
        )
    }
}

extension DSThemePalette {
    static let light: DSThemePalette = {
        let sem = DSColor.Semantic.light
        let accent = sem.accent
        let warning = sem.warning
        // Blue-slate ink — same hue family as dark neutrals, inverted for light surfaces.
        let inkR = 0.098
        let inkG = 0.118
        let inkB = 0.152
        return DSThemePalette(
            page: DSColor.srgb(0.965, 0.972, 0.988),
            surface: DSColor.srgb(0.972, 0.978, 0.992),
            surfaceElevated: DSColor.srgb(0.988, 0.992, 1.0),
            modal: DSColor.srgb(1.0, 1.0, 1.0),
            card: DSColor.srgb(0.992, 0.995, 1.0),
            fill: DSColor.srgb(0.047, 0.412, 0.843, 0.045),
            fillSecondary: DSColor.srgb(0.047, 0.412, 0.843, 0.085),
            textPrimary: DSColor.srgb(inkR, inkG, inkB),
            textSecondary: DSColor.srgb(0.400, 0.440, 0.500),
            textTertiary: DSColor.srgb(0.520, 0.560, 0.615),
            onAccent: DSColor.srgb(1, 1, 1),
            border: DSColor.srgb(0.047, 0.412, 0.843, 0.11),
            borderHover: DSColor.srgb(0.047, 0.412, 0.843, 0.18),
            borderFocused: accent.opacity(0.50),
            cardShadow: DSColor.srgb(0.047, 0.118, 0.196, 0.045),
            modalShadow: DSColor.srgb(0.047, 0.118, 0.196, 0.10),
            subtleShadow: DSColor.srgb(0.047, 0.118, 0.196, 0.06),
            overlayBg: DSColor.srgb(inkR, inkG, inkB, 0.32),
            scrollMaskOpaque: DSColor.srgb(0.965, 0.972, 0.988),
            scrollMaskFade: Color.clear,
            gridDot: DSColor.srgb(0.047, 0.412, 0.843, 0.12),
            terminal: DSColor.srgb(0.972, 0.978, 0.992),
            terminalNS: DSColor.nsrgb(0.972, 0.978, 0.992),
            terminalForegroundNS: DSColor.nsrgb(inkR, inkG, inkB),
            accent: accent,
            accentFill: accent.opacity(0.10),
            accentGradient: LinearGradient(
                colors: [accent, accent.opacity(0.82)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            success: sem.success,
            warning: warning,
            warningFill: warning.opacity(0.10),
            danger: sem.danger,
            knowledge: sem.knowledge,
            info: sem.info,
            teal: sem.teal,
            purple: sem.purple,
            amber: sem.amber,
            lime: sem.lime,
            slate: sem.slate,
            gold: sem.gold,
            sunrise: sem.sunrise
        )
    }()

    static let dark: DSThemePalette = {
        let sem = DSColor.Semantic.dark
        let accent = sem.accent
        let warning = sem.warning
        return DSThemePalette(
            page: DSColor.srgb(0.051, 0.067, 0.090),
            surface: DSColor.srgb(0.059, 0.075, 0.098),
            surfaceElevated: DSColor.srgb(0.067, 0.082, 0.106),
            modal: DSColor.srgb(0.090, 0.106, 0.129),
            card: DSColor.srgb(0.078, 0.094, 0.118),
            fill: DSColor.srgb(0.902, 0.929, 0.953, 0.05),
            fillSecondary: DSColor.srgb(0.902, 0.929, 0.953, 0.08),
            textPrimary: DSColor.srgb(0.902, 0.929, 0.953),
            textSecondary: DSColor.srgb(0.520, 0.555, 0.595),
            textTertiary: DSColor.srgb(0.420, 0.450, 0.490),
            onAccent: DSColor.srgb(1, 1, 1),
            border: DSColor.srgb(0.902, 0.929, 0.953, 0.08),
            borderHover: DSColor.srgb(0.902, 0.929, 0.953, 0.12),
            borderFocused: accent.opacity(0.50),
            cardShadow: DSColor.srgb(0, 0, 0, 0.12),
            modalShadow: DSColor.srgb(0, 0, 0, 0.22),
            subtleShadow: DSColor.srgb(0, 0, 0, 0.08),
            overlayBg: DSColor.srgb(0.020, 0.031, 0.051, 0.55),
            scrollMaskOpaque: DSColor.srgb(0.051, 0.067, 0.090),
            scrollMaskFade: Color.clear,
            gridDot: DSColor.srgb(0.902, 0.929, 0.953, 0.06),
            terminal: DSColor.srgb(0.047, 0.063, 0.086),
            terminalNS: DSColor.nsrgb(0.047, 0.063, 0.086),
            terminalForegroundNS: DSColor.nsrgb(0.902, 0.929, 0.953),
            accent: accent,
            accentFill: accent.opacity(0.12),
            accentGradient: LinearGradient(
                colors: [accent, accent.opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            success: sem.success,
            warning: warning,
            warningFill: warning.opacity(0.10),
            danger: sem.danger,
            knowledge: sem.knowledge,
            info: sem.info,
            teal: sem.teal,
            purple: sem.purple,
            amber: sem.amber,
            lime: sem.lime,
            slate: sem.slate,
            gold: sem.gold,
            sunrise: sem.sunrise
        )
    }()
}

// MARK: - Theme manager

@Observable
final class DSThemeManager {
    static let shared = DSThemeManager()

    private static let appearanceKey = "appAppearance"
    private static var isObservingSystemChanges = false

    private(set) var palette: DSThemePalette = .dark
    private(set) var themeRevision: Int = 0

    var appearance: AppAppearance {
        didSet {
            guard appearance != oldValue else { return }
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey)
            refreshPalette(userInitiated: true)
        }
    }

    /// Always explicit — `nil` leaves sheet/input layers on a stale scheme after Light → System.
    var resolvedColorScheme: ColorScheme {
        effectiveAppearance == .light ? .light : .dark
    }

    var effectiveAppearance: AppAppearance {
        Self.resolveEffectiveAppearance(for: appearance)
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.appearanceKey)
        appearance = AppAppearance(rawValue: stored ?? AppAppearance.system.rawValue) ?? .system
        refreshPalette(userInitiated: true)
    }

    func refreshPalette(userInitiated: Bool = false) {
        applyAppKitAppearance()
        commitPaletteUpdate(bumpRevision: userInitiated)

        guard appearance == .system else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self, appearance == .system else { return }
            applyAppKitAppearance()
            commitPaletteUpdate(bumpRevision: false)
        }
    }

    func applyAppKitAppearance() {
        let nsAppearance: NSAppearance? = switch appearance {
        case .system:
            nil
        case .light:
            NSAppearance(named: .aqua)
        case .dark:
            NSAppearance(named: .darkAqua)
        }
        NSApp.appearance = nsAppearance
        for window in NSApp.windows {
            window.appearance = nsAppearance
            window.contentView?.needsDisplay = true
            window.contentView?.needsLayout = true
        }
    }

    private func commitPaletteUpdate(bumpRevision: Bool) {
        let resolved = Self.resolveEffectiveAppearance(for: appearance)
        let nextPalette = resolved == .light ? DSThemePalette.light : DSThemePalette.dark
        let resolvedChanged = resolved != lastCommittedAppearance
        lastCommittedAppearance = resolved
        palette = nextPalette
        guard bumpRevision || resolvedChanged else { return }
        themeRevision &+= 1
        NotificationCenter.default.post(name: .dsThemeDidChange, object: nil)
    }

    private var lastCommittedAppearance: AppAppearance?

    func observeSystemAppearanceChanges() {
        guard !Self.isObservingSystemChanges else { return }
        Self.isObservingSystemChanges = true

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            guard appearance == .system else { return }
            refreshPalette()
        }
    }

    private static func resolveEffectiveAppearance(for mode: AppAppearance) -> AppAppearance {
        switch mode {
        case .light,
             .dark:
            mode
        case .system:
            resolvedSystemAppearance()
        }
    }

    /// Uses AppKit effective appearance only — not `AppleInterfaceStyle` defaults, which stay at the OS value while the app forces light/dark.
    private static func resolvedSystemAppearance() -> AppAppearance {
        let match = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua])
        return match == .darkAqua ? .dark : .light
    }
}

extension Notification.Name {
    static let dsThemeDidChange = Notification.Name("dsThemeDidChange")
}

extension EnvironmentValues {
    @Entry var dsPalette: DSThemePalette = .dark
}

// MARK: - Theme root

struct DSThemeRoot<Content: View>: View {
    @State private var theme = DSThemeManager.shared
    @ViewBuilder let content: () -> Content

    var body: some View {
        let revision = theme.themeRevision
        content()
            .id(revision)
            .environment(theme)
            .environment(\.dsPalette, theme.palette)
            .preferredColorScheme(theme.resolvedColorScheme)
            .onAppear {
                theme.observeSystemAppearanceChanges()
                theme.refreshPalette()
            }
    }
}

// MARK: - Color helpers

private extension Color {
    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#000000" }
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var cssRGBA: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "rgba(0,0,0,0)" }
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        let a = c.alphaComponent
        return "rgba(\(r),\(g),\(b),\(String(format: "%.2f", a)))"
    }
}
