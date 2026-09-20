import SwiftUI

struct WatchProviderRow: View {
    let kind: ProviderMediaKind

    @Binding
    var selection: WatchProvider?

    @Binding
    var region: String

    @State
    private var providers: [WatchProvider] = []

    @State
    private var loading = false

    @State
    private var error: String?

    @State
    private var retry = 0

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            providerRow

            if let error {
                errorRow(error)
            }

            availabilityText
        }
        .task(
            id: "\(region)-\(retry)"
        ) {
            await load()
        }
    }

    // MARK: - Provider row

    private var providerRow: some View {
        ScrollView(
            .horizontal,
            showsIndicators: false
        ) {
            LazyHStack(
                spacing: 22
            ) {
                ForEach(
                    providers
                ) { provider in
                    providerButton(
                        provider
                    )
                }

                regionPicker

                if loading {
                    ProgressView()
                        .frame(
                            width: 100,
                            height: 82
                        )
                }
            }
            .padding(
                .horizontal,
                10
            )
            .padding(
                .vertical,
                14
            )
        }
        .scrollClipDisabled()
    }

    private var regionPicker: some View {
        Menu {
            regionButton("België", code: "BE")
            regionButton("Nederland", code: "NL")
            regionButton("Verenigde Staten", code: "US")
            regionButton("Verenigd Koninkrijk", code: "GB")
            regionButton("Frankrijk", code: "FR")
            regionButton("Duitsland", code: "DE")
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "globe.europe.africa.fill")
                    .foregroundStyle(VeyraColors.cyan)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Aanbod")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(VeyraColors.secondary)

                    Text(regionName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white.opacity(0.55))
            }
            .padding(.horizontal, 18)
            .frame(
                width: 290,
                height: 88
            )
        }
        .buttonStyle(
            VeyraFocusButtonStyle(
                radius: 28
            )
        )
    }

    private func regionButton(
        _ name: String,
        code: String
    ) -> some View {
        Button {
            region = code
        } label: {
            if region == code {
                Label(name, systemImage: "checkmark")
            } else {
                Text(name)
            }
        }
    }

    private var regionName: String {
        switch region {
        case "NL": "Nederland"
        case "US": "Verenigde Staten"
        case "GB": "Verenigd Koninkrijk"
        case "FR": "Frankrijk"
        case "DE": "Duitsland"
        default: "België"
        }
    }

    // MARK: - Provider button

    private func providerButton(
        _ provider: WatchProvider
    ) -> some View {
        let selected =
            selection?.id
            == provider.id

        return Button {
            selection =
                selected
                ? nil
                : provider

        } label: {
            WatchProviderLogo(
                provider: provider
            )
            .frame(
                width: 190,
                height: 88
            )
        }
        .buttonStyle(
            WatchProviderPillStyle(
                selected: selected
            )
        )
        .focusEffectDisabled()
        .accessibilityLabel(
            provider.name
        )
        .accessibilityHint(
            selected
            ? "Selecteer opnieuw om alle titels te tonen"
            : "Filter op deze streamingdienst"
        )
        .accessibilityAddTraits(
            selected
            ? [.isSelected]
            : []
        )
    }

    // MARK: - Error

    private func errorRow(
        _ message: String
    ) -> some View {
        HStack(
            spacing: 16
        ) {
            Text(message)
                .font(
                    .system(
                        size: 18
                    )
                )
                .foregroundStyle(
                    .orange
                )

            Button(
                "Opnieuw"
            ) {
                retry += 1
            }
            .font(
                .system(
                    size: 18
                )
            )
        }
    }

    // MARK: - Availability

    private var availabilityText: some View {
        Text(
            "Beschikbaarheid: JustWatch via TMDB · Abonnement, huur of koop kan nodig zijn."
        )
        .font(
            .system(
                size: 18
            )
        )
        .foregroundStyle(
            .secondary
        )
    }

    // MARK: - Loading

    @MainActor
    private func load() async {
        loading = true
        error = nil
        providers = []

        guard
            let token =
                AppConfiguration
                    .tmdbReadAccessToken
        else {
            error =
                "De metadataservice is niet geconfigureerd."

            loading = false

            return
        }

        do {
            let result =
                try await TMDBClient(
                    readAccessToken:
                        token
                )
                .watchProviders(
                    kind: kind,
                    region: region
                )

            try Task
                .checkCancellation()

            providers =
                result

        } catch {
            guard
                !Task.isCancelled
            else {
                return
            }

            self.error =
                "Streamingdiensten konden niet worden geladen."
        }

        loading = false
    }
}

// MARK: - Provider logo

private struct WatchProviderLogo: View {
    let provider: WatchProvider

    var body: some View {
        AsyncImage(
            url: provider.logoURL
        ) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: 166,
                        maxHeight: 66
                    )

            case .empty:
                ProgressView()
                    .scaleEffect(
                        0.8
                    )

            case .failure:
                placeholder

            @unknown default:
                placeholder
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(
            .horizontal,
            12
        )
        .padding(
            .vertical,
            9
        )
    }

    private var placeholder: some View {
        Image(
            systemName:
                "play.rectangle"
        )
        .font(
            .system(
                size: 32,
                weight: .medium
            )
        )
        .foregroundStyle(
            .cyan.opacity(
                0.75
            )
        )
    }
}

// MARK: - Provider pill style

private struct WatchProviderPillStyle:
    ButtonStyle
{
    let selected: Bool

    func makeBody(
        configuration: Configuration
    ) -> some View {
        WatchProviderPillSurface(
            label:
                configuration.label,
            selected:
                selected,
            pressed:
                configuration.isPressed
        )
    }
}

private struct WatchProviderPillSurface<
    Label: View
>: View {
    let label: Label

    let selected: Bool

    let pressed: Bool

    @Environment(\.isFocused)
    private var isFocused

    var body: some View {
        label
            .background(
                LinearGradient(
                    colors: [
                        Color.white.opacity(isFocused ? 0.13 : 0.06),
                        VeyraColors.surface.opacity(0.72)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .strokeBorder(
                    borderColor,
                    lineWidth:
                        isFocused
                        ? 3
                        : selected
                            ? 2
                            : 0
                )
            }
            .shadow(
                color:
                    isFocused
                    ? VeyraColors.cyan.opacity(0.30)
                    : .clear,
                radius:
                    isFocused
                    ? 14
                    : 0
            )
            .shadow(
                color: isFocused ? VeyraColors.red.opacity(0.14) : .clear,
                radius: isFocused ? 14 : 0,
                x: 8
            )
            .scaleEffect(
                pressed
                ? 0.98
                : isFocused
                    ? 1.055
                    : 1
            )
            .animation(
                .easeOut(
                    duration: 0.14
                ),
                value:
                    isFocused
            )
            .animation(
                .easeOut(
                    duration: 0.10
                ),
                value:
                    pressed
            )
    }

    private var borderColor: Color {
        if isFocused {
            return .cyan
        }

        if selected {
            return
                .cyan.opacity(
                    0.70
                )
        }

        return .clear
    }
}
