import SwiftUI

struct SettingsView: View {
    @ObservedObject var history: HistoryStore
    @State private var showConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 56)
                .padding(.bottom, 24)

            VStack(spacing: 0) {
                Button(role: .destructive) {
                    showConfirm = true
                } label: {
                    HStack {
                        Image(systemName: "trash")
                            .font(.system(size: 15))
                        Text("Delete All Test Data")
                            .font(.system(size: 15, weight: .medium))
                        Spacer()
                    }
                    .foregroundStyle(Color(red: 0.80, green: 0.20, blue: 0.20))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .background(Color.capCard)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.capBorder, lineWidth: 1))
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.capSurface.ignoresSafeArea())
        .confirmationDialog("Delete all test history?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Delete All", role: .destructive) {
                history.deleteAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Settings")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(Color.capText)
        }
    }
}

#Preview {
    SettingsView(history: HistoryStore())
}
