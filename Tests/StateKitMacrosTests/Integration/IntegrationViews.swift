import SwiftUI
import StateKitUI
import StateKitMacros

// MARK: - Module 3: Profile Feature (16 Hook + 4 View Macros)

@HookView
struct ProfileDashboardView: View {
    
    // MARK: Hooks (16)
    
    @Hook
    func useAnalytics() {
    }
    
    @CustomHook
    func useTheme() {
    }
    
    @HookState
    struct Counter {
        var value: Int = 0
    }
    
    @HookRef
    struct AnimationRef {
        var offset: Double = 0.0
    }
    
    @HookToggle
    struct IsEditing {
    }
    
    @HookEffect
    struct Logger {
        func run() async {
            print("Profile Loaded")
        }
    }
    
    @AsyncHook
    struct Uploader {
        func run() async {
            // Simulated upload
        }
    }
    
    @HookPrevious
    struct LastScore {
        let score: Int
    }
    
    @HookInterval
    struct AutoRefresh {
        var intervalMs: Int = 5000
        func tick() async {
        }
    }
    
    @HookMemo
    struct ExpensiveTitle {
        func compute() -> String {
            "User Dashboard"
        }
    }
    
    @HookCallback
    struct ShareHandler {
        func call() {
        }
    }
    
    @HookReducer
    struct Preferences: Hashable {
        typealias State = Bool
        typealias Action = Int
        
        func reduce(_ s: inout Bool, action: Int) {
            s = (action > 0)
        }
    }
    
    @HookContext
    struct AppContext {
        var version: String = "1.0"
    }
    
    @HookForm
    struct ProfileForm {
        var name: String = ""
        var bio: String = ""
    }
    
    @Debounce(milliseconds: 300)
    static func search() async {
    }
    
    @Throttle(milliseconds: 500)
    static func like() async {
    }

    var stateBody: some View {
        useAnalytics()
        useTheme()
        
        let _ = useCounter()
        let _ = useAnimationRef()
        let (isEditing, toggleEditing) = useIsEditing()
        
        useLogger()
        useUploader()
        
        let _ = useLastScore(score: 10)
        useAutoRefresh(intervalMs: 1000)
        
        let _ = useExpensiveTitle()
        let _ = useShareHandler()
        let _ = usePreferences()
        let _ = useAppContext()
        
        let form = useProfileForm()
        
        return VStack {
            TextField("Name", text: form.name)
            Button("Toggle Edit") {
                toggleEditing()
            }
            if isEditing {
                Button("Like") {
                    Self.like_throttled()
                }
                Button("Search") {
                    Self.search_debounced()
                }
            }
        }
    }
}

// MARK: - Additional View Macros

@StateView
struct SimpleHeader: View {
    var stateBody: some View {
        Text("Header")
    }
}

@AsyncView(atom: UserModule.SessionAtom.shared) 
struct ProfileAsyncView: View {
    var stateBody: some View {
        Text("Loaded")
    }
}

@ObservableState
struct GlobalUIState {
    var sidebarVisible = true
}
