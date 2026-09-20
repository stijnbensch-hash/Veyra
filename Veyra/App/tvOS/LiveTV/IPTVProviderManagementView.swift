import SwiftUI

struct IPTVProviderManagementView: View {
    @State private var configuration:
        IPTVStoredConfiguration?

    @State private var preferences =
        IPTVProviderPreferences()

    @State private var errorMessage: String?

    private let configurationStore =
        IPTVConfigurationStore()

    private let preferencesStore =
        IPTVProviderPreferencesStore()

    var body: some View {
        ZStack {
            VeyraBackground()
            .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 34
            ) {
                header

                content

                Spacer()
            }
            .padding(.horizontal, VeyraSpacing.page)
            .padding(.top, 36)
            .padding(.bottom, 50)
        }
        .onAppear {
            loadConfiguration()
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(
            alignment: .leading,
            spacing: 8
        ) {
            Text("IPTV beheren")
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(providerName)
                .font(
                    .system(
                        size: 29,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    .cyan.opacity(0.90)
                )

            Text(providerTypeLabel)
                .font(.system(size: 18))
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.65)
                )
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let errorMessage {
            VStack(
                alignment: .leading,
                spacing: 16
            ) {
                Text(
                    "IPTV-instellingen konden niet worden geladen"
                )
                .font(.system(size: 26)) // ~20% increase from title2 (~21)

                Text(errorMessage)
                    .font(.system(size: 18)) // caption style
                    .foregroundStyle(.secondary)
            }
        } else if let configuration {
            managementOptions(
                configuration
            )
        } else {
            Text(
                "Er is geen IPTV-provider ingesteld."
            )
            .font(.system(size: 22))
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Management

    @ViewBuilder
    private func managementOptions(
        _ configuration:
            IPTVStoredConfiguration
    ) -> some View {
        VStack(
            alignment: .leading,
            spacing: 22
        ) {
            Text("INHOUD")
                .font(
                    .system(
                        size: 28,
                        weight: .semibold
                    )
                )
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.85)
                )

            NavigationLink {
                IPTVLiveManagementView()
            } label: {
                managementRow(
                    icon: "tv",
                    title: "LIVE TV BEHEREN",
                    subtitle:
                        "Categorieën en kanalen tonen of verbergen",
                    status: liveStatus
                )
            }
            .buttonStyle(.card)

            if case .xtream = configuration {
                NavigationLink {
                    IPTVVODManagementView()
                } label: {
                    managementRow(
                        icon: "film",
                        title: "VOD BEHEREN",
                        subtitle:
                            "VOD-lijsten en titels tonen of verbergen",
                        status: vodStatus
                    )
                }
                .buttonStyle(.card)
            }
        }
        .frame(
            maxWidth: 900,
            alignment: .leading
        )
    }

    private func managementRow(
        icon: String,
        title: String,
        subtitle: String,
        status: String
    ) -> some View {
        HStack(spacing: 24) {
            ZStack {
                RoundedRectangle(
                    cornerRadius: 16
                )
                .fill(
                    Color.cyan.opacity(0.10)
                )

                Image(
                    systemName: icon
                )
                .font(
                    .system(
                        size: 34,
                        weight: .light
                    )
                )
                .foregroundStyle(
                    Color.cyan.opacity(0.85)
                )
            }
            .frame(
                width: 90,
                height: 90
            )

            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Text(title)
                    .font(
                        .system(
                            size: 31,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.system(size: 23))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(
                alignment: .trailing,
                spacing: 8
            ) {
                Text(status)
                    .font(
                        .system(
                            size: 20,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        Color.cyan.opacity(0.75)
                    )

                Image(
                    systemName: "chevron.right"
                )
                .font(
                    .system(
                        size: 18,
                        weight: .semibold
                    )
                )
                .foregroundStyle(.secondary)
            }
        }
        .padding(24)
        .frame(
            width: 850,
            height: 145
        )
    }

    // MARK: - Status

    private var liveStatus: String {
        let hiddenCategories =
            preferences
                .hiddenLiveCategoryIDs
                .count

        let hiddenChannels =
            preferences
                .hiddenLiveChannelIDs
                .count

        let total =
            hiddenCategories +
            hiddenChannels

        guard total > 0 else {
            return "Alles zichtbaar"
        }

        return "\(total) verborgen"
    }

    private var vodStatus: String {
        let hiddenCategories =
            preferences
                .hiddenVODCategoryIDs
                .count

        let hiddenItems =
            preferences
                .hiddenVODItemIDs
                .count

        let total =
            hiddenCategories +
            hiddenItems

        guard total > 0 else {
            return "Alles zichtbaar"
        }

        return "\(total) verborgen"
    }

    private var providerName: String {
        guard let configuration else {
            return "IPTV"
        }

        switch configuration {
        case .xtream(let configuration):
            return configuration.displayName

        case .m3u(let configuration):
            return configuration.displayName
        }
    }

    private var providerTypeLabel: String {
        guard let configuration else {
            return "PROVIDER"
        }

        switch configuration {
        case .xtream:
            return "XTREAM"

        case .m3u:
            return "M3U"
        }
    }

    // MARK: - Loading

    private func loadConfiguration() {
        do {
            guard
                let configuration =
                    try configurationStore.load()
            else {
                self.configuration = nil

                preferences =
                    IPTVProviderPreferences()

                errorMessage = nil
                return
            }

            self.configuration =
                configuration

            preferences =
                preferencesStore.load(
                    for: configuration
                )

            errorMessage = nil
        } catch {
            configuration = nil

            preferences =
                IPTVProviderPreferences()

            errorMessage =
                error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        IPTVProviderManagementView()
    }
}
