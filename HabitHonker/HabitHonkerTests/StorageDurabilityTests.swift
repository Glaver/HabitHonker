import Foundation
import SwiftData
import SwiftUI
import XCTest
@testable import HabitHonker

/// Phase 4F: explicit storage durability, a CloudKit-free durable local store that reopens the
/// pre-4F local store file, and container-scoped dependency graphs.
///
/// No test opens a CloudKit-backed container: a test must never read or write a real iCloud account.
@MainActor
final class StorageDurabilityTests: XCTestCase {

    // MARK: F19–F21 — durability gate

    func testDurabilityGateAllowsDurableGamificationOnlyOnPersistentStorage() {
        XCTAssertTrue(StorageDurabilityState.durableCloud.supportsDurableGamification)
        XCTAssertTrue(StorageDurabilityState.durableLocal.supportsDurableGamification)
        XCTAssertFalse(StorageDurabilityState.ephemeralFallback.supportsDurableGamification)
        XCTAssertEqual(StorageDurabilityState.allCases.count, 3)
    }

    // MARK: F1–F3, F15–F18 — the state reaches AppDependencies; construction writes nothing

    func testEveryDurabilityStateReachesAppDependenciesWithoutGamificationWrites() throws {
        for state in StorageDurabilityState.allCases {
            let store = try TxStore.memory()
            let dependencies = AppDependencies.make(container: store, storageDurability: state)
            XCTAssertEqual(dependencies.storageDurability, state)
            try Phase2TestStore.assertNewTablesEmpty(ModelContext(store))
        }
    }

    // MARK: F1/F4 — a local request opens a durable, CloudKit-free store

    func testLocalRequestOpensDurableLocalStoreWithoutCloudKit() throws {
        let directory = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("default.store")

        let openedValue = PersistentStoreFactory.openStore(for: .local, schema: v2Schema(), localStoreURL: url)
        let opened = try XCTUnwrap(openedValue)

        XCTAssertEqual(opened.durability, .durableLocal)
        let configuration = try XCTUnwrap(opened.container.configurations.first)
        XCTAssertEqual(configuration.url, url)
        XCTAssertNil(configuration.cloudKitContainerIdentifier, "durableLocal must not be tied to a CloudKit container")
        XCTAssertFalse(configuration.isStoredInMemoryOnly)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let dependencies = AppDependencies.make(container: opened.container, storageDurability: opened.durability)
        XCTAssertEqual(dependencies.storageDurability, .durableLocal)
        try Phase2TestStore.assertNewTablesEmpty(ModelContext(opened.container))
    }

    func testLocalConfigurationExplicitlyDisablesCloudKit() throws {
        let configuration = PersistentStoreFactory.localConfiguration(schema: v2Schema())
        XCTAssertNil(configuration.cloudKitContainerIdentifier)
        XCTAssertFalse(configuration.isStoredInMemoryOnly)
        XCTAssertTrue(configuration.allowsSave)

        // The intent is written out, not inherited from a default: LOCAL MEANS NO CLOUDKIT.
        let source = try appSource("App/PersistentStoreFactory.swift")
        let body = try XCTUnwrap(source.components(separatedBy: "static func localConfiguration").last?
            .components(separatedBy: "\n    }").first)
        XCTAssertTrue(body.contains("cloudKitDatabase: .none"))
        XCTAssertFalse(body.contains(".private("))
        XCTAssertFalse(body.contains(".automatic"))
    }

    // MARK: F5 — the cloud world is unchanged

    func testCloudConfigurationKeepsTheApprovedPrivateCloudKitStore() {
        let cloud = PersistentStoreFactory.cloudConfiguration()
        let preFourF = ModelConfiguration("Cloud", schema: nil, isStoredInMemoryOnly: false, allowsSave: true,
                                          groupContainer: .automatic,
                                          cloudKitDatabase: .private("iCloud.com.flyingwhale.habithonker"))
        XCTAssertEqual(cloud.cloudKitContainerIdentifier, "iCloud.com.flyingwhale.habithonker")
        XCTAssertEqual(cloud.cloudKitContainerIdentifier, preFourF.cloudKitContainerIdentifier)
        XCTAssertEqual(cloud.name, "Cloud")
        XCTAssertEqual(cloud.url, preFourF.url)
        XCTAssertEqual(cloud.url.lastPathComponent, "Cloud.store")
        XCTAssertFalse(cloud.isStoredInMemoryOnly)
    }

