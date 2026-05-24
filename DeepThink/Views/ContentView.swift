import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(CommandPaletteState.self) private var commandPaletteState
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var isReady = false

    var body: some View {
        DSThemeRoot {
            if !hasCompletedOnboarding {
                WelcomeView {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        hasCompletedOnboarding = true
                    }
                }
            } else if !isReady {
                SplashView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                isReady = true
                            }
                        }
                    }
            } else {
                HStack(spacing: 0) {
                    SidebarView()

                    Divider()

                    VStack(spacing: 0) {
                        GlobalHeader()
                        Divider()
                        ContentRouter()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .background(DS.Colors.page)
                }
                .overlay {
                    if appState.showCommandPalette {
                        CommandPaletteView()
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                }
                .overlay(alignment: .bottom) {
                    DSToastView()
                        .padding(.bottom, DS.Spacing.xl)
                }
                .alert(item: Binding(
                    get: { appState.presentedError },
                    set: { appState.presentedError = $0 }
                )) { err in
                    Alert(
                        title: Text(err.title),
                        message: Text("\(err.context): \(err.message)"),
                        dismissButton: .default(Text("OK")) {
                            appState.presentedError = nil
                        }
                    )
                }
                .transition(.opacity)
            }
        }
    }
}

private struct GlobalHeader: View {
    @Environment(AppState.self) private var appState
    @State private var showDailyBrief = false
    @State private var dailyBriefRefreshID = UUID()

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            navButton(icon: "chevron.left", enabled: appState.canGoBack) {
                appState.navigateBack()
            }
            navButton(icon: "chevron.right", enabled: appState.canGoForward) {
                appState.navigateForward()
            }

            Button { appState.toggleCommandPalette() } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: DS.IconSize.xs, weight: .medium))
                        .foregroundStyle(DS.Colors.textTertiary)
                    Text("Search")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    HStack(spacing: 1) {
                        Image(systemName: "command")
                            .font(DS.Font.micro)
                        Text("K")
                            .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    }
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, DS.Spacing.xxs)
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                }
                .padding(.horizontal, DS.Spacing.md)
                .frame(height: DS.Layout.searchFieldHeight)
                .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plainPointer)
            .keyboardShortcut("k", modifiers: .command)

            Spacer()

            Button {
                showDailyBrief = true
            } label: {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "sun.horizon")
                        .font(.system(size: DS.IconSize.xs, weight: .semibold))
                        .foregroundStyle(DS.Colors.accent)
                    Text("Daily Brief")
                        .font(DS.Font.small)
                        .fontWeight(.semibold)
                        .foregroundStyle(DS.Colors.textSecondary)
                }
                .padding(.horizontal, DS.Spacing.sm)
                .padding(.vertical, DS.Spacing.xs)
                .background(DS.Colors.fill, in: Capsule())
                .overlay(Capsule().strokeBorder(DS.Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plainPointer)
            .keyboardShortcut("d", modifiers: .command)
        }
        .frame(height: DS.Layout.toolbarHeight)
        .padding(.horizontal, DS.Spacing.lg)
        .dsChromeBar()
        .sheet(isPresented: $showDailyBrief) {
            DailyBriefModal(refreshID: $dailyBriefRefreshID)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showDailyBrief)) { _ in
            showDailyBrief = true
        }
    }

    private func navButton(icon: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        DSToolbarButton(
            icon: icon,
            color: enabled ? DS.Colors.textPrimary : DS.Colors.textTertiary,
            size: DS.IconSize.xs,
            action: { withAnimation(DS.Animation.standard) { action() } }
        )
        .disabled(!enabled)
    }
}

private struct SplashView: View {
    @State private var dotCount = 0
    private let timer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            Text("DeepThink")
                .font(DS.Font.display)
                .foregroundStyle(DS.Colors.textPrimary)

            Text("Loading workspace" + String(repeating: ".", count: dotCount))
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textTertiary)
                .frame(width: 120, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.page)
        .onReceive(timer) { _ in
            dotCount = (dotCount + 1) % 4
        }
    }
}

struct ContentRouter: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var listRefreshID = 0

    var body: some View {
        Group {
            switch appState.selectedSection {
            case .recent: RecentView().id(listRefreshID)
            case .workspace: WorkspaceView().id(listRefreshID)
            case .knowledge: KnowledgeView()
            case .aiAssistant: AIView()
            case .reminders: ReminderListView().id(listRefreshID)
            case .integrations: IntegrationsView()
            case .terminal: DeepThinkTerminalView()
            case .contextGraph: ContextGraphView()
            case .settings: SettingsView()
            case nil: RecentView().id(listRefreshID)
            }
        }
        .onChange(of: appState.externalSyncToken) { _, _ in
            listRefreshID += 1
        }
    }
}
