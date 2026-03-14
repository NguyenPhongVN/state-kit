import SwiftUI

struct UseMemo: View {
    
    var body: some View {
        StateScope {
            @HState var numberOne = 0
            @HState var numberTwo = 0
            
            @HMemo(deps: [numberOne])
            var memo: Int = {
                Int.random(in: 1...100)
            }()
            
            VStack {
                
                Text("numberOne: \(numberOne)")
                Text("numberTwo: \(numberTwo)")
                Text("Memo: \(memo)")
                
                Button("Increment") {
                    numberOne += 1
                }
                
                Button("Increment 2") {
                    numberTwo += 1
                }
            }
        }
    }
}
