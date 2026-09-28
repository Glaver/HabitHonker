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
    @State private var storageDurability: StorageDurabilityState?
    /// Incremented for every newly opened container, so the whole view tree (and every view model
    /// bound to the previous container's dependency graph) is rebuilt for the new store.
    @State private var storeGeneration = 0
    @State private var appCoordinator: AppCoordinator?
    
    @StateObject private var sync = SyncManager()

    private let schema = Schema(versionedSchema: HabitHonkerSchemaV2.self)
    
    var body: some Scene {
        WindowGroup {
            Group {
                if let container, let appCoordinator {
                    RootTabsView(container: container, dependencies: appCoordinator.dependencies)
                        .id(storeGeneration)             // <- new container: fresh view models, no old-store services
                        .environmentObject(appCoordinator)
                        .environmentObject(sync)
                        .modelContainer(container)
                } else {
                    Color(.systemBackground).ignoresSafeArea()
                }
            }
            .preferredColorScheme(appearance.colorScheme)
            .task {
                if sync.isOn {
                    // Choosing the iCloud store depends on the account state.
                    await sync.refreshAccountStatusAndWait()
                    await rebuildContainerIfNeeded(force: true)
                } else {
                    // The local store needs no iCloud account and no CloudKit: open it right away.
                    await rebuildContainerIfNeeded(force: true)
                    // Still refreshed, because the Settings sync toggle uses it.
                    await sync.refreshAccountStatusAndWait()
                }
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

        let request: PersistentStoreFactory.Request = (sync.isOn && sync.iCloudAvailable) ? .cloud : .local

        // No-op if the requested durable world is already open (unless forced). The decision uses
        // the durability recorded when the store was opened, not a guess from its CloudKit settings.
        if !force, appCoordinator != nil {
            if request == .cloud, storageDurability == .durableCloud { return }
            if request == .local, storageDurability == .durableLocal { return }
        }

        // Tear down old store FIRST to avoid 134422
        container = nil
        storageDurability = nil
        appCoordinator = nil
        await Task.yield() // give old store a chance to deinit & unregister

        // Local: the pre-4F default store with CloudKit disabled. Cloud: unchanged.
        // Either failing: in-memory fallback so the app still starts, classified as ephemeral.
        guard let opened = PersistentStoreFactory.openStore(for: request, schema: schema) else { return }
        container = opened.container
        storageDurability = opened.durability
        storeGeneration += 1
        appCoordinator = AppCoordinator(dependencies: .make(container: opened.container,
                                                           storageDurability: opened.durability))
    }
}
