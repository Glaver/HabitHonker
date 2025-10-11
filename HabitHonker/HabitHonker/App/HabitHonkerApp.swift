import SwiftUI
import SwiftData
import CloudKit

@main
struct HabitHonkerApp: App {
    @AppStorage("appearance") private var appearanceRaw: String = HonkerColorSchema.auto.rawValue
    private var appearance: HonkerColorSchema { HonkerColorSchema(rawValue: appearanceRaw) ?? .auto }
    
    @State private var isBuildingContainer = false
    @State private var didInitialBuild = false
    @State private var container: ModelContainer?
    
    @StateObject private var sync = SyncManager()

    private let cloudID = "iCloud.com.flyingwhale.habithonker"
    private let schema = Schema([HabitSD.self, HabitRecordSD.self, DeletedHabitSD.self, StatisticsPresetSD.self])
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    let identity = container.configurations.first?.cloudKitContainerIdentifier ?? "local"
                    RootTabsView(container: container)
                        .id(identity)                    // <- ensures teardown before rebuild
                        .environmentObject(sync)
                        .modelContainer(container)
                } else {
                    Color(.systemBackground).ignoresSafeArea()
                }
            }
            .preferredColorScheme(appearance.colorScheme)
            .task {
//                await rebuildContainerIfNeeded(force: true)
//                sync.refreshAccountStatus()
                await sync.refreshAccountStatusAndWait()       // decide target once
                await rebuildContainerIfNeeded(force: true)    // build ONCE
                didInitialBuild = true
            }
            .onChange(of: sync.isOn) { _, _ in Task { await rebuildContainerIfNeeded() } }
            .onChange(of: sync.iCloudAvailable) { _, _ in
                guard didInitialBuild else { return }          // ignore the first publish
                Task { await rebuildContainerIfNeeded() }
            }
        }
    }

    @MainActor
    private func rebuildContainerIfNeeded(force: Bool = false) async {
        guard !isBuildingContainer else { return }
        isBuildingContainer = true
        defer { isBuildingContainer = false }

        let wantCloud = sync.isOn && sync.iCloudAvailable
        let currentID = container?.configurations.first?.cloudKitContainerIdentifier

        // No-op if nothing actually changes (unless forced)
        if !force {
            if wantCloud, currentID == cloudID { return }
            if !wantCloud, currentID == nil { return }
        }

        // Tear down old store FIRST to avoid 134422
        container = nil
        await Task.yield() // give old store a chance to deinit & unregister

        if wantCloud {
            let cfg = ModelConfiguration(
                "Cloud", schema: nil,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .private(cloudID)
            )
            container = try? ModelContainer(for: schema, configurations: cfg)
        } else {
            container = try? ModelContainer(for: schema)
        }

        // Fallback so app always starts
        if container == nil {
            container = try? ModelContainer(for: schema)
        }
    }
}
