import SwiftUI

struct ObsidianImportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vaultURL: URL?
    @State private var options = ObsidianImportService.ImportOptions()
    @State private var result: ObsidianImportService.ImportResult?
    @State private var fileCount = 0
    @State private var totalSize: Int64 = 0

    private var importService: ObsidianImportService { ObsidianImportService.shared }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if importService.isImporting {
                progressContent
            } else if let result {
                resultContent(result)
            } else {
                configContent
            }
        }
        .frame(width: 500)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "square.stack.3d.up")
                    .font(.system(size: DS.IconSize.lg, weight: .medium))
                    .foregroundStyle(DS.Colors.purple)
                Text("Import Obsidian Vault")
                    .font(DS.Font.heading)
            }
            Spacer()
            Button("Close") { dismiss() }
                .font(DS.Font.body)
                .buttonStyle(.plainPointer)
                .foregroundStyle(DS.Colors.textSecondary)
        }
        .padding(DS.Spacing.lg)
        .background(DS.Colors.surfaceElevated)
    }

    // MARK: - Config

    private var configContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Vault picker
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                Text("VAULT LOCATION")
                    .font(DS.Font.small)
                    .foregroundStyle(DS.Colors.textTertiary)

                Button { pickVault() } label: {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: vaultURL != nil ? "checkmark.circle.fill" : "folder.badge.questionmark")
                            .font(.system(size: DS.IconSize.md))
                            .foregroundStyle(vaultURL != nil ? DS.Colors.success : DS.Colors.textTertiary)

                        if let url = vaultURL {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .font(DS.Font.body)
                                    .fontWeight(.medium)
                                    .foregroundStyle(DS.Colors.textPrimary)
                                Text(url.path)
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Colors.textTertiary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        } else {
                            Text("Select Obsidian Vault Folder")
                                .font(DS.Font.body)
                                .foregroundStyle(DS.Colors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "folder")
                            .font(.system(size: DS.IconSize.md))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .strokeBorder(DS.Colors.border, lineWidth: 1)
                    )
                }
                .buttonStyle(.plainPointer)
            }

            // Vault stats
            if vaultURL != nil, fileCount > 0 {
                HStack(spacing: DS.Spacing.md) {
                    DSStatChip(label: "Files", value: "\(fileCount) files", icon: "doc.text", color: DS.Colors.purple)
                    DSStatChip(label: "Size", value: formattedSize(totalSize), icon: "internaldrive", color: DS.Colors.teal)
                }
            }

            DSSectionDivider(label: "Options")

            // Options
            VStack(spacing: DS.Spacing.md) {
                optionToggle(
                    "Preserve folder structure",
                    icon: "folder.badge.gearshape",
                    isOn: $options.preserveStructure,
                    description: "Keep the Obsidian vault's subfolder hierarchy"
                )
                optionToggle(
                    "Convert wiki-links",
                    icon: "link",
                    isOn: $options.convertWikiLinks,
                    description: "Transform [[links]] and callouts to standard markdown"
                )
                optionToggle(
                    "Extract inline tags",
                    icon: "tag",
                    isOn: $options.extractTags,
                    description: "Pull #tags from note body into frontmatter"
                )
                optionToggle(
                    "Skip duplicates",
                    icon: "doc.on.doc",
                    isOn: $options.skipDuplicates,
                    description: "Skip files similar to existing knowledge entries"
                )
            }

            // Folder name
            DSLabeledTextField(
                label: "Destination Folder",
                text: $options.folderName,
                placeholder: "obsidian"
            )

            // Import button
            Button {
                Task { await startImport() }
            } label: {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: DS.IconSize.sm, weight: .medium))
                    Text("Import Vault")
                        .font(DS.Font.body)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(DS.Colors.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    vaultURL == nil
                        ? DS.Colors.accent.opacity(DS.Opacity.disabled)
                        : DS.Colors.accent,
                    in: RoundedRectangle(cornerRadius: DS.Radius.md)
                )
            }
            .buttonStyle(.plainPointer)
            .disabled(vaultURL == nil)
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: - Progress

    private var progressContent: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            VStack(spacing: DS.Spacing.md) {
                ProgressView(value: importService.importProgress)
                    .progressViewStyle(.linear)
                    .tint(DS.Colors.accent)

                HStack {
                    Text("Importing...")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textPrimary)

                    Spacer()

                    Text("\(importService.importedCount) of \(importService.totalCount)")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                }

                Text("\(Int(importService.importProgress * 100))%")
                    .font(DS.Font.display)
                    .foregroundStyle(DS.Colors.accent)
            }

            if let error = importService.lastImportError {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(DS.Colors.warning)
                        .font(.system(size: DS.IconSize.sm))
                    Text("Last error: \(error)")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding(DS.Spacing.xl)
        .frame(minHeight: 200)
    }

    // MARK: - Result

    private func resultContent(_ result: ObsidianImportService.ImportResult) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer()

            Image(systemName: result.errors == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(result.errors == 0 ? DS.Colors.success : DS.Colors.warning)

            Text("Import Complete")
                .font(DS.Font.title)
                .foregroundStyle(DS.Colors.textPrimary)

            HStack(spacing: DS.Spacing.lg) {
                resultStat("\(result.imported)", label: "Imported", color: DS.Colors.success)
                resultStat("\(result.skipped)", label: "Skipped", color: DS.Colors.textTertiary)
                resultStat("\(result.duplicates)", label: "Duplicates", color: DS.Colors.warning)
                if result.errors > 0 {
                    resultStat("\(result.errors)", label: "Errors", color: DS.Colors.danger)
                }
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(DS.Font.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(DS.Colors.onAccent)
                    .padding(.horizontal, DS.Spacing.xxl)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            }
            .buttonStyle(.plainPointer)

            Spacer()
        }
        .padding(DS.Spacing.xl)
        .frame(minHeight: 280)
    }

    // MARK: - Helpers

    private func optionToggle(_ title: String, icon: String, isOn: Binding<Bool>, description: String) -> some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: DS.IconSize.sm, weight: .medium))
                .foregroundStyle(DS.Colors.textTertiary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(description)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private func resultStat(_ value: String, label: String, color: Color) -> some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(value)
                .font(DS.Font.titleLarge)
                .foregroundStyle(color)
            Text(label)
                .font(DS.Font.small)
                .foregroundStyle(DS.Colors.textSecondary)
        }
    }

    private func pickVault() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select your Obsidian vault folder"
        panel.prompt = "Select Vault"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            vaultURL = url
            let stats = importService.scanVault(at: url)
            fileCount = stats.fileCount
            totalSize = stats.totalSize
        }
    }

    @MainActor
    private func startImport() async {
        guard let url = vaultURL else { return }
        result = await importService.importVault(at: url, options: options)
    }

    private func formattedSize(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return "\(bytes / 1024) KB" }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }
}
