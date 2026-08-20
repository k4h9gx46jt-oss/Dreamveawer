import SwiftUI

/// A dismissible-looking prompt shown when Health access is unavailable or not yet granted.
/// Gives the reviewer (and the user) a clear explanation and a single action.
struct HealthAccessBanner: View {
    let descriptor: HealthAccessState.Descriptor
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: descriptor.opensSettings ? "heart.slash.fill" : "heart.text.square.fill")
                .font(.title2)
                .foregroundStyle(.pink)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(descriptor.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(descriptor.message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: action) {
                    Text(descriptor.actionTitle)
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                .padding(.top, 4)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.thinMaterial)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(descriptor.title)
        .accessibilityHint(descriptor.message)
        .padding(.horizontal)
    }
}
