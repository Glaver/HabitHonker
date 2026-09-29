import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

/// Phase 4B source and schema guards: the planning layer is pure, revision identity is minted only
/// by the injected provider, the one repository actor stages history inside each mutation's single
/// context/save, 4B writes no other gamification row, and Schema V2 is unchanged.
@MainActor
final class BehaviorScheduleRevisionArchitectureTests: XCTestCase {
    static let pureFiles = [
        "Core/Domain/BehaviorScheduleSnapshot.swift",
        "Core/Domain/BehaviorSchedulingPolicy.swift",
        "Core/Domain/ScheduleHistoryOutcome.swift",
        "Core/Domain/BehaviorScheduleRevisionPlan.swift",
        "Core/Protocols/BehaviorScheduleRevisionPlanning.swift",
        "Core/Protocols/BehaviorScheduleRevisionIDProviding.swift",
        "Core/Services/BehaviorScheduleRevisionPlanner.swift",
    ]

    func testPurePlanningLayerIsFoundationOnlyWithoutDeviceStateClockIdentityOrPersistence() throws {
        let forbidden = [
            "import SwiftUI", "import SwiftData", "import CloudKit", "import Combine", "import UIKit", "import CoreData",
            "ModelContext", "ModelContainer", "@Model", "FetchDescriptor", "UserDefaults", ".save(",
            "Date()", "Date.now", "timeIntervalSinceNow", "Calendar.current", "Calendar.autoupdatingCurrent",
            "TimeZone.current", "TimeZone.autoupdatingCurrent", "Locale.current", "Locale.autoupdatingCurrent",
            "NSTimeZone", "NSCalendar", "NSLocale",
            "Hasher", "hashValue", "UUID(", "random",
            "GamificationProfileSD", "BehaviorScheduleRevisionSD", "TaskOccurrenceSD", "BehaviorEventSD",
            "GamificationLedgerEntrySD", "GamificationService", "RewardCalculator", "LevelCalculator", "HabitModel",
        ]
        for path in Self.pureFiles {
            let source = try productionSource(path)
            XCTAssertEqual(imports(source), ["import Foundation"], path)
            for token in forbidden {
                XCTAssertFalse(source.contains(token), "\(path) contains \(token)")
            }
        }
        // The planner never mints identities; the only calendar is the policy's explicit Gregorian one.
        XCTAssertFalse(try productionSource("Core/Services/BehaviorScheduleRevisionPlanner.swift").contains("makeRevisionID"))
        let policy = try productionSource("Core/Domain/BehaviorSchedulingPolicy.swift")
        XCTAssertEqual(policy.components(separatedBy: "Calendar(identifier:").count - 1, 1)
        XCTAssertTrue(policy.contains("Calendar(identifier: .gregorian)"))
        XCTAssertTrue(policy.contains("static let gregorianCalendarIdentifier = \"gregorian\""))
        XCTAssertTrue(policy.contains("fileprivate init("), "only resolution can create a policy")
        for path in Self.pureFiles where path != "Core/Domain/BehaviorSchedulingPolicy.swift" {
            XCTAssertFalse(try productionSource(path).contains("Calendar(identifier"), path)
            XCTAssertFalse(try productionSource(path).contains("TimeZone(identifier"), path)
        }
    }

