import SwiftUI

struct ResultBadge: View {

    let mbps: Double

    private var label: String {
        switch mbps {
        case ..<10:   return "Slow"
        case ..<50:   return "Fair"
        case ..<200:  return "Good"
        case ..<500:  return "Fast"
        default:      return "Excellent"
        }
    }

    private var fg: Color {
        switch mbps {
        case ..<10:   return .capError
        case ..<50:   return .capWarning
        case ..<200:  return .capSuccess
        default:      return .capAccentFg
        }
    }

    private var bg: Color {
        switch mbps {
        case ..<10:   return .capErrorBg
        case ..<50:   return .capWarningBg
        case ..<200:  return .capSuccessBg
        default:      return .capAccentBg
        }
    }

    private var border: Color {
        switch mbps {
        case ..<10:   return .capErrorBorder
        case ..<50:   return .capWarningBorder
        case ..<200:  return .capSuccessBorder
        default:      return .capAccentBorder
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.5)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(bg)
            .foregroundStyle(fg)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(border, lineWidth: 1))
    }
}
