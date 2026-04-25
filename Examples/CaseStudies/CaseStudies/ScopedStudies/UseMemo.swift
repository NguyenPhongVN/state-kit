import SwiftUI

struct UseMemo: View {
    var body: some View {
        StateScope {
            @HState var numberOne = 0
            @HState var numberTwo = 0

            let memo = useMemo(updateStrategy: .preserved(by: numberOne)) {
                "Memo token: \(Int.random(in: 100...999))"
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("numberOne: \(numberOne)")
                Text("numberTwo: \(numberTwo)")
                Text("Memo: \(memo)")
                    .font(.title3.monospacedDigit())

                Text("Tang `numberTwo` se render lai view, nhung memo chi doi khi `numberOne` doi.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Increment numberOne") {
                        numberOne += 1
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Increment numberTwo") {
                        numberTwo += 1
                    }
                }
                .buttonStyle(.bordered)

                Button("Reset") {
                    numberOne = 0
                    numberTwo = 0
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