    func testRevisionIdentityIsMintedOnlyByTheInjectedProvider() throws {
        let provider = try productionSource("Core/Services/BehaviorScheduleRevisionIDProviderV1.swift")
        XCTAssertEqual(imports(provider), ["import Foundation"])
        XCTAssertEqual(provider.components(separatedBy: "UUID()").count - 1, 1, "only the injectable default generator")
        XCTAssertTrue(provider.contains("init(uuid: @escaping @Sendable () -> UUID = { UUID() })"))
        XCTAssertTrue(provider.contains("\"rev:v1:\\(BehaviorLogicalIdentity.canonicalUUIDText(targetID.rawValue)):change:\\(BehaviorLogicalIdentity.canonicalUUIDText(revisionUUID))\""))
        for token in ["hashValue", "Hasher", "persistentModelID", "BehaviorScheduleRevisionSD", "Date()", "SwiftData"] {
            XCTAssertFalse(provider.contains(token), token)
        }
        // Row construction never supplies the physical id, so it cannot double as the logical one.
        let mapper = try productionSource("Repository/SwiftDataRepository/BehaviorScheduleRevisionMapper.swift")
        XCTAssertEqual(mapper.components(separatedBy: "BehaviorScheduleRevisionSD(").count - 1, 1)
        for token in ["UUID(", "persistentModelID", "hashValue", "Hasher", ".save(", "Date()", "GamificationProfileSD(",
                      "TaskOccurrenceSD", "BehaviorEventSD", "GamificationLedgerEntrySD"] {
            XCTAssertFalse(mapper.contains(token), "mapper: \(token)")
        }
        // The 4C baseline identity is untouched and not minted by 4B production code.
        XCTAssertTrue(try productionSource("Core/Domain/BehaviorLogicalIdentity.swift")
            .contains("\"rev:v1:\\(canonicalUUIDText(targetID.rawValue)):baseline\""))
        for path in ["Repository/SwiftDataRepository/HabitsRepositorySwiftData+ScheduleHistory.swift",
                     "Repository/SwiftDataRepository/HabitsRepositorySwiftData.swift",
                     "Repository/SwiftDataRepository/BehaviorScheduleRevisionMapper.swift"] {
            XCTAssertFalse(try productionSource(path).contains("baselineRevisionID"), "4B must not create baselines: \(path)")
        }
    }

    func testScheduleHistoryStagingReadsTheProfileAndWritesOnlyRevisionRows() throws {
        let staging = try productionSource("Repository/SwiftDataRepository/HabitsRepositorySwiftData+ScheduleHistory.swift")
        for token in [".save(", "makeContext(", "ModelContext(", "await ", "Date()", "Calendar.current", "TimeZone.current",
                      "GamificationProfileSD(", "TaskOccurrenceSD", "BehaviorEventSD", "GamificationLedgerEntrySD",
                      "GamificationService", "RewardCalculator", "LevelCalculator", "BehaviorTransaction",
                      ".first", ".last", "totalXP", "honkerCoins", "lifetimeCoins", "trackingStartedAt =",
                      "ctx.delete(", "HabitRecordSD", "records"] {
            XCTAssertFalse(staging.contains(token), "staging contains \(token)")
        }
        XCTAssertEqual(staging.components(separatedBy: "scheduleRevisionIDs.makeRevisionID(").count - 1, 1,
                       "IDs are minted only where a revision row is inserted")
        XCTAssertEqual(staging.components(separatedBy: "ctx.insert(").count - 1, 1)
        XCTAssertTrue(staging.contains("extension HabitsRepositorySwiftData"), "no second repository actor")
        XCTAssertFalse(staging.contains("actor "), "no second repository actor")
    }

