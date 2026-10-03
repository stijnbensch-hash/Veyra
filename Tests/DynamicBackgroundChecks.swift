import AppKit

@MainActor private enum BackgroundSamples {
    static var offsets: [String: CGFloat] = [:]
}
@MainActor private final class ScrollDriver: ObservableObject {
    @Published var target = 0
}
private struct BackgroundProbe: View {
    let name: String
    @Environment(\.veyraPageBackgroundOffset) private var offset
    var body: some View {
        Color.clear.frame(width: 1, height: 1)
            .onAppear { BackgroundSamples.offsets[name] = offset }
            .onChange(of: offset) { _, value in BackgroundSamples.offsets[name] = value }
    }
}
private struct ScrollContent: View {
    @ObservedObject var driver: ScrollDriver
    var horizontal = false
    var body: some View {
        ScrollViewReader { proxy in
            VeyraScrollView(horizontal ? .horizontal : .vertical) {
                if horizontal {
                    HStack(spacing: 0) {
                        ForEach(0..<60) { Color.clear.frame(width: 80, height: 200).id($0) }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(0..<60) { Color.clear.frame(width: 320, height: 80).id($0) }
                    }
                }
            }
            .onChange(of: driver.target) { _, value in proxy.scrollTo(value, anchor: .topLeading) }
        }
    }
}
private struct ScrollCheckPage: View {
    @ObservedObject var driver: ScrollDriver
    var horizontal = false
    var body: some View {
        VeyraDynamicBackgroundScope {
            ZStack {
                VeyraBackground()
                ScrollContent(driver: driver, horizontal: horizontal)
                BackgroundProbe(name: "page")
            }
        }
    }
}
private struct ListCheckPage: View {
    @ObservedObject var driver: ScrollDriver
    let form: Bool
    var body: some View {
        VeyraDynamicBackgroundScope {
            ZStack {
                ScrollViewReader { proxy in
                    Group {
                        if form {
                            VeyraForm {
                                Section("Instellingen") {
                                    ForEach(0..<80) { Text("Instelling \($0)").frame(height: 30).id($0) }
                                }
                            }
                        } else {
                            VeyraList { ForEach(0..<80) { Text("Titel \($0)").frame(height: 30).id($0) } }
                        }
                    }
                    .onChange(of: driver.target) { _, value in proxy.scrollTo(value, anchor: .top) }
                }
                BackgroundProbe(name: "page")
            }
        }
    }
}
private struct NestedCheckPage: View {
    @ObservedObject var driver: ScrollDriver
    var body: some View {
        VeyraDynamicBackgroundScope {
            ZStack {
                VeyraBackground()
                VStack {
                    BackgroundProbe(name: "outer")
                    VeyraDynamicBackgroundScope {
                        ZStack {
                            ScrollContent(driver: driver)
                            BackgroundProbe(name: "inner")
                        }
                    }
                }
            }
        }
    }
}
private final class FlippedScrollDocument: NSView {
    override var isFlipped: Bool { true }
}

@main private struct DynamicBackgroundChecks {
    @MainActor static func pump() { RunLoop.main.run(until: Date().addingTimeInterval(0.3)) }
    @MainActor static func host<Content: View>(_ content: Content) -> NSWindow {
        BackgroundSamples.offsets.removeAll()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content)
        window.orderBack(nil)
        window.contentView?.layoutSubtreeIfNeeded()
        pump()
        return window
    }
    @MainActor static func main() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let verticalDriver = ScrollDriver()
        let verticalWindow = host(ScrollCheckPage(driver: verticalDriver))
        let initial = BackgroundSamples.offsets["page"] ?? -1
        verticalDriver.target = 20; pump()
        let after = BackgroundSamples.offsets["page"] ?? -1
        print("vertical", initial, after); fflush(stdout)
        precondition(initial == 0 && after >= 600)
        precondition(VeyraNightGlow.phase(offset: after) != VeyraNightGlow.phase(offset: initial))
        verticalDriver.target = 0; pump()
        precondition(BackgroundSamples.offsets["page"] == 0, "Returning to top must restore color")
        verticalWindow.close()

        let horizontalDriver = ScrollDriver()
        let horizontalWindow = host(ScrollCheckPage(driver: horizontalDriver, horizontal: true))
        horizontalDriver.target = 20; pump()
        precondition(BackgroundSamples.offsets["page"] == 0, "Horizontal rows must not change color")
        horizontalWindow.close()

        for form in [false, true] {
            let driver = ScrollDriver()
            let window = host(ListCheckPage(driver: driver, form: form))
            driver.target = 20; pump()
            let offset = BackgroundSamples.offsets["page"] ?? -1
            print(form ? "form" : "list", offset); fflush(stdout)
            precondition(offset >= 600, "List/Form must report vertical scroll")
            window.close()
        }
        let nestedDriver = ScrollDriver()
        let nestedWindow = host(NestedCheckPage(driver: nestedDriver))
        nestedDriver.target = 20; pump()
        print("nested", BackgroundSamples.offsets); fflush(stdout)
        precondition((BackgroundSamples.offsets["inner"] ?? 0) >= 600)
        precondition(BackgroundSamples.offsets["outer"] == 0, "Child page must not recolor its parent")
        nestedWindow.close()

        // Exercise the public AppKit observer used by macOS 14 List/Form.
        let legacyWindow = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 400),
                                    styleMask: [.borderless], backing: .buffered, defer: false)
        legacyWindow.isReleasedWhenClosed = false
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 400, height: 400))
        let scroll = NSScrollView(frame: container.bounds)
        scroll.documentView = FlippedScrollDocument(frame: NSRect(x: 0, y: 0, width: 400, height: 4000))
        container.addSubview(scroll)
        let probe = VeyraLegacyListScrollProbe(frame: container.bounds)
        var legacyOffset: CGFloat = -1
        probe.onOffset = { legacyOffset = $0 }
        container.addSubview(probe)
        legacyWindow.contentView = container
        legacyWindow.orderBack(nil)
        pump(); probe.connect(); pump()
        precondition(legacyOffset == 0)
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 600)); pump()
        precondition(legacyOffset == 600, "Legacy list must report scroll offset")
        probe.disconnect()
        scroll.contentView.scroll(to: NSPoint(x: 0, y: 900)); pump()
        precondition(legacyOffset == 600, "Legacy observer must stop after page teardown")
        legacyWindow.close()

        print("PASS: scroll color, return to top, horizontal exclusion, lists/forms, page isolation, legacy observer cleanup")
    }
}
