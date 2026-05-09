import SwiftUI

struct GeneralSettingsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                UpdatesSettingsSection()
                BackupSettingsSection()
            }
            .padding(DS.Spacing.xl)
        }
        .dsPage()
    }
}

// MARK: - Updates Section

private struct UpdatesSettingsSection: View {
    @State private var updater = UpdateService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader(title: "Updates")

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text("Automatic updates")
                            .font(DS.Font.body)
                            .foregroundStyle(DS.Colors.textPrimary)
                        if updater.isEmbedded {
                            Text("DeepThink checks for updates automatically on launch.")
                                .font(DS.Font.small)
                                .foregroundStyle(DS.Colors.textTertiary)
                        } else {
                            Text(
                                "In-app updates require a signed build or SUPublicEDKey in Info.plist — enable Signing & Capabilities in Xcode (or CI), or omit Sparkle checks for unsigned local builds."
                            )
                            .font(DS.Font.small)
                            .foregroundStyle(DS.Colors.textTertiary)
                        }
                    }
                    Spacer()
                    Button("Check Now") {
                        updater.checkForUpdates()
                    }
                    .buttonStyle(.dsSecondary)
                    .disabled(!updater.isEmbedded || !updater.canCheckForUpdates)
                }
                .padding(DS.Spacing.lg)
            }
            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
        }
        .onAppear { updater.prepareIfNeeded() }
    }
}

// MARK: - Backup Settings Section

private struct BackupSettingsSection: View {
    @State private var backup = BackupService.shared
    @AppStorage("backupEnabled") private var backupEnabled: Bool = true
    @AppStorage("backupIntervalHours") private var intervalHours: Int = 4
    @AppStorage("backupMaxKeep") private var maxKeep: Int = 10

    @State private var pendingDelete: BackupSnapshot?
    @State private var pendingRestore: BackupSnapshot?
    @State private var snapshotsExpanded = false

    private let intervals = [1, 2, 4, 8, 24]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            DSSectionHeader(title: "Backup")

