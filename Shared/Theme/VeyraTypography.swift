import SwiftUI

enum VeyraTypography {
#if os(tvOS)
    // 10-foot UI: viewed from the couch, so sizes stay large.
    static let hero = Font.system(size: 54, weight: .bold, design: .rounded)
    static let section = Font.system(size: 28, weight: .bold, design: .rounded)
    static let body = Font.system(size: 23, weight: .regular, design: .rounded)
#else
    // Phone/tablet: same design, scaled down for a handheld screen.
    static let hero = Font.system(size: 32, weight: .bold, design: .rounded)
    static let section = Font.system(size: 19, weight: .bold, design: .rounded)
    static let body = Font.system(size: 15, weight: .regular, design: .rounded)
#endif
}
