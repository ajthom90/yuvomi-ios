import SwiftUI

struct WelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "house.lodge.fill")
                .font(.system(size: 64))
                .foregroundStyle(YuvomiColors.overview)
                .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text("Yuvomi")
                    .font(.largeTitle.bold())
                Text("Your family’s private planner on a server you own. Connect this app to your self-hosted Yuvomi instance.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading, spacing: 10) {
                Label("No vendor cloud — only your server", systemImage: "lock.shield")
                Label("API token or username & password", systemImage: "key.fill")
                Label("Open source · MIT License", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 360, alignment: .leading)
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onContinue) {
                Text("Connect to server")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(YuvomiColors.overview)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }
}
