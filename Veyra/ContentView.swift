import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
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

                VStack(spacing: 36) {
                    Spacer()

                    Image("VeyraPrimaryLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(
                            maxWidth: 900,
                            maxHeight: 560
                        )
                        .accessibilityLabel("Veyra")

                    HStack(spacing: 24) {
                        NavigationLink {
                            MoviesView()
                        } label: {
                            Text("FILM")
                        }
                        .buttonStyle(
                            VeyraMenuButtonStyle()
                        )

                        NavigationLink {
                            SeriesView()
                        } label: {
                            Text("SERIES")
                        }
                        .buttonStyle(
                            VeyraMenuButtonStyle()
                        )

                        NavigationLink {
                            SearchView()
                        } label: {
                            Text("ZOEKEN")
                        }
                        .buttonStyle(
                            VeyraMenuButtonStyle()
                        )

                        NavigationLink {
                            LiveTVView()
                        } label: {
                            Text("LIVE TV")
                        }
                        .buttonStyle(
                            VeyraMenuButtonStyle()
                        )

                        NavigationLink {
                            SettingsView()
                        } label: {
                            Text("INSTELLINGEN")
                        }
                        .buttonStyle(
                            VeyraMenuButtonStyle()
                        )

                        menuItem(
                            title: "BEYOND"
                        )
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
                .padding(.horizontal, 70)
                .padding(.vertical, 35)
            }
        }
    }

    private func menuItem(
        title: String
    ) -> some View {
        Text(title)
            .font(
                .system(
                    size: 19,
                    weight: .medium
                )
            )
            .tracking(5)
            .foregroundStyle(
                .cyan.opacity(0.30)
            )
            .padding(.horizontal, 22)
            .padding(.vertical, 15)
    }
}

struct VeyraMenuButtonStyle: ButtonStyle {
    @Environment(\.isFocused)
    private var isFocused

    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .font(
                .system(
                    size: 19,
                    weight: isFocused
                        ? .semibold
                        : .medium
                )
            )
            .tracking(5)
            .foregroundStyle(
                isFocused
                    ? .white
                    : .cyan.opacity(0.55)
            )
            .padding(.horizontal, 22)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(
                    cornerRadius: 14
                )
                .fill(
                    isFocused
                        ? .cyan.opacity(0.16)
                        : .clear
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 14
                )
                .stroke(
                    isFocused
                        ? .cyan.opacity(0.65)
                        : .clear,
                    lineWidth: 1
                )
            )
            .scaleEffect(
                isFocused ? 1.06 : 1.0
            )
            .animation(
                .easeOut(duration: 0.15),
                value: isFocused
            )
    }
}

#Preview {
    ContentView()
}
