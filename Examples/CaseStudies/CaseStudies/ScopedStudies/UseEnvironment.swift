import SwiftUI

struct UseEnvironment: View {
    var body: some View {
        StateScope {
            let colorScheme = useEnvironment(\.colorScheme)
            let locale = useEnvironment(\.locale)
            let timeZone = useEnvironment(\.timeZone)

            VStack(alignment: .leading, spacing: 12) {
                Text("Color scheme: \(colorScheme == .dark ? "dark" : "light")")
                Text("Locale: \(locale.identifier)")
                Text("Time zone: \(timeZone.identifier)")

                Text("Demo nay chi doc gia tri tu `EnvironmentValues` ma khong can property wrapper SwiftUI.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
