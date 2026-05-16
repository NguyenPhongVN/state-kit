import Foundation
import SwiftUI
import RealityKit
import Riverpods
import StateKit
import StateKitAtoms

// MARK: - visionOS Spatial Computing Example

/// Complete example of StateKit for visionOS spatial computing.
///
/// Demonstrates:
/// - 3D state management
/// - Hand gesture handling
/// - Spatial UI composition
/// - Multi-window state synchronization

// MARK: - Models

struct SpatialObject: Sendable, Identifiable {
    let id: String
    var position: SIMD3<Float>
    var rotation: simd_quatf
    var scale: Float
    var color: String
    var isSelected: Bool

    mutating func move(by offset: SIMD3<Float>) {
        position += offset
    }

    mutating func rotate(by quaternion: simd_quatf) {
        rotation = quaternion * rotation
    }

    mutating func setScale(_ newScale: Float) {
        scale = max(0.1, min(10.0, newScale))
    }
}

struct GestureInput: Sendable {
    let type: GestureType
    let position: SIMD3<Float>
    let velocity: SIMD3<Float>?
    let timestamp: Date

    enum GestureType: String, Sendable {
        case tap
        case pinch
        case drag
        case rotate
        case pan
    }
}

// MARK: - State

@SKStateAtom
var spatialObjectsAtom: [SpatialObject] = [
    SpatialObject(id: "obj1", position: [0, 0, -1], rotation: simd_quatf(), scale: 1.0, color: "red", isSelected: false),
    SpatialObject(id: "obj2", position: [0.5, 0, -1], rotation: simd_quatf(), scale: 0.8, color: "blue", isSelected: false),
    SpatialObject(id: "obj3", position: [-0.5, 0, -1], rotation: simd_quatf(), scale: 1.2, color: "green", isSelected: false),
]

@SKStateAtom
var selectedObjectIdAtom: String?

@SKStateAtom
var gestureHistoryAtom: [GestureInput] = []

@SKStateAtom
var viewModeAtom: ViewMode = .object

enum ViewMode: String, Sendable {
    case object  // Edit individual objects
    case scene   // Edit entire scene
    case inspect // Inspect properties
}

// MARK: - Providers

let selectedObjectProvider = Provider { ref -> SpatialObject? in
    let selectedId = ref.watch(selectedObjectIdAtom)
    let objects = ref.watch(spatialObjectsAtom)
    return objects.first { $0.id == selectedId }
}

let objectCountProvider = Provider { ref -> Int in
    ref.watch(spatialObjectsAtom).count
}

let lastGestureProvider = Provider { ref -> GestureInput? in
    ref.watch(gestureHistoryAtom).last
}

// MARK: - Notifiers

let spatialNotifier = NotifierProvider { ref -> SpatialNotifier in
    SpatialNotifier(ref: ref)
}

final class SpatialNotifier: Notifier, Sendable {
    let ref: NotifierProviderRef

    init(ref: NotifierProviderRef) {
        self.ref = ref
    }

    /// Selects an object in 3D space
    func selectObject(_ id: String) {
        var objects = ref.read(spatialObjectsAtom)

        // Deselect all
        for i in 0..<objects.count {
            objects[i].isSelected = false
        }

        // Select new
        if let index = objects.firstIndex(where: { $0.id == id }) {
            objects[index].isSelected = true
            ref.read(spatialObjectsAtom.notifier).state = objects
            ref.read(selectedObjectIdAtom.notifier).state = id
        }
    }

    /// Moves selected object
    func moveObject(offset: SIMD3<Float>) {
        var objects = ref.read(spatialObjectsAtom)
        guard let selectedId = ref.read(selectedObjectIdAtom),
              let index = objects.firstIndex(where: { $0.id == selectedId }) else { return }

        objects[index].move(by: offset)
        ref.read(spatialObjectsAtom.notifier).state = objects

        recordGesture(.drag, position: objects[index].position, velocity: offset)
    }

    /// Scales selected object (pinch gesture)
    func scaleObject(by factor: Float) {
        var objects = ref.read(spatialObjectsAtom)
        guard let selectedId = ref.read(selectedObjectIdAtom),
              let index = objects.firstIndex(where: { $0.id == selectedId }) else { return }

        objects[index].setScale(objects[index].scale * factor)
        ref.read(spatialObjectsAtom.notifier).state = objects

        recordGesture(.pinch, position: objects[index].position)
    }

    /// Rotates selected object
    func rotateObject(by quaternion: simd_quatf) {
        var objects = ref.read(spatialObjectsAtom)
        guard let selectedId = ref.read(selectedObjectIdAtom),
              let index = objects.firstIndex(where: { $0.id == selectedId }) else { return }

        objects[index].rotate(by: quaternion)
        ref.read(spatialObjectsAtom.notifier).state = objects

        recordGesture(.rotate, position: objects[index].position)
    }

    /// Adds new object to scene
    func addObject(at position: SIMD3<Float>, color: String = "gray") {
        let object = SpatialObject(
            id: UUID().uuidString,
            position: position,
            rotation: simd_quatf(),
            scale: 1.0,
            color: color,
            isSelected: true
        )

        var objects = ref.read(spatialObjectsAtom)
        objects.append(object)
        ref.read(spatialObjectsAtom.notifier).state = objects
        ref.read(selectedObjectIdAtom.notifier).state = object.id

        recordGesture(.tap, position: position)
    }