    func testEveryHabitMutationStagesHistoryInItsOwnSingleContextAndSave() throws {
        let actor = try productionSource("Repository/SwiftDataRepository/HabitsRepositorySwiftData.swift")
        let windows: [(String, String)] = [
            ("func createHabit(", "/// Replaces the editable fields"),
            ("func updateMetadata(", "/// Changes only the priority"),
            ("func updatePriority(", "/// Legacy same-day completion"),
            ("func delete(id: UUID, effectiveAt: Date)", "// MARK: - Deleted Habits"),
            ("func restoreDeletedHabit(id: UUID, effectiveAt: Date)", "// MARK: - Statistics Preset"),
        ]
        for (start, end) in windows {
            let window = try XCTUnwrap(actor.components(separatedBy: start).last?.components(separatedBy: end).first, start)
            XCTAssertEqual(window.components(separatedBy: "makeContext()").count - 1, 1, "\(start): one context")
            XCTAssertEqual(window.components(separatedBy: "stageScheduleHistory(").count - 1, 1, "\(start): history staged once")
            XCTAssertEqual(window.components(separatedBy: "try commit(ctx)").count - 1, 1, "\(start): one save")
            XCTAssertFalse(window.contains(".save()"), "\(start): no second save")
            XCTAssertFalse(window.contains("await "), "\(start): no suspension between reading history and saving")
            XCTAssertFalse(window.contains("Date()"), "\(start): effectiveAt comes from the caller")
        }
        let commit = try XCTUnwrap(actor.components(separatedBy: "private func commit(").last?
            .components(separatedBy: "private func activeHabitCount").first)
        XCTAssertEqual(commit.components(separatedBy: "ctx.save()").count - 1, 1)
        XCTAssertTrue(commit.contains("#if DEBUG"), "the before-save seam is absent from release builds")

        // Legacy completion keeps its own 4A path with no schedule-history effect.
        let completion = try XCTUnwrap(actor.components(separatedBy: "func recordLegacyCompletion(").last?
            .components(separatedBy: "/// The single save of every").first)
        for token in ["stageScheduleHistory", "effectiveAt", "commit(", "BehaviorSchedule"] {
            XCTAssertFalse(completion.contains(token), "legacy completion: \(token)")
        }
        XCTAssertTrue(actor.contains("scheduleRevisionIDs: any BehaviorScheduleRevisionIDProviding = BehaviorScheduleRevisionIDProviderV1()"))
    }

    func testApplicationBoundaryCapturesEffectiveAtAndDependenciesInjectPlannerAndProvider() throws {
        let service = try productionSource("Core/Services/HabitService.swift")
        XCTAssertEqual(service.components(separatedBy: "effectiveAt: now()").count - 1, 5,
                       "create, update, priority, delete and restore each read the injected clock once")
        XCTAssertEqual(service.components(separatedBy: "Date()").count - 1, 1, "only the default clock")
        let completion = try XCTUnwrap(service.components(separatedBy: "func completeHabit(").last?
            .components(separatedBy: "func changePriority(").first)
        XCTAssertFalse(completion.contains("effectiveAt"))
        for token in ["BehaviorTransactionService", "GamificationService", "BehaviorScheduleRevisionPlanner", "stageScheduleHistory"] {
            XCTAssertFalse(service.contains(token), "service: \(token)")
        }

        let dependencies = try productionSource("App/AppDependencies.swift")
        XCTAssertTrue(dependencies.contains("scheduleRevisionPlanner: BehaviorScheduleRevisionPlanner()"))
        XCTAssertTrue(dependencies.contains("scheduleRevisionIDs: BehaviorScheduleRevisionIDProviderV1()"))
        XCTAssertEqual(dependencies.components(separatedBy: "HabitsRepositorySwiftData(container:").count - 1, 1)

        // The UI keeps its HabitModel-returning service API; no view model sees history outcomes.
        let serviceProtocol = try productionSource("Core/Protocols/HabitServiceProtocol.swift")
        XCTAssertFalse(serviceProtocol.contains("ScheduleHistoryOutcome"))
        XCTAssertFalse(serviceProtocol.contains("effectiveAt"))
        for path in ["Screens/TaskList/HabitListViewModel.swift", "Screens/PriorityMatrix/PriorityMatrixViewModel.swift",
                     "Screens/TaskList/HabitListView.swift", "Screens/Navigation/RootTabsView.swift"] {
            let source = try productionSource(path)
            for token in ["ScheduleHistoryOutcome", "BehaviorSchedule", "effectiveAt"] {
                XCTAssertFalse(source.contains(token), "\(path): \(token)")
            }
        }
    }

