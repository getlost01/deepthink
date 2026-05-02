import SwiftUI

struct SourceBrowserView: View {
    @Environment(AppState.self) private var appState
    private let service = ContextService.shared
    private let fm = FileManager.default

    @State private var expandedSources: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Integrations section
                DSSectionHeader(title: "Integrations", count: service.sources.count)
                    .padding(.horizontal, DS.Spacing.md)

                VStack(spacing: 2) {
                    ForEach(service.sources) { source in
                        sourceRow(source)

                        if expandedSources.contains(source.id) {
                            ForEach(source.channels) { channel in
                                channelRow(channel, source: source)
                            }
                        }
                    }
                }

                Divider()
                    .padding(.vertical, DS.Spacing.sm)

                // Project Knowledge section
                DSSectionHeader(title: "Project Knowledge", count: projectNames.count)
                    .padding(.horizontal, DS.Spacing.md)

                VStack(spacing: 2) {
                    ForEach(projectNames, id: \.self) { name in
                        projectRow(name)
                    }
                }

                if service.sources.isEmpty && projectNames.isEmpty {
                    DSEmptyState(
                        icon: "tray",
                        title: "No Data Yet",
                        subtitle: "Use the CLI to capture context from Slack, GitHub, and more."
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.top, DS.Spacing.xxl)
                }
            }
            .padding(.vertical, DS.Spacing.md)
        }
        .background(DS.Colors.surface)
    }

    // MARK: - Project Knowledge

    private var projectNames: [String] {
        let url = StorageService.shared.knowledgeProjectsURL
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .filter { url in
                var isDir: ObjCBool = false
                return fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue
            }
            .map(\.lastPathComponent)
            .sorted()
    }

    // MARK: - Rows

    @ViewBuilder
    private func sourceRow(_ source: ContextSource) -> some View {
        Button {
            withAnimation(DS.Animation.quick) {
                if expandedSources.contains(source.id) {
                    expandedSources.remove(source.id)
                } else {
                    expandedSources.insert(source.id)
                }
            }
            appState.selectedContextSource = source.id
            appState.selectedContextChannel = nil
            appState.selectedContextItemPath = nil
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: expandedSources.contains(source.id) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(DS.Colors.textTertiary)
                    .frame(width: 12)

                Image(systemName: source.icon)
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(source.color)
                    .frame(width: 20)

                Text(source.name)
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(
                        appState.selectedContextSource == source.id && appState.selectedContextChannel == nil
                            ? DS.Colors.textPrimary
                            : DS.Colors.textSecondary
                    )
                    .lineLimit(1)

                Spacer()

                DSPill(text: "\(source.totalItems)", color: source.color)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                appState.selectedContextSource == source.id && appState.selectedContextChannel == nil
                    ? DS.Colors.selectedBg
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
        }
        .buttonStyle(.plainPointer)
    }

    @ViewBuilder
    private func channelRow(_ channel: ContextChannel, source: ContextSource) -> some View {
        let isSelected = appState.selectedContextSource == source.id && appState.selectedContextChannel == channel.name

        Button {
            appState.selectedContextSource = source.id
            appState.selectedContextChannel = channel.name
            appState.selectedContextItemPath = nil
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Color.clear
                    .frame(width: 12)

                Color.clear
                    .frame(width: 20)

                Text(channel.name)
                    .font(DS.Font.body)
                    .foregroundStyle(isSelected ? DS.Colors.textPrimary : DS.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()

                if let date = channel.lastUpdated {
                    Text(date.relativeFormatted)
                        .font(DS.Font.tiny)
                        .foregroundStyle(DS.Colors.textTertiary)
                }

                Text("\(channel.itemCount)")
                    .font(DS.Font.tiny)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Colors.border, in: Capsule())
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs + 2)
            .background(
                isSelected ? DS.Colors.selectedBg : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
        }
        .buttonStyle(.plainPointer)
    }

    @ViewBuilder
    private func projectRow(_ name: String) -> some View {
        Button {
            appState.selectedContextSource = "projects"
            appState.selectedContextChannel = name
            appState.selectedContextItemPath = nil
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "folder")
                    .font(.system(size: DS.IconSize.sm, weight: .medium))
                    .foregroundStyle(.blue)
                    .frame(width: 20)

                Text(name.replacingOccurrences(of: "-", with: " ").capitalized)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                (appState.selectedContextSource == "projects" && appState.selectedContextChannel == name)
                    ? DS.Colors.selectedBg
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: DS.Radius.sm)
            )
        }
        .buttonStyle(.plainPointer)
    }
}