    func testSuccessfulCloudStoreIsClassifiedDurableCloud() throws {
        let openedValue = PersistentStoreFactory.openStore(for: .cloud, schema: v2Schema(), build: { schema, configuration in
            XCTAssertEqual(configuration.cloudKitContainerIdentifier, PersistentStoreFactory.cloudKitContainerIdentifier)
            // Stand-in for the iCloud store: tests never open a real CloudKit-backed container.
            let standIn = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            return try PersistentStoreFactory.buildVersionedContainer(schema: schema, configuration: standIn)
        })
        let opened = try XCTUnwrap(openedValue)

        XCTAssertEqual(opened.durability, .durableCloud)
        let dependencies = AppDependencies.make(container: opened.container, storageDurability: opened.durability)
        XCTAssertEqual(dependencies.storageDurability, .durableCloud)
        XCTAssertTrue(dependencies.storageDurability.supportsDurableGamification)
    }

    // MARK: F3 — failures fall back to an in-memory store that is classified as ephemeral

    func testFailedLocalStoreFallsBackToEphemeralAndOrdinaryHabitsStillWork() async throws {
        var attempted: [ModelConfiguration] = []
        let neverOpened = FileManager.default.temporaryDirectory.appendingPathComponent("phase4f-never-opened.store")
        let openedValue = PersistentStoreFactory.openStore(for: .local, schema: v2Schema(), localStoreURL: neverOpened,
                                                           build: { schema, configuration in
            attempted.append(configuration)
            guard configuration.isStoredInMemoryOnly else { throw StorageTestFailure.persistentStoreUnavailable }
            return try PersistentStoreFactory.buildVersionedContainer(schema: schema, configuration: configuration)
        })
        let opened = try XCTUnwrap(openedValue)

        XCTAssertEqual(opened.durability, .ephemeralFallback)
        XCTAssertEqual(attempted.count, 2)
        XCTAssertEqual(attempted.first?.url, neverOpened)
        let fallback = try XCTUnwrap(opened.container.configurations.first)
        XCTAssertTrue(fallback.isStoredInMemoryOnly)
        XCTAssertNil(fallback.cloudKitContainerIdentifier, "Ephemeral storage must never mirror to iCloud")
        let dependencies = AppDependencies.make(container: opened.container, storageDurability: opened.durability)
        XCTAssertFalse(dependencies.storageDurability.supportsDurableGamification)

        // Legacy habit behavior keeps working on the fallback store.
        let created = try await dependencies.habitService.createHabit(ScopingFixture.habit("Fallback habit"))
        let completed = try await dependencies.habitService.completeHabit(id: created.id)
        XCTAssertEqual(completed?.record.count, 1)
        try Phase2TestStore.assertNewTablesEmpty(ModelContext(opened.container))
    }

    func testFailedCloudStoreIsNeverReportedAsDurable() throws {
        var attempted: [ModelConfiguration] = []
        let openedValue = PersistentStoreFactory.openStore(for: .cloud, schema: v2Schema(), build: { schema, configuration in
            attempted.append(configuration)
            guard configuration.isStoredInMemoryOnly else { throw StorageTestFailure.persistentStoreUnavailable }
            return try PersistentStoreFactory.buildVersionedContainer(schema: schema, configuration: configuration)
        })
        let opened = try XCTUnwrap(openedValue)

        XCTAssertEqual(attempted.map(\.name), [PersistentStoreFactory.cloudConfigurationName,
                                               PersistentStoreFactory.fallbackConfigurationName])
        XCTAssertEqual(attempted.first?.cloudKitContainerIdentifier, PersistentStoreFactory.cloudKitContainerIdentifier)
        XCTAssertEqual(opened.durability, .ephemeralFallback)
    }