    func testFrozenLayersAreNotTouched() throws {
        // Phase 4C identity formats.
        let identity = try productionSource("Core/Domain/OccurrenceIdentityV1.swift")
        XCTAssertTrue(identity.contains("\"occ:v1:\\(BehaviorLogicalIdentity.canonicalUUIDText(targetID.rawValue)):day:\\(localDay.canonicalKey)\""))
        XCTAssertTrue(identity.contains("\"occ:v1:\\(BehaviorLogicalIdentity.canonicalUUIDText(targetID.rawValue)):once\""))
        XCTAssertEqual(BehaviorLogicalIdentity.defaultProfileKey, "profile:v1:default")
        // Phase 4F storage and Phase 3 transaction code know nothing about schedule history.
        for path in ["App/PersistentStoreFactory.swift", "Core/Configuration/StorageDurabilityState.swift",
                     "Core/Services/BehaviorTransactionService.swift",
                     "Core/Repositories/SwiftDataBehaviorTransactionRepository.swift",
                     "Repository/SwiftDataRepository/BehaviorTransactionSD.swift"] {
            let source = try productionSource(path)
            for token in ["BehaviorSchedule", "ScheduleHistory", "stageScheduleHistory"] {
                XCTAssertFalse(source.contains(token), "\(path): \(token)")
            }
        }
    }

    func testSchemaV2AndTheMigrationPlanAreUnchanged() throws {
        let v2 = Schema(versionedSchema: HabitHonkerSchemaV2.self)
        XCTAssertEqual(v2.version, Schema.Version(2, 0, 0))
        XCTAssertEqual(Set(v2.entities.map(\.name)), ["HabitSD", "HabitRecordSD", "DeletedHabitSD", "StatisticsPresetSD",
                                                      "TaskOccurrenceSD", "BehaviorScheduleRevisionSD", "BehaviorEventSD",
                                                      "GamificationProfileSD", "GamificationLedgerEntrySD"])
        XCTAssertEqual(HabitHonkerMigrationPlan.schemas.count, 2)
        XCTAssertEqual(HabitHonkerMigrationPlan.stages.count, 1)
        let expected: [String: Set<String>] = [
            "BehaviorScheduleRevisionSD": ["id", "logicalRevisionID", "targetID", "effectiveFrom", "effectiveTo",
                                           "taskTypeRawValue", "selectedWeekdaysMask", "scheduledHour", "scheduledMinute",
                                           "dueAt", "schedulingTimeZoneIdentifier", "schedulingCalendarIdentifier",
                                           "priorityRawValue", "iconName", "notificationEnabled", "schemaVersion"],
            "GamificationProfileSD": ["id", "logicalProfileKey", "totalXP", "honkerCoins", "lifetimeCoinsEarned",
                                      "lifetimeCoinsSpent", "trackingStartedAt", "schedulingTimeZoneIdentifier",
                                      "schedulingCalendarIdentifier", "lastProcessedWeekKey", "aggregateFingerprint",
                                      "schemaVersion", "updatedAt"],
            "HabitSD": ["id", "icon", "iconColorHex", "title", "descriptionText", "tags", "priorityRaw", "typeRaw",
                        "repeatingWeekdays", "dueDate", "notificationActivated", "records"],
        ]
        for (name, properties) in expected {
            XCTAssertEqual(Set(try XCTUnwrap(v2.entitiesByName[name]).properties.map(\.name)), properties, name)
        }
        // No model outside the two versioned schemas: every @Model lives in the frozen model files.
        let root = productionRoot()
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        let modelFiles: Set<String> = ["HabitItemSD.swift", "DeletedHabitSD.swift", "StatisticsPresetSD.swift",
                                       "BehaviorSD.swift", "GamificationSD.swift"]
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            if source.contains("@Model") {
                XCTAssertTrue(modelFiles.contains(url.lastPathComponent), "unexpected @Model in \(url.lastPathComponent)")
            }
            XCTAssertFalse(source.contains("HabitHonkerSchemaV3"), url.lastPathComponent)
        }
    }

    // MARK: - Helpers

    private func productionRoot() -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("HabitHonker")
    }

    private func productionSource(_ path: String) throws -> String {
        try String(contentsOf: productionRoot().appendingPathComponent(path), encoding: .utf8)
    }

    private func imports(_ source: String) -> [String] {
        source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("import ") }
    }
}
