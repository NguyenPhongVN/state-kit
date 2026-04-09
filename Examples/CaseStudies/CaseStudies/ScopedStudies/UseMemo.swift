import SwiftUI

struct UseMemo: View {
    
    var body: some View {
        StateScope {
            @SKScopeState var numberOne = 0
            @SKScopeState var numberTwo = 0
            
            @SKScopeMemo(updateStrategy: .preserved(by: numberOne))
            var memo = {
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