    // MARK: F6 — durableLocal reopens the pre-4F store identity, never a new file

    func testLocalConfigurationUsesThePreFourFDefaultStoreFile() {
        let schema = v2Schema()
        let local = PersistentStoreFactory.localConfiguration(schema: schema)
        // Before 4F, sync-off called ModelContainer(for:migrationPlan:) without a configuration,
        // i.e. SwiftData's default configuration.
        let preFourFDefault = ModelConfiguration(schema: schema)
        XCTAssertEqual(local.url, preFourFDefault.url, "durableLocal must reopen the existing store, not a new empty one")
        XCTAssertEqual(local.name, preFourFDefault.name)
        XCTAssertEqual(local.url, ModelConfiguration(schema: Schema(versionedSchema: HabitHonkerSchemaV1.self)).url)
        XCTAssertNotEqual(local.url, PersistentStoreFactory.cloudConfiguration().url, "Local and cloud stay separate worlds")
        XCTAssertEqual(local.url.lastPathComponent, "default.store")

        // Characterization for the 4F report: how the pre-4F sync-off configuration resolved.
        let preFourFCloudKit = preFourFDefault.cloudKitContainerIdentifier ?? "nil"
        let localCloudKit = local.cloudKitContainerIdentifier ?? "nil"
        let cloudFile = PersistentStoreFactory.cloudConfiguration().url.lastPathComponent
        let facts = [
            "PHASE 4F PROBE pre-4F sync-off configuration: file=\(preFourFDefault.url.lastPathComponent)",
            "name=\(preFourFDefault.name)",
            "cloudKitContainerIdentifier=\(preFourFCloudKit);",
            "durableLocal cloudKitContainerIdentifier=\(localCloudKit);",
            "cloud file=\(cloudFile)",
        ].joined(separator: " ")
        print(facts)
        let attachment = XCTAttachment(string: facts)
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: F7–F14 — store continuity on disk, then normal CRUD across close/reopen

    func testPreFourFLocalDataSurvivesDurableLocalAndStaysWritableAcrossReopen() async throws {
        let schema = v2Schema()
        let directory = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        // A scratch store with the same file name as SwiftData's default configuration; never the app's real store.
        let url = directory.appendingPathComponent(ModelConfiguration(schema: schema).url.lastPathComponent)

        // Phase A — representative pre-4F user data, written through the pre-4F construction shape
        // (versioned V2 schema + migration plan, the default configuration's name and file name).
        // CloudKit is off here only because a test must never write to a real iCloud account
        // (see the 4F report).
        let seeded: [String: [String: AnyHashable?]] = try autoreleasepool {
            let preFourFName = ModelConfiguration(schema: schema).name
            let configuration = ModelConfiguration(preFourFName, schema: schema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, migrationPlan: HabitHonkerMigrationPlan.self,
                                               configurations: configuration)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            ContinuityFixture.insertPreFourFUserData(into: context)
            try context.save()
            return try Phase2TestStore.legacySnapshot(context)
        }
        XCTAssertEqual(seeded.count, ContinuityFixture.seededRowCount)

        // Phase B — the production durableLocal path opens the SAME file.
        do {
            let openedValue = PersistentStoreFactory.openStore(for: .local, schema: schema, localStoreURL: url)
            let opened = try XCTUnwrap(openedValue)
            XCTAssertEqual(opened.durability, .durableLocal)
            let context = ModelContext(opened.container)
            // F8–F11: habit ids and metadata, record UUIDs/dates/counts and parent links, archive,
            // statistics preset — identical; nothing disappeared, nothing duplicated.
            XCTAssertEqual(try Phase2TestStore.legacySnapshot(context), seeded)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitSD>()), 2)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitRecordSD>()), 6)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<DeletedHabitSD>()), 1)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<StatisticsPresetSD>()), 1)
            try Phase2TestStore.assertNewTablesEmpty(context)

            // F12–F14: normal repository operations on the reopened store.
            let dependencies = AppDependencies.make(container: opened.container, storageDurability: opened.durability)
            _ = try await dependencies.habitService.createHabit(ContinuityFixture.habitAddedAfterFourF())
            let loaded = try await dependencies.habitService.fetchHabit(id: ContinuityFixture.gym)
            var gym = try XCTUnwrap(loaded)
            gym.title = "Gym (after 4F)"
            gym.record = [] // a wrong draft history must be ignored by the 4A metadata update
            let renamed = try await dependencies.habitService.updateHabit(gym)
            XCTAssertEqual(Set(renamed.record.map(\.id)), ContinuityFixture.gymRecordIDs)
            let completed = try await dependencies.habitService.completeHabit(id: ContinuityFixture.taxes)
            XCTAssertEqual(completed?.record.count, 2)
            try await dependencies.habitRepository.saveStatisticsPresetHabitIDs([ContinuityFixture.gym, ContinuityFixture.added],
                                                                               presetName: "After 4F")
            try Phase2TestStore.assertNewTablesEmpty(ModelContext(opened.container))
        }

        // Phase C — close, reopen through the factory again: every change persisted.
        do {
            let openedValue = PersistentStoreFactory.openStore(for: .local, schema: schema, localStoreURL: url)
            let reopened = try XCTUnwrap(openedValue)
            XCTAssertEqual(reopened.durability, .durableLocal)
            let dependencies = AppDependencies.make(container: reopened.container, storageDurability: reopened.durability)

            let habits = try await dependencies.habitService.fetchHabits()
            XCTAssertEqual(Set(habits.map(\.id)), [ContinuityFixture.gym, ContinuityFixture.taxes, ContinuityFixture.added])
            let gym = habits.first { $0.id == ContinuityFixture.gym }
            XCTAssertEqual(gym?.title, "Gym (after 4F)")
            XCTAssertEqual(gym.map { Set($0.record.map(\.id)) }, ContinuityFixture.gymRecordIDs)
            XCTAssertEqual(gym?.record.reduce(0) { $0 + $1.count }, 6)
            let taxes = habits.first { $0.id == ContinuityFixture.taxes }
            XCTAssertEqual(taxes?.record.count, 2)
            XCTAssertEqual(taxes?.record.reduce(0) { $0 + $1.count }, 2)

            let archivedValue = try await dependencies.habitService.fetchDeletedHabit(id: ContinuityFixture.archived)
            let archived = try XCTUnwrap(archivedValue)
            XCTAssertEqual(archived.title, "Old habit")
            XCTAssertEqual(Set(archived.record.map(\.id)), ContinuityFixture.archivedRecordIDs)
            let presetIDs = try await dependencies.habitRepository.fetchStatisticsPresetHabitIDs()
            XCTAssertEqual(presetIDs, [ContinuityFixture.gym, ContinuityFixture.added])

            let context = ModelContext(reopened.container)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitRecordSD>()), 7)
            XCTAssertEqual(try context.fetchCount(FetchDescriptor<StatisticsPresetSD>()), 1)
            try Phase2TestStore.assertNewTablesEmpty(context)
        }
    }

    // MARK: F22 — independently created containers get independently scoped graphs

    func testIndependentlyCreatedContainersGetIndependentlyScopedGraphs() async throws {
        let first = try TxStore.memory()
        let second = try TxStore.memory()
        let a = AppDependencies.make(container: first, storageDurability: .durableLocal)
        let b = AppDependencies.make(container: second, storageDurability: .durableCloud)

        let onlyInA = try await a.habitService.createHabit(ScopingFixture.habit("Only in A"))
        let seenByB = try await b.habitService.fetchHabit(id: onlyInA.id)
        XCTAssertNil(seenByB)
        let onlyInB = try await b.habitService.createHabit(ScopingFixture.habit("Only in B"))
        _ = try await b.habitService.completeHabit(id: onlyInB.id)

        let habitsA = try await a.habitService.fetchHabits()
        let habitsB = try await b.habitService.fetchHabits()
        XCTAssertEqual(habitsA.map(\.id), [onlyInA.id])
        XCTAssertEqual(habitsB.map(\.id), [onlyInB.id])
        XCTAssertEqual(habitsA.first?.record.count, 0)
        XCTAssertEqual(a.storageDurability, .durableLocal)
        XCTAssertEqual(b.storageDurability, .durableCloud)
        for store in [first, second] {
            try Phase2TestStore.assertNewTablesEmpty(ModelContext(store))
        }
    }

    // MARK: F23 — rebuilding the graph for a new store never reaches the old one

    func testRebuildingTheGraphForANewStoreLeavesTheOldStoreUntouched() async throws {
        let schema = v2Schema()
        let directory = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let oldValue = PersistentStoreFactory.openStore(for: .local, schema: schema,
                                                        localStoreURL: directory.appendingPathComponent("old.store"))
        let oldStore = try XCTUnwrap(oldValue)
        var dependencies = AppDependencies.make(container: oldStore.container, storageDurability: oldStore.durability)
        let oldHabit = try await dependencies.habitService.createHabit(ScopingFixture.habit("Before switch"))

        // Switch worlds the way HabitHonkerApp does: new container → brand-new graph.
        let newValue = PersistentStoreFactory.openStore(for: .local, schema: schema,
                                                        localStoreURL: directory.appendingPathComponent("new.store"))
        let newStore = try XCTUnwrap(newValue)
        dependencies = AppDependencies.make(container: newStore.container, storageDurability: newStore.durability)
        let newHabit = try await dependencies.habitService.createHabit(ScopingFixture.habit("After switch"))
        _ = try await dependencies.habitService.completeHabit(id: newHabit.id)
        let oldThroughNewGraph = try await dependencies.habitService.completeHabit(id: oldHabit.id)
        XCTAssertNil(oldThroughNewGraph, "The new graph must not reach the old store")

        let oldContext = ModelContext(oldStore.container)
        XCTAssertEqual(try oldContext.fetch(FetchDescriptor<HabitSD>()).map(\.id), [oldHabit.id])
        XCTAssertEqual(try oldContext.fetchCount(FetchDescriptor<HabitRecordSD>()), 0)
        let newContext = ModelContext(newStore.container)
        XCTAssertEqual(try newContext.fetch(FetchDescriptor<HabitSD>()).map(\.id), [newHabit.id])
        XCTAssertEqual(try newContext.fetchCount(FetchDescriptor<HabitRecordSD>()), 1)
    }

    // MARK: Structural guards

    func testCompositionRootIsTheOnlyStoreBuilderAndPassesDurability() throws {
        let app = try appSource("App/HabitHonkerApp.swift")
        XCTAssertFalse(app.contains("ModelContainer("), "Only PersistentStoreFactory constructs containers")
        XCTAssertFalse(app.contains("ModelConfiguration("), "Only PersistentStoreFactory chooses configurations")
        XCTAssertTrue(app.contains("PersistentStoreFactory.openStore("))
        XCTAssertTrue(app.contains("storageDurability: opened.durability"))

        let factory = try appSource("App/PersistentStoreFactory.swift")
        XCTAssertFalse(factory.contains("HabitsRepositorySwiftData"), "No second repository actor")
        XCTAssertFalse(factory.contains("static var"), "No mutable global storage state")
        for forbidden in ["GamificationProfileSD", "GamificationLedgerEntrySD", "TaskOccurrenceSD", "BehaviorEventSD"] {
            XCTAssertFalse(factory.contains(forbidden), forbidden)
        }

        let dependencies = try appSource("App/AppDependencies.swift")
        XCTAssertEqual(dependencies.components(separatedBy: "HabitsRepositorySwiftData(container:").count - 1, 1)
        XCTAssertFalse(dependencies.contains("static var"))

        let durability = try appSource("Core/Configuration/StorageDurabilityState.swift")
        XCTAssertFalse(durability.contains("import SwiftData"))
        XCTAssertFalse(durability.contains("import CloudKit"))
    }

    // MARK: - Helpers

    private func v2Schema() -> Schema {
        Schema(versionedSchema: HabitHonkerSchemaV2.self)
    }

    private func appSource(_ path: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HabitHonker")
        return try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }
}

