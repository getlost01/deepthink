import SwiftUI

struct WelcomeView: View {
    let onComplete: () -> Void
    @State private var currentStep = 0

    private let steps: [WelcomeStep] = [
        WelcomeStep(
            icon: "sparkles",
            title: "Welcome to DeepThink",
            subtitle: "Your personal workspace for thinking, planning, and getting things done — with AI that actually knows your work.",
            features: []
        ),
        WelcomeStep(
            icon: "square.grid.2x2",
            title: "Organize Your Work",
            subtitle: "Everything starts in your Workspace.",
            features: [
                Feature(icon: "folder", title: "Projects", description: "Group related work together"),
                Feature(icon: "doc.text", title: "Notes", description: "Capture ideas, plans, and meeting notes"),
                Feature(icon: "checklist", title: "Tasks", description: "Track what needs to get done"),
            ]
        ),
        WelcomeStep(
            icon: "brain",
            title: "Build Your Knowledge",
            subtitle: "Save articles, research, and reference material. AI uses this to give you smarter answers.",
            features: [
                Feature(icon: "globe", title: "Save web pages", description: "Grab content from any URL"),
                Feature(icon: "doc.on.clipboard", title: "Paste anything", description: "Quick-save from your clipboard"),
                Feature(icon: "folder.badge.plus", title: "Import files", description: "Bring in documents and folders"),
            ]
        ),
        WelcomeStep(
            icon: "sparkles",
            title: "Chat with AI",
            subtitle: "Ask questions, brainstorm ideas, or get help — AI has access to your notes and knowledge.",
            features: [
                Feature(icon: "person.2.circle", title: "AI Assistants", description: "Specialized helpers for different tasks"),
                Feature(icon: "sparkles", title: "Automations", description: "Reusable AI actions you can run anytime"),
                Feature(icon: "puzzlepiece.extension", title: "Connections", description: "Give AI access to external tools"),
            ]
        ),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: DS.Spacing.xxl) {
                let step = steps[currentStep]

                Image(systemName: step.icon)
                    .font(DS.Font.hero)
                    .foregroundStyle(DS.Colors.accent)
                    .frame(height: 60)

                VStack(spacing: DS.Spacing.md) {
                    Text(step.title)
                        .font(DS.Font.display)
                        .foregroundStyle(DS.Colors.textPrimary)

                    Text(step.subtitle)
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 400)
                }

                if !step.features.isEmpty {
                    VStack(spacing: DS.Spacing.md) {
                        ForEach(step.features) { feature in
                            HStack(spacing: DS.Spacing.lg) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: DS.IconSize.lg, weight: .medium))
                                    .foregroundStyle(DS.Colors.accent)
                                    .frame(width: 32, height: 32)
                                    .background(DS.Colors.accentFill, in: RoundedRectangle(cornerRadius: DS.Radius.sm))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.title)
                                        .font(DS.Font.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(DS.Colors.textPrimary)
                                    Text(feature.description)
                                        .font(DS.Font.caption)
                                        .foregroundStyle(DS.Colors.textSecondary)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                            .padding(.vertical, DS.Spacing.sm)
                        }
                    }
                    .frame(maxWidth: 380)
                    .padding(.vertical, DS.Spacing.md)
                    .background(DS.Colors.fill, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentStep)

            Spacer()

            VStack(spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.sm) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? DS.Colors.accent : DS.Colors.border)
                            .frame(width: 8, height: 8)
                    }
                }

                HStack(spacing: DS.Spacing.lg) {
                    if currentStep > 0 {
                        Button("Back") {
                            withAnimation { currentStep -= 1 }
                        }
                        .font(DS.Font.body)
                        .foregroundStyle(DS.Colors.textSecondary)
                        .buttonStyle(.plainPointer)
                    }

                    Button {
                        if currentStep < steps.count - 1 {
                            withAnimation { currentStep += 1 }
                        } else {
                            onComplete()
                        }
                    } label: {
                        Text(currentStep < steps.count - 1 ? "Next" : "Get Started")
                            .font(DS.Font.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Colors.onAccent)
                            .padding(.horizontal, DS.Spacing.xxl)
                            .padding(.vertical, DS.Spacing.md)
                            .background(DS.Colors.accent, in: RoundedRectangle(cornerRadius: DS.Radius.md))
                    }
                    .buttonStyle(.plainPointer)
                }

                if currentStep == 0 {
                    Button("Skip intro") {
                        onComplete()
                    }
                    .font(DS.Font.caption)
                    .foregroundStyle(DS.Colors.textTertiary)
                    .buttonStyle(.plainPointer)
                }
            }
            .padding(.bottom, DS.Spacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct WelcomeStep {
    let icon: String
    let title: String
    let subtitle: String
    let features: [Feature]
}

private struct Feature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
}
