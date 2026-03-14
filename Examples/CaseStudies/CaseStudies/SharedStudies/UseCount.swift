import SwiftUI

let counterKey = StateKey<Int>("counter")
let counterKey2 = StateKey<Int>("counter2")

//struct UseCount: View {
//    
//    @WatchState(counterKey, default: 0)
//    var count
//    
//    var body: some View {
//        VStack {
//            Text("\(count)")
//            
//            Button("Increase") {
//                count += 1
//            }
//            
//            UseCount2()
//        }
//    }
//}
//
//struct UseCount2: View {
//    
//    @WatchState(counterKey, default: 0)
//    var count
//    
//    @ViewContext
//    var context
//    
//    var body: some View {
//        VStack {
//            Text("\(context.get(key: counterKey, default: 0))")
//            
//            Button("Increase") {
//                count += 1
//            }
//        }
//    }
//}
