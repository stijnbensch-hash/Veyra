import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.01, green: 0.04, blue: 0.07),
                        Color(red: 0.02, green: 0.10, blue: 0.16)
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
                        .frame(maxWidth: 900, maxHeight: 560)
                        .accessibilityLabel("Veyra")

                    HStack(spacing: 60) {
                        NavigationLink("FILMS") {
                            MoviesView()
                        }

                        Text("SERIES")
                        Text("LIVE TV")
                        Text("BEYOND")
                    }
                    .font(.system(size: 19, weight: .medium))
                    .tracking(5)
                    .foregroundStyle(.cyan.opacity(0.85))

                    Spacer()
                }
                .padding(.horizontal, 70)
                .padding(.vertical, 35)
            }
        }
    }
}

#Preview {
    ContentView()
}