private enum StorageTestFailure: Error {
    case persistentStoreUnavailable
}

private enum ScopingFixture {
    static func habit(_ title: String) -> HabitModel {
        HabitModel(icon: "atom", iconColor: .red, title: title, priority: .importantAndUrgent,
                   type: .repeating, repeating: [.monday], dueDate: Date(timeIntervalSince1970: 1_735_689_600),
                   notificationActivated: false)
    }
}

/// Representative pre-4F user data with stable identities.
private enum ContinuityFixture {
    static let gym = uuid(1)
    static let taxes = uuid(2)
    static let archived = uuid(3)
    static let added = uuid(4)
    static let preset = uuid(5)
    static let gymRecordIDs: Set<UUID> = [uuid(11), uuid(12), uuid(13)]
    static let archivedRecordIDs: Set<UUID> = [uuid(15), uuid(16)]
    /// 2 habits + 1 archived habit + 6 records + 1 statistics preset.
    static let seededRowCount = 10

    static func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "4F4F4F4F-0000-0000-0000-%012d", value))!
    }

    /// Hours after 2025-01-01T00:00Z: always in the past, never "today".
    static func date(_ hours: Int) -> Date {
        Date(timeIntervalSince1970: 1_735_689_600 + Double(hours) * 3_600)
    }

    static func insertPreFourFUserData(into context: ModelContext) {
        let gymHabit = HabitSD(id: gym, icon: "biceps-flexed", iconColorHex: "#FF8800FF",
                               title: "Gym", descriptionText: "Legs and back", tags: ["health", "strength"],
                               priorityRaw: PriorityEisenhower.importantButNotUrgent.rawValue,
                               typeRaw: HabitType.repeating.rawValue, repeatingWeekdays: [2, 4, 6],
                               dueDate: date(0), notificationActivated: true,
                               records: [HabitRecordSD(id: uuid(11), date: date(1), count: 1),
                                         HabitRecordSD(id: uuid(12), date: date(25), count: 3),
                                         HabitRecordSD(id: uuid(13), date: date(49), count: 2)])
        let taxesHabit = HabitSD(id: taxes, icon: nil, iconColorHex: "#3366CCFF",
                                 title: "File taxes", descriptionText: "", tags: [],
                                 priorityRaw: PriorityEisenhower.importantAndUrgent.rawValue,
                                 typeRaw: HabitType.dueDate.rawValue, repeatingWeekdays: [],
                                 dueDate: date(72), notificationActivated: false,
                                 records: [HabitRecordSD(id: uuid(14), date: date(70), count: 1)])
        let archivedHabit = DeletedHabitSD(id: archived, icon: "bed", iconColorHex: "#AABBCCFF",
                                           title: "Old habit", descriptionText: "Archived before 4F", tags: ["rest"],
                                           priorityRaw: PriorityEisenhower.notUrgentAndNotImportant.rawValue,
                                           typeRaw: HabitType.repeating.rawValue, repeatingWeekdays: [1, 7],
                                           dueDate: date(5), notificationActivated: true, deletedAt: date(80),
                                           records: [HabitRecordSD(id: uuid(15), date: date(2), count: 4),
                                                     HabitRecordSD(id: uuid(16), date: date(26), count: 1)])
        context.insert(gymHabit)
        context.insert(taxesHabit)
        context.insert(archivedHabit)
        context.insert(StatisticsPresetSD(id: preset, name: "Morning", isActive: true,
                                          habitIDs: [gym, taxes, archived]))
    }

    static func habitAddedAfterFourF() -> HabitModel {
        HabitModel(id: added, icon: "atom", iconColor: .blue, title: "Added after 4F",
                   priority: .notUrgentAndNotImportant, type: .repeating, repeating: [.tuesday],
                   dueDate: date(90), notificationActivated: false)
    }
}
