import SwiftUI

private final class DemoCallbackBox {
    let perform: () -> Void

    init(_ perform: @escaping () -> Void) {
        self.perform = perform
    }
}

struct UseCallback: View {
    var body: some View {
        StateScope {
            @HState var query = "swift"
            @HState var unrelatedCount = 0
            @HState var callbackRebuilds = 0
            @HState var submitted = "Chua submit"

            let callbackBox = useCallback(
                updateStrategy: .preserved(by: query),
                DemoCallbackBox {
                    submitted = "Submitted query: \(query)"
                }
            )

            let callbackIdentity = ObjectIdentifier(callbackBox)

            let _ = useOnChange(callbackIdentity, initial: true) { _ in
                callbackRebuilds += 1
            }

            VStack(alignment: .leading, spacing: 12) {
                TextField("Query", text: $query)
                    .textFieldStyle(.roundedBorder)

                Text(submitted)
                Text("Callback rebuilt: \(callbackRebuilds) lan")
                Text("Unrelated local state: \(unrelatedCount)")
                    .foregroundStyle(.secondary)

                Text("Tang unrelated state khong lam callback doi. Doi `query` moi rebuild callback.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Submit") {
                        callbackBox.perform()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Change unrelated state") {
                        unrelatedCount += 1
                    }

                    Button("Preset query") {
                        query = "state-kit"
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
