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

                VStack(spacing: 28) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 70, weight: .medium))
                        .foregroundStyle(.cyan)

                    Text("VEYRA")
                        .font(.system(size: 72, weight: .light))
                        .tracking(18)
                        .foregroundStyle(.white)

                    Text("ALL YOUR MEDIA. ONE PLACE.")
                        .font(.system(size: 20, weight: .light))
                        .tracking(7)
                        .foregroundStyle(.white.opacity(0.65))

                    HStack(spacing: 48) {
                        NavigationLink("MOVIES") {
                            MoviesView()
                        }

                        Text("SERIES")
                        Text("LIVE TV")
                        Text("BEYOND")
                    }
                    .font(.system(size: 17, weight: .medium))
                    .tracking(4)
                    .foregroundStyle(.cyan.opacity(0.8))
                    .padding(.top, 15)
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
