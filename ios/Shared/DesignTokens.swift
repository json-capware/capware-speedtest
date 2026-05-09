import SwiftUI

// MARK: - Brand colours
// Single source of truth shared by the iOS app and the Watch app.
// Light/dark variants live in Shared/Colors.xcassets — SwiftUI resolves
// the correct shade automatically based on the system colour scheme.

extension Color {
    // Base
    static let capSurface = Color("capSurface")
    static let capCard    = Color("capCard")
    static let capBorder  = Color("capBorder")
    static let capText    = Color("capText")
    static let capSub     = Color("capSub")
    static let capMuted   = Color("capMuted")
    static let capAccent  = Color("capAccent")
    static let capAmber   = Color("capAmber")
    static let capDark    = Color("capDark")

    // Semantic — success / error / warning / accent tint
    static let capSuccess        = Color("capSuccess")
    static let capSuccessBg      = Color("capSuccessBg")
    static let capSuccessBorder  = Color("capSuccessBorder")
    static let capError          = Color("capError")
    static let capErrorBg        = Color("capErrorBg")
    static let capErrorBorder    = Color("capErrorBorder")
    static let capWarning        = Color("capWarning")
    static let capWarningBg      = Color("capWarningBg")
    static let capWarningBorder  = Color("capWarningBorder")
    static let capAccentBg       = Color("capAccentBg")
    static let capAccentBorder   = Color("capAccentBorder")
    static let capAccentFg       = Color("capAccentFg")
}
