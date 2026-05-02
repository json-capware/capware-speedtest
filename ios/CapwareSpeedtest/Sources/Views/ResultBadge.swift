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

    // Uses semantic colors from the design system
    private var fg: Color {
        switch mbps {
        case ..<10:   return Color(red: 0.41, green: 0.12, blue: 0.12)  // error fg
        case ..<50:   return Color(red: 0.41, green: 0.30, blue: 0.12)  // warning fg
        case ..<200:  return Color(red: 0.12, green: 0.41, blue: 0.22)  // success fg
        default:      return Color(red: 0.00, green: 0.58, blue: 0.58)  // accent-600
        }
    }

    private var bg: Color {
        switch mbps {
        case ..<10:   return Color(red: 0.97, green: 0.93, blue: 0.93)  // error bg
        case ..<50:   return Color(red: 0.97, green: 0.95, blue: 0.93)  // warning bg
        case ..<200:  return Color(red: 0.93, green: 0.97, blue: 0.94)  // success bg
        default:      return Color(red: 0.95, green: 1.00, blue: 1.00)  // accent-50
        }
    }

    private var border: Color {
        switch mbps {
        case ..<10:   return Color(red: 0.88, green: 0.69, blue: 0.69)  // error border
        case ..<50:   return Color(red: 0.88, green: 0.81, blue: 0.69)  // warning border
        case ..<200:  return Color(red: 0.69, green: 0.88, blue: 0.76)  // success border
        default:      return Color(red: 0.68, green: 0.98, blue: 0.98)  // accent-200
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
