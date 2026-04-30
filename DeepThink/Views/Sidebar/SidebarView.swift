import SwiftUI
import SwiftData

struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Query(filter: #Predicate<TaskItem> { $0.statusRaw == "In Progress" || $0.statusRaw == "To Do" })
    private var activeTasks: [TaskItem]
    @Query private var notes: [Note]

    var body: some View {
        @Bindable var appState = appState

        List(selection: $appState.selectedSection) {
            Section {
                sidebarRow(.home)
            }

            Section("AI") {
                sidebarRow(.chat)
                sidebarRow(.deepSearch)
                sidebarRow(.analysis)
            }

            Section("Workspace") {
                sidebarRow(.notes, badge: notes.isEmpty ? nil : "\(notes.count)")
                sidebarRow(.tasks, badge: activeTasks.isEmpty ? nil : "\(activeTasks.count)")
                sidebarRow(.projects)
            }

            Section("Tools") {
                sidebarRow(.tools)
                sidebarRow(.graph)
                sidebarRow(.terminal)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("DeepThink")
        .safeAreaInset(edge: .bottom) {
            Button {
                appState.toggleCommandPalette()
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "command")
                            .font(.system(size: 9))
                        Text("K")
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                    }
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DS.Colors.border, in: RoundedRectangle(cornerRadius: DS.Spacing.xs))

                    Text("Command Palette")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.sm)
            }
            .buttonStyle(.plain)
            .background(.bar)
        }
    }

    private func sidebarRow(_ section: SidebarSection, badge: String? = nil) -> some View {
        Label {
            HStack {
                Text(section.rawValue)
                Spacer()
                if let badge {
                    Text(badge)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: Capsule())
                }
            }
        } icon: {
            Image(systemName: section.icon)
                .foregroundStyle(section.color)
                .symbolRenderingMode(.hierarchical)
        }
        .tag(section)
    }
}
