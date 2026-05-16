import SwiftUI
import StateKit
import Riverpods

// MARK: - 1. Atoms (The Global State)

@Atom
struct CountAtom {
    func defaultValue(context: AtomContext) -> Int { 0 }
}

@SelectorAtom
struct IsEvenAtom {
    func select(context: AtomContext) -> Bool {
        context.watch(CountAtom()) % 2 == 0
    }
}

// MARK: - 2. Hooks (The Local State)

@HookToggle
struct IsToggledHook {}

@HookForm
struct RegistrationForm {
    var username: String = ""
    var email: String = ""
}

// MARK: - 3. Riverpod (The Service Layer)

@RiverpodAsync
final class userDataProvider async {
    try? await Task.sleep(nanoseconds: 1_000_000_000)
    return "User #\(Int.random(in: 1...100))"
}

// MARK: - 4. Unified View (The UI)

@StateView
struct ShowcaseView: View {
    // Atom Property Wrappers
    @SKState(CountAtom()) var count
    @SKValue(IsEvenAtom()) var isEven
    
    // Riverpod Property Wrappers
    @Watch(userDataProvider) var userName
    
    var stateBody: some View {
        // Custom Hooks
        let (isToggled, toggle) = useIsToggled()
        let form = useRegistrationForm()
        
        List {
            Section("Atoms") {
                HStack {
                    Text("Count: \(count)")
                    Spacer()
                    Button("+") { count += 1 }
                }
                Text("Is Even: \(isEven ? "Yes" : "No")")
            }
            
            Section("Hooks") {
                Toggle("Toggle Hook", isOn: Binding(get: { isToggled }, set: { _ in toggle() }))
                
                VStack(alignment: .leading) {
                    TextField("Username", text: form.username)
                        .textFieldStyle(.roundedBorder)
                    if !form.usernameError.wrappedValue.isEmpty {
                        Text(form.usernameError.wrappedValue).font(.caption).foregroundColor(.red)
                    }
                    
                    TextField("Email", text: form.email)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Validate Form") {
                        if form.validate() {
                            print("Form is valid!")
                        }
                    }
                }
            }
            
            Section("Riverpod") {
                switch userName {
                case .loading:
                    ProgressView()
                case .success(let name):
                    Text("Welcome, \(name)")
                case .failure(let error):
                    Text("Error: \(error.localizedDescription)")
                case .idle:
                    Text("Idle")
                }
            }
        }
        .navigationTitle("StateKit Showcase")
    }
}

// MARK: - 5. App Root

struct ShowcaseApp: App {
    var body: some Scene {
        WindowGroup {
            SKAtomRoot { // Required for Atoms
                ProviderScope { // Required for Riverpod
                    NavigationStack {
                        ShowcaseView()
                    }
                }
            }
        }
    }
}
