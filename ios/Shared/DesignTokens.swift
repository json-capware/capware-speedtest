import SwiftUI

// MARK: - Brand colours
// iOS  — resolved from Shared/Colors.xcassets (supports light + dark automatically)
// watchOS — hardcoded; asset catalog named-colour lookup is unreliable in watch bundles

extension Color {

#if os(watchOS)

    // Surfaces
    static let capSurface = Color.black
    static let capCard    = Color(white: 0.10)
    static let capBorder  = Color(white: 0.22)

    // Text
    static let capText    = Color(white: 0.95)
    static let capSub     = Color(white: 0.82)
    static let capMuted   = Color(white: 0.55)

    // Brand
    static let capAccent  = Color(red: 0.00, green: 0.92, blue: 0.92)
    static let capAmber   = Color(red: 0.97, green: 0.65, blue: 0.12)
    static let capDark    = Color(white: 0.88)

    // Semantic
    static let capSuccess       = Color(red: 0.15, green: 0.95, blue: 0.45)
    static let capSuccessBg     = Color(red: 0.04, green: 0.20, blue: 0.10)
    static let capSuccessBorder = Color(red: 0.08, green: 0.35, blue: 0.18)
    static let capError         = Color(red: 0.97, green: 0.45, blue: 0.45)
    static let capErrorBg       = Color(red: 0.17, green: 0.05, blue: 0.05)
    static let capErrorBorder   = Color(red: 0.30, green: 0.10, blue: 0.10)
    static let capWarning       = Color(red: 0.97, green: 0.75, blue: 0.30)
    static let capWarningBg     = Color(red: 0.17, green: 0.12, blue: 0.05)
    static let capWarningBorder = Color(red: 0.30, green: 0.22, blue: 0.10)
    static let capAccentBg      = Color(red: 0.00, green: 0.16, blue: 0.16)
    static let capAccentBorder  = Color(red: 0.00, green: 0.35, blue: 0.35)
    static let capAccentFg      = Color(red: 0.00, green: 0.92, blue: 0.92)

#else

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

    // Semantic
    static let capSuccess       = Color("capSuccess")
    static let capSuccessBg     = Color("capSuccessBg")
    static let capSuccessBorder = Color("capSuccessBorder")
    static let capError         = Color("capError")
    static let capErrorBg       = Color("capErrorBg")
    static let capErrorBorder   = Color("capErrorBorder")
    static let capWarning       = Color("capWarning")
    static let capWarningBg     = Color("capWarningBg")
    static let capWarningBorder = Color("capWarningBorder")
    static let capAccentBg      = Color("capAccentBg")
    static let capAccentBorder  = Color("capAccentBorder")
    static let capAccentFg      = Color("capAccentFg")

#endif
}
