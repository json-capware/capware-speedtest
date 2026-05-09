import SwiftUI

// MARK: - Brand colours
// Single source of truth shared by the iOS app and the Watch app.
// Light/dark variants live in Shared/Colors.xcassets — SwiftUI resolves
// the correct shade automatically based on the system colour scheme.

extension Color {
    static let capSurface = Color("capSurface")
    static let capCard    = Color("capCard")
    static let capBorder  = Color("capBorder")
    static let capText    = Color("capText")
    static let capSub     = Color("capSub")
    static let capMuted   = Color("capMuted")
    static let capAccent  = Color("capAccent")
    static let capAmber   = Color("capAmber")
    static let capDark    = Color("capDark")
}
