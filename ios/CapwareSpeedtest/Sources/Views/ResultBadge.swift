import SwiftUI

struct ResultBadge: View {

    let mbps: Double

    private var label: String {
        switch mbps {
        case ..<10:   return "Slow"
        case ..<50:   return "Fair"
        case ..<200:  return "Good"
        case ..<500:  return "Fast"
        default:      return "Blazing"
        }
    }

    private var color: Color {
        switch mbps {
        case ..<10:   return .red
        case ..<50:   return .orange
        case ..<200:  return .green
        case ..<500:  return .cyan
        default:      return .indigo
        }
    }

    var body: some View {
        Text(label)
            .font(.system(size: 13, weight: .semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
    }
}
