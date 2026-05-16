import Foundation
import SwiftUI
import CloudKit
import Riverpods
import StateKit
import StateKitAtoms

// MARK: - CloudKit Integration Example

/// Complete example of StateKit + CloudKit integration.
///
/// Demonstrates:
/// - Syncing StateKit state with CloudKit
/// - Handling sync conflicts
/// - Offline-first architecture
/// - Real-time updates from Cloud

// MARK: - Models

struct CloudNote: Sendable, Codable, Identifiable {
    let id: String
    let title: String
    let content: String
    let createdAt: Date
    let modifiedAt: Date
    var isSyncedToCloud: Bool = false

    var needsSync: Bool { modifiedAt > createdAt }
}

// MARK: - State

@SKStateAtom
var notesAtom: [CloudNote] = []

@SKStateAtom
var syncStateAtom: SyncState = .idle

@SKStateAtom
var lastSyncTimeAtom: Date?

enum SyncState: String, Sendable {
    case idle
    case syncing
    case synced
    case error(String)

    var description: String {
        switch self {
        case .idle: return "Ready"
        case .syncing: return "Syncing..."
        case .synced: return "Synced"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

// MARK: - Providers

/// Notes that need syncing
let unsyncedNotesProvider = Provider { ref -> [CloudNote] in
    let notes = ref.watch(notesAtom)
    return notes.filter { !$0.isSyncedToCloud || $0.needsSync }
}

/// Sync status
let syncStatusProvider = Provider { ref -> String in
    let state = ref.watch(syncStateAtom)
    let lastSync = ref.watch(lastSyncTimeAtom)

    switch state {
    case .idle:
        if let last = lastSync {
            return "Last synced: \(lastSync?.formatted() ?? "")"
        }
        return "Not synced"
    case .syncing:
        return "Syncing..."
    case .synced:
        return "All synced"
    case .error(let msg):
        return "Error: \(msg)"
    }
}

// MARK: - CloudKit Notifier

let cloudKitNotifier = NotifierProvider { ref -> CloudKitNotifier in
    CloudKitNotifier(ref: ref)
}

final class CloudKitNotifier: Notifier, Sendable {
    let ref: NotifierProviderRef

    init(ref: NotifierProviderRef) {
        self.ref = ref
    }

    /// Creates new note (local first)
    func createNote(title: String, content: String) {
        let note = CloudNote(
            id: UUID().uuidString,
            title: title,
            content: content,
            createdAt: Date(),
            modifiedAt: Date(),
            isSyncedToCloud: false
        )

        var notes = ref.read(notesAtom)
        notes.append(note)
        ref.read(notesAtom.notifier).state = notes

        // Schedule sync
        scheduleSync()
    }

    /// Updates note
    func updateNote(_ id: String, title: String, content: String) {
        var notes = ref.read(notesAtom)

        if let index = notes.firstIndex(where: { $0.id == id }) {
            notes[index].title = title
            notes[index].content = content
            notes[index].modifiedAt = Date()
            notes[index].isSyncedToCloud = false
            ref.read(notesAtom.notifier).state = notes

            scheduleSync()
        }
    }

    /// Deletes note
    func deleteNote(_ id: String) {
        var notes = ref.read(notesAtom)
        notes.removeAll { $0.id == id }
        ref.read(notesAtom.notifier).state = notes

        scheduleSync()
    }

    /// Synchronizes with CloudKit
    func syncWithCloud() async {
        updateSyncState(.syncing)

        do {
            let unsynced = ref.read(unsyncedNotesProvider)

            // Simulate CloudKit upload
            try await Task.sleep(nanoseconds: 1_000_000_000)

            // Mark as synced
            var notes = ref.read(notesAtom)
            for unsyncedNote in unsynced {
                if let index = notes.firstIndex(where: { $0.id == unsyncedNote.id }) {
                    notes[index].isSyncedToCloud = true
                }
            }

            ref.read(notesAtom.notifier).state = notes
            ref.read(lastSyncTimeAtom.notifier).state = Date()

            updateSyncState(.synced)

            // Reset to idle after 2 seconds
            try await Task.sleep(nanoseconds: 2_000_000_000)
            updateSyncState(.idle)
        } catch {
            updateSyncState(.error(error.localizedDescription))
        }
    }

    /// Fetches notes from CloudKit
    func fetchFromCloud() async {
        updateSyncState(.syncing)

        do {
            // Simulate CloudKit fetch
            try await Task.sleep(nanoseconds: 1_000_000_000)

            // In real app: fetch from CloudKit and merge
            // For demo: just mark as synced
            var notes = ref.read(notesAtom)
            notes = notes.map { note in
                var updated = note
                updated.isSyncedToCloud = true
                return updated
            }

            ref.read(notesAtom.notifier).state = notes
            ref.read(lastSyncTimeAtom.notifier).state = Date()

            updateSyncState(.synced)

            try await Task.sleep(nanoseconds: 2_000_000_000)
            updateSyncState(.idle)
        } catch {
            updateSyncState(.error(error.localizedDescription))
        }
    }

    private func scheduleSync() {
        // In real app: debounce and sync
        Task {
            await syncWithCloud()
        }
    }

    private func updateSyncState(_ state: SyncState) {
        ref.read(syncStateAtom.notifier).state = state
    }
}

// MARK: - Conflict Resolution

/// Handles CloudKit sync conflicts
struct ConflictResolver: Sendable {
    enum Strategy {
        case preferLocal
        case preferRemote
        case merge((local: CloudNote, remote: CloudNote) -> CloudNote)
    }

    static func resolve(
        local: CloudNote,
        remote: CloudNote,
        strategy: Strategy
    ) -> CloudNote {
        switch strategy {
        case .preferLocal:
            return local

        case .preferRemote:
            return remote

        case .merge(let merger):
            return merger((local, remote))
        }
    }

    /// Default merge: combine changes chronologically
    static let defaultMerge: (CloudNote, CloudNote) -> CloudNote = { local, remote in
        // If remote is newer, use remote
        if remote.modifiedAt > local.modifiedAt {
            return remote
        }

        // Otherwise keep local
        return local
    }
}

// MARK: - Views

struct CloudKitIntegrationView: View {
    @Watch(var notes: notesAtom)
    @Watch(var syncStatus: syncStatusProvider)
    @Watch(var unsyncedCount: unsyncedNotesProvider.count)

    @State private var showAddNote = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Sync status bar
                HStack {
                    Text(syncStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if unsyncedCount > 0 {
                        Badge(count: unsyncedCount)
                    }

                    Button(action: syncNow) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color(.systemGray6))

                // Notes list
                List {
                    if notes.isEmpty {
                        Text("No notes yet")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .listRowSeparator(.hidden)
                    } else {
                        ForEach(notes) { note in
                            NoteRowView(
                                note: note,
                                onEdit: { showAddNote = true },
                                onDelete: { deleteNote(note.id) }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Cloud Notes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showAddNote = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddNote) {
                AddNoteView(isPresented: $showAddNote)
            }
        }
    }

    private func syncNow() {
        let container = ProviderContainer()
        let notifier = container.read(cloudKitNotifier)

        Task {
            await notifier.syncWithCloud()
        }
    }

    private func deleteNote(_ id: String) {
        let container = ProviderContainer()
        let notifier = container.read(cloudKitNotifier)
        notifier.deleteNote(id)
    }
}

struct NoteRowView: View {
    let note: CloudNote
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(note.title)
                        .font(.headline)

                    if !note.isSyncedToCloud {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                }

                Text(note.content)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Text(note.modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .swipeActions {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct AddNoteView: View {
    @Binding var isPresented: Bool
    @State private var title = ""
    @State private var content = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Note") {
                    TextField("Title", text: $title)
                    TextField("Content", text: $content, axis: .vertical)
                        .lineLimit(5...10)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { isPresented = false }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let container = ProviderContainer()
                        container.read(cloudKitNotifier).createNote(title: title, content: content)
                        isPresented = false
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

struct Badge: View {
    let count: Int

    var body: some View {
        Text("\(count)")
            .font(.caption2).bold()
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange)
            .cornerRadius(4)
    }
}

// MARK: - Preview

#Preview {
    CloudKitIntegrationView()
}
