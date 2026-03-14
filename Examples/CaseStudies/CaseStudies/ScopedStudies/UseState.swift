import SwiftUI

struct UseState: View {
    
    var body: some View {
        StateScope {
            
            let (count, countSetter) = useState(0)
            
            VStack {
                
                Text("Count: \(count)")
                
                Button("Increment") {
                    countSetter(count + 1)
                }
                
            }
        }
    }
}
