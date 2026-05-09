import SwiftUI

// MARK: - Brand colours
// Single source of truth shared by the iOS app and the Watch app.
// Never duplicate these values anywhere else.

extension Color {
    static let capSurface = Color(red: 0.98, green: 0.98, blue: 0.98)   // #fafafa  background
    static let capCard    = Color.white                                   // card background
    static let capBorder  = Color(red: 0.91, green: 0.89, blue: 0.89)   // #e7e4e4  dividers / ring track
    static let capText    = Color(red: 0.16, green: 0.14, blue: 0.14)   // #282424  primary text
    static let capSub     = Color(red: 0.47, green: 0.43, blue: 0.43)   // #786d6d  secondary text
    static let capMuted   = Color(red: 0.71, green: 0.69, blue: 0.69)   // #b6afaf  tertiary / labels
    static let capAccent  = Color(red: 0.00, green: 0.81, blue: 0.81)   // #00cece  brand cyan / download
    static let capAmber   = Color(red: 0.97, green: 0.65, blue: 0.12)   // #f7a61f  ping / warning
    static let capDark    = Color(red: 0.10, green: 0.09, blue: 0.09)   // #1a1717  upload
}
