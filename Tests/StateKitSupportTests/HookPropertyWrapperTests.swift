import Testing
import StateKit
import StateKitTesting
import StateKitSupport
import SwiftUI

@Suite("StateKitSupport — Hook Property Wrappers")
@MainActor
struct HookPropertyWrapperTests {
    
    @Test("@HState basic usage")
    func testHState() {
        let h = StateTest()
        
        func render() -> (String, Binding<String>) {
            h.render {
                @HState var name = "Initial"
                return (name, $name)
            }
        }
        
        var (name, binding) = render()
        #expect(name == "Initial")
        
        binding.wrappedValue = "Updated"
        
        (name, binding) = render()
        #expect(name == "Updated")
    }
    
    @Test("@HMemo caching")
    func testHMemo() {
        let h = StateTest()
        var computeCount = 0
        
        func render(dep: Int) -> Int {
            h.render {
                @HMemo(updateStrategy: .preserved(by: dep)) var value = {
                    computeCount += 1
                    return dep * 2
                }()
                return value
            }
        }
        
        #expect(render(dep: 1) == 2)
        #expect(computeCount == 1)
        
        #expect(render(dep: 1) == 2)
        #expect(computeCount == 1)
        
        #expect(render(dep: 2) == 4)
        #expect(computeCount == 2)
    }
    
    @Test("@HRef persistence")
    func testHRef() {
        let h = StateTest()
        
        func render() -> Int {
            h.render {
                @HRef var count = 0
                return count
            }
        }
        
        #expect(render() == 0)
        
        h.render {
            @HRef var count = 0
            count = 42
        }
        
        #expect(render() == 42)
    }
}
