import SwiftUI
struct VeyraAsyncImage<Content: View>: View {
    let rendered: Content
    init<Placeholder: View>(url: URL?, maxPixelSize: Int = 1920,
         @ViewBuilder content: (Image) -> Content,
         @ViewBuilder placeholder: () -> Placeholder) {
        rendered = content(Image(systemName: "photo"))
    }
    init(url: URL?, @ViewBuilder content: (AsyncImagePhase) -> Content) {
        rendered = content(.success(Image(systemName: "photo")))
    }
    var body: some View { rendered }
}