            // Settings card
            VStack(spacing: 0) {
                toggleRow

                if backupEnabled {
                    Divider().padding(.leading, DS.Spacing.lg)
                    intervalRow
                    Divider().padding(.leading, DS.Spacing.lg)
                    maxKeepRow
                }

                Divider().padding(.leading, DS.Spacing.lg)
                backupNowRow
            }
            .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))

            // Snapshots list
            if !backup.snapshots.isEmpty {
                Button {
                    withAnimation(DS.Animation.standard) { snapshotsExpanded.toggle() }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        Text("Snapshots")
                            .font(DS.Font.small)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Colors.textSecondary)
                        Text("\(backup.snapshots.count)")
                            .font(DS.Font.micro)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(DS.Colors.fillSecondary, in: Capsule())
                            .foregroundStyle(DS.Colors.textTertiary)
                        Spacer()
                        Text("Restore replaces workspace")
                            .font(DS.Font.caption)
                            .foregroundStyle(DS.Colors.textTertiary)
                        Image(systemName: snapshotsExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: DS.IconSize.xs, weight: .semibold))
                            .foregroundStyle(DS.Colors.textTertiary)
                    }
                }
                .buttonStyle(.plainPointer)

                if snapshotsExpanded {
                    VStack(spacing: 0) {
                        ForEach(Array(backup.snapshots.enumerated()), id: \.element.id) { idx, snap in
                            if idx > 0 { Divider().padding(.leading, DS.Spacing.lg) }
                            snapshotRow(snap)
                        }
                    }
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.md).strokeBorder(DS.Colors.border, lineWidth: 1))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }

            if let err = backup.lastError {
                Text("Last backup failed: \(err)")
                    .font(DS.Font.caption)
                    .foregroundStyle(.red.opacity(0.8))
            }
        }
        .alert("Delete Snapshot?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Delete", role: .destructive) {
                if let s = pendingDelete { BackupService.shared.deleteSnapshot(s) }
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            if let s = pendingDelete {
                Text("This will permanently delete the snapshot from \(s.date.formatted(date: .abbreviated, time: .shortened)).")
            }
        }
        .alert("Restore from Backup?", isPresented: Binding(get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } })) {
            Button("Restore and Quit", role: .destructive) {
                if let s = pendingRestore { BackupService.shared.stageRestore(snapshot: s) }
                pendingRestore = nil
            }
            Button("Cancel", role: .cancel) { pendingRestore = nil }
        } message: {
            if let s = pendingRestore {
                Text(
                    "Your current workspace will be replaced with the snapshot from \(s.date.formatted(date: .abbreviated, time: .shortened)). The app will quit to apply the restore."
                )
            }
        }
    }

    // MARK: Rows

    private var toggleRow: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("Automatic backups")
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textPrimary)
                    Text("Snapshots stored outside your workspace — survives accidental folder deletion.")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                Spacer()
                Toggle("", isOn: $backupEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .onChange(of: backupEnabled) { _, enabled in
                        if enabled { BackupService.shared.start() }
                    }
            }

            // What's covered
            HStack(spacing: DS.Spacing.xs) {
                Text("Covers:")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
                ForEach([
                    ("doc.text", "Notes & Tasks"),
                    ("brain", "Knowledge"),
                    ("memorychip", "Memory"),
                    ("sparkles", "Skills & Rules"),
                    ("person.2.circle", "Agents")
                ], id: \.0) { icon, label in
                    HStack(spacing: 3) {
                        Image(systemName: icon)
                            .font(.system(size: DS.IconSize.xs))
                        Text(label)
                            .font(DS.Font.caption)
                    }
                    .foregroundStyle(DS.Colors.textSecondary)
                    .padding(.horizontal, DS.Spacing.xs)
                    .padding(.vertical, 2)
                    .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                }
            }
        }
        .padding(DS.Spacing.lg)
    }

    private var intervalRow: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Backup every")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("App must be running — no background agent.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            Spacer()
            Picker("", selection: $intervalHours) {
                ForEach(intervals, id: \.self) { h in
                    Text(h == 1 ? "1 hour" : h == 24 ? "24 hours" : "\(h) hours").tag(h)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 100)
        }
        .padding(DS.Spacing.lg)
    }

    private var maxKeepRow: some View {
        HStack(spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Keep last auto snapshots")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text("Oldest auto snapshots pruned when limit is hit. Manual snapshots kept forever.")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
            }
            Spacer()
            maxKeepStepper
        }
        .padding(DS.Spacing.lg)
    }

    private var backupNowRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("Last backup")
                    .font(DS.Font.body)
                    .foregroundStyle(DS.Colors.textPrimary)
                Group {
                    if backup.isRunning {
                        Text("Backing up…")
                    } else if let last = backup.snapshots.first {
                        Text("\(last.date.formatted(.relative(presentation: .named))) · \(last.formattedSize)")
                    } else {
                        Text("Never")
                    }
                }
                .font(DS.Font.caption)
                .foregroundStyle(DS.Colors.textTertiary)
            }
            Spacer()
            Button(backup.isRunning ? "Backing up…" : "Backup Now") {
                Task { await BackupService.shared.runBackup(isManual: true) }
            }
            .buttonStyle(.dsSecondary)
            .disabled(backup.isRunning)
        }
        .padding(DS.Spacing.lg)
    }

    // MARK: Snapshot Row

    private func snapshotRow(_ snap: BackupSnapshot) -> some View {
        SnapshotRowView(snap: snap, onRestore: { pendingRestore = snap }, onDelete: { pendingDelete = snap })
    }

    // MARK: Max Keep Stepper

    private var maxKeepStepper: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button {
                if maxKeep > 3 { maxKeep -= 1 }
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plainPointer)

            Text("\(maxKeep)")
                .font(DS.Font.body)
                .fontWeight(.semibold)
                .foregroundStyle(DS.Colors.textPrimary)
                .frame(minWidth: 28, alignment: .center)
                .monospacedDigit()

            Button {
                if maxKeep < 50 { maxKeep += 1 }
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: DS.IconSize.xs, weight: .semibold))
                    .frame(width: 26, height: 26)
                    .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                    .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
            }
            .buttonStyle(.plainPointer)
        }
    }
}

// MARK: - Snapshot Row View

private struct SnapshotRowView: View {
    let snap: BackupSnapshot
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            HStack(spacing: DS.Spacing.xs) {
                Text(snap.date.formatted(date: .abbreviated, time: .shortened))
                    .font(DS.Font.body)
                    .fontWeight(.medium)
                    .foregroundStyle(DS.Colors.textPrimary)
                Text(snap.isManual ? "Manual" : "Auto")
                    .font(DS.Font.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(DS.Colors.fillSecondary, in: Capsule())
                    .foregroundStyle(DS.Colors.textSecondary)
                Text("·")
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
                Text(snap.formattedSize)
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .monospacedDigit()
            }
            Spacer()
            HStack(spacing: DS.Spacing.xs) {
                Button("Restore") { onRestore() }
                    .buttonStyle(.dsSecondary)
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: DS.IconSize.xs, weight: .medium))
                        .frame(width: 26, height: 26)
                        .background(DS.Colors.fillSecondary, in: RoundedRectangle(cornerRadius: DS.Radius.sm))
                        .overlay(RoundedRectangle(cornerRadius: DS.Radius.sm).strokeBorder(DS.Colors.border, lineWidth: 1))
                        .foregroundStyle(DS.Colors.textTertiary)
                }
                .buttonStyle(.plainPointer)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
}