    /// Deletes selected object
    func deleteSelected() {
        guard let selectedId = ref.read(selectedObjectIdAtom) else { return }

        var objects = ref.read(spatialObjectsAtom)
        objects.removeAll { $0.id == selectedId }
        ref.read(spatialObjectsAtom.notifier).state = objects
        ref.read(selectedObjectIdAtom.notifier).state = nil
    }

    /// Changes view mode
    func setViewMode(_ mode: ViewMode) {
        ref.read(viewModeAtom.notifier).state = mode
    }

    private func recordGesture(_ type: GestureInput.GestureType, position: SIMD3<Float>, velocity: SIMD3<Float>? = nil) {
        let gesture = GestureInput(type: type, position: position, velocity: velocity, timestamp: Date())

        var history = ref.read(gestureHistoryAtom)
        history.append(gesture)

        // Keep last 50 gestures
        if history.count > 50 {
            history.removeFirst()
        }

        ref.read(gestureHistoryAtom.notifier).state = history
    }
}

// MARK: - visionOS Views

struct VisionOSExampleView: View {
    @Watch(var objects: spatialObjectsAtom)
    @Watch(var selectedObject: selectedObjectProvider)
    @Watch(var viewMode: viewModeAtom)
    @Watch(var objectCount: objectCountProvider)

    var body: some View {
        ZStack {
            // 3D Content (simulated)
            SpatialCanvasView(objects: objects)
                .ignoresSafeArea()

            // UI Overlay
            VStack(alignment: .leading) {
                // Top bar
                HStack {
                    Text("Spatial Editor")
                        .font(.title2).bold()

                    Spacer()

                    HStack(spacing: 12) {
                        Button(action: { addObject() }) {
                            Image(systemName: "plus.circle")
                        }

                        Menu {
                            Button("Object", action: { setViewMode(.object) })
                            Button("Scene", action: { setViewMode(.scene) })
                            Button("Inspect", action: { setViewMode(.inspect) })
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.5))

                Spacer()

                // Bottom panels
                HStack(spacing: 12) {
                    // Object list
                    VStack(alignment: .leading) {
                        Text("Objects (\(objectCount))")
                            .font(.caption).bold()

                        ScrollView {
                            VStack(spacing: 8) {
                                ForEach(objects) { obj in
                                    ObjectItemView(
                                        object: obj,
                                        isSelected: selectedObject?.id == obj.id,
                                        onSelect: { selectObject(obj.id) }
                                    )
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(12)

                    // Inspector
                    if let selected = selectedObject {
                        InspectorPanelView(object: selected)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(12)
                    }
                }
                .padding()
            }
            .foregroundColor(.white)
        }
    }

    private func addObject() {
        let container = ProviderContainer()
        container.read(spatialNotifier).addObject(at: [0, 0, -1], color: "purple")
    }

    private func selectObject(_ id: String) {
        let container = ProviderContainer()
        container.read(spatialNotifier).selectObject(id)
    }

    private func setViewMode(_ mode: ViewMode) {
        let container = ProviderContainer()
        container.read(spatialNotifier).setViewMode(mode)
    }
}

struct SpatialCanvasView: View {
    let objects: [SpatialObject]

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // 3D Objects (simplified visualization)
            VStack(spacing: 30) {
                ForEach(objects) { obj in
                    ObjectRepresentation(object: obj)
                }
            }
        }
    }
}

struct ObjectRepresentation: View {
    let object: SpatialObject

    var color: Color {
        switch object.color {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        default: return .gray
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(color)
                .opacity(object.isSelected ? 0.8 : 0.6)

            if object.isSelected {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yellow, lineWidth: 2)
            }

            Text(object.id.prefix(4))
                .font(.caption).bold()
                .foregroundColor(.white)
        }
        .frame(width: 80 * CGFloat(object.scale), height: 80 * CGFloat(object.scale))
    }
}

struct ObjectItemView: View {
    let object: SpatialObject
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                Circle()
                    .fill(colorForName(object.color))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(object.id.prefix(8) + "...")
                        .font(.caption).bold()

                    Text("Scale: \(String(format: "%.1f", object.scale))x")
                        .font(.caption2)
                        .opacity(0.7)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.white.opacity(0.2) : Color.clear)
            .cornerRadius(6)
        }
    }

    private func colorForName(_ name: String) -> Color {
        switch name {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "purple": return .purple
        default: return .gray
        }
    }
}

struct InspectorPanelView: View {
    let object: SpatialObject

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Inspector")
                .font(.caption).bold()

            VStack(alignment: .leading, spacing: 4) {
                Text("Position: (\(String(format: "%.2f", object.position.x)), \(String(format: "%.2f", object.position.y)), \(String(format: "%.2f", object.position.z)))")
                    .font(.caption2)

                Text("Scale: \(String(format: "%.2f", object.scale))")
                    .font(.caption2)

                Text("Color: \(object.color)")
                    .font(.caption2)
            }
            .opacity(0.8)
        }
        .frame(maxWidth: 200)
    }
}

// MARK: - Preview

#Preview {
    VisionOSExampleView()
}
