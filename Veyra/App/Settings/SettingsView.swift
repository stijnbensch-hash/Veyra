import SwiftUI

struct SettingsView: View {
    @State private var configuration:
        IPTVStoredConfiguration?

    @State private var errorMessage: String?

    private let configurationStore =
        IPTVConfigurationStore()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(
                        red: 0.01,
                        green: 0.04,
                        blue: 0.07
                    ),
                    Color(
                        red: 0.02,
                        green: 0.10,
                        blue: 0.16
                    )
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(
                alignment: .leading,
                spacing: 34
            ) {
                header

                settingsContent

                Spacer()
            }
            .padding(70)
        }
        .onAppear {
            loadConfiguration()
        }
    }

    // MARK: - Header

    private var header: some View {
        Text("INSTELLINGEN")
            .font(
                .system(
                    size: 54,
                    weight: .light
                )
            )
            .tracking(10)
            .foregroundStyle(.white)
    }

    // MARK: - Settings

    private var settingsContent: some View {
        VStack(
            alignment: .leading,
            spacing: 22
        ) {
            Text("BRONNEN")
                .font(
                    .system(
                        size: 22,
                        weight: .semibold
                    )
                )
                .tracking(3)
                .foregroundStyle(
                    .cyan.opacity(0.85)
                )

            NavigationLink {
                IPTVAccountsView()
            } label: {
                settingsRow(
                    icon: "tv",
                    title: "IPTV",
                    subtitle:
                        "Live TV en VOD via Xtream of M3U",
                    status: iptvStatus
                )
            }
            .buttonStyle(.card)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .frame(
            maxWidth: 900,
            alignment: .leading
        )
    }

    private func settingsRow(
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
                            size: 26,
                            weight: .semibold
                        )
                    )
                    .foregroundStyle(.white)

                Text(subtitle)
                    .font(.body)
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
                            size: 17,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        configuration == nil
                            ? Color.white.opacity(0.45)
                            : Color.cyan.opacity(0.85)
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

    // MARK: - IPTV Status

    private var iptvStatus: String {
        guard let configuration else {
            return "Niet ingesteld"
        }

        switch configuration {
        case .m3u:
            return "M3U"

        case .xtream:
            return "Xtream"
        }
    }

    private func loadConfiguration() {
        do {
            configuration =
                try configurationStore.load()

            errorMessage = nil
        } catch {
            configuration = nil
            errorMessage =
                error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
