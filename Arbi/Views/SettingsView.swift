import SwiftUI

/// Settings view providing dynamic language switching and app metadata.
/// Bank Accounts and Capital Settings are managed exclusively from the Home dashboard.
struct SettingsView: View {
    @Environment(\.localization) private var loc

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        NavigationStack {
            List {
                // Section 1: In-App Language Selection
                Section {
                    ForEach(AppLanguage.allCases) { language in
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                loc.setLanguage(language)
                            }
                        } label: {
                            HStack {
                                Text(language.title)
                                    .font(.body.weight(.regular))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if loc.currentLanguage == language {
                                    Image(systemName: "checkmark")
                                        .font(.body.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text(loc["Language / Мова"])
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                // Section 2: Data & Export (Placeholder — Future)
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline)
                            .frame(width: 24, alignment: .leading)
                            .foregroundStyle(.secondary)

                        Text(loc["Export to CSV"])
                            .font(.subheadline.weight(.regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        Spacer()

                        Text(loc["Coming Soon"])
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                } header: {
                    Text(loc["Data & Export"])
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                // Section 3: App Information
                Section {
                    HStack {
                        Text(loc["Version"])
                        Spacer()
                        Text("Spred v\(appVersion)")
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(loc["Build"])
                        Spacer()
                        Text(buildNumber)
                            .font(.callout.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(loc["Engine"])
                        Spacer()
                        Text(loc["Spred P2P Arbitrage Engine"])
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(loc["App Information"])
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Designed for high-frequency crypto P2P arbitrage and bank limit monitoring.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .listSectionSpacing(8)
            .bottomScrollFade()
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(loc["Settings"])
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
