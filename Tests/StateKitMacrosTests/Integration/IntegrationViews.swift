import SwiftUI
import StateKitUI
import StateKitMacros

// MARK: - Module 3: Profile Feature (16 Hook + 4 View Macros)

@HookView
struct ProfileDashboardView: View {
    
    // MARK: Hooks (16)
    
    private struct Hooks {
        @Hook
        static func useAnalytics() {
        }
    }
    
    @HookState
    struct CounterHook { var value: Int = 0 }
    
    @HookRef
    struct AnimationRefHook { var offset: Double = 0.0 }
    
    @HookToggle
    struct IsEditingHook {}
    
    @HookEffect
    struct LoggerHook {
        func run() async {
            print("Profile Loaded")
        }
    }
    
    @AsyncHook
    struct UploaderHook {
        func run() async {}
    }
    
    @HookPrevious
    struct LastScoreHook { let score: Int }
    
    @HookInterval
    struct AutoRefreshHook {
        var intervalMs: Int = 5000
        func tick() async {}
    }
    
    @HookMemo
    struct ExpensiveTitleHook {
        func compute() -> String { "User Dashboard" }
    }
    
    @HookCallback
    struct ShareHandlerHook { func call() {} }
    
    @HookReducer
    struct PreferencesHook {
        typealias State = Bool
        typealias Action = Int
        func reduce(_ s: inout Bool, action: Int) {
            s = (action > 0)
        }
    }
    
    @HookContext
    struct AppContextHook { var version: String = "1.0" }
    
    @HookForm
    struct ProfileFormHook {
        var name: String = ""
        var bio: String = ""
    }
    
    private struct SearchHook {
        @Debounce(milliseconds: 300)
        static func search() async {}
    }
    
    private struct LikeHook {
        @Throttle(milliseconds: 500)
        static func like() async {}
    }

    var stateBody: some View {
        Hooks.useAnalytics()

        let _ = useCounterHook(value: 0)
        let _ = useAnimationRefHook(offset: 0.0)
        let (isEditing, toggleEditing) = useIsEditingHook()
        
        useLoggerHook()
        useUploaderHook()
        
        let _ = useLastScoreHook(score: 10)
        useAutoRefreshHook(intervalMs: 1000)
        
        let _ = useExpensiveTitleHook()
        let _ = useShareHandlerHook()
        let _ = usePreferencesHook()
        let _ = useAppContextHook()
        
        let form = useProfileFormHook()
        
        return VStack {
            TextField("Name", text: form.name)
            Button("Toggle Edit") {
                toggleEditing()
            }
            if isEditing {
                Button("Like") {
                    LikeHook.likeThrottled()
                }
                Button("Search") {
                    SearchHook.searchDebounced()
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

@AsyncView(atom: UserModule.SessionAtom()) 
struct ProfileAsyncView: View {
    var stateBody: some View {
        Text("Loaded")
    }
}

@ObservableState
struct GlobalUIState {
    var sidebarVisible = true
}
