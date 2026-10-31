import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

/// Phase 4E source and schema guards (§82–§87):
/// - the enrollment contract is pure;
/// - staging reuses the 4B normalization and the 4C baseline key, and writes only profile and
///   revision rows;
/// - enrollment is one context and one save on the one actor;
/// - DI builds the service without calling it, and no live code enrolls;
/// - Schema V2 and the migration plan are unchanged.
@MainActor
final class GamificationEnrollmentArchitectureTests: XCTestCase {
    static let pureFiles = [
        "Core/Domain/GamificationEnrollmentRequest.swift",
        "Core/Domain/GamificationEnrollmentResult.swift",
        "Core/Domain/GamificationEnrollmentError.swift",
        "Core/Protocols/GamificationEnrollmentServicing.swift",
        "Core/Protocols/GamificationEnrollmentRepositoryProtocol.swift",
        "Core/Services/GamificationEnrollmentService.swift",
    ]
    static let stagingFile = "Repository/SwiftDataRepository/HabitsRepositorySwiftData+Enrollment.swift"
    static let actorFile = "Repository/SwiftDataRepository/HabitsRepositorySwiftData.swift"
    static let adapterFile = "Core/Repositories/SwiftDataGamificationEnrollmentRepository.swift"

    func testEnrollmentContractIsPureFoundationWithoutClockDeviceStateOrRewards() throws {
        let forbidden = [
            "import SwiftUI", "import SwiftData", "import CloudKit", "import Combine", "import UIKit", "import CoreData",
            "ModelContext", "ModelContainer", "@Model", "FetchDescriptor", "UserDefaults", ".save(",
            "Date()", "Date.now", "timeIntervalSinceNow", "Calendar.current", "Calendar.autoupdatingCurrent",
            "TimeZone.current", "TimeZone.autoupdatingCurrent", "Locale.current", "NSTimeZone", "NSCalendar",
            "Calendar(identifier", "TimeZone(identifier",
            "Hasher", "hashValue", "UUID(", "random", "static var", "shared",
            "GamificationProfileSD", "BehaviorScheduleRevisionSD", "TaskOccurrenceSD", "BehaviorEventSD",
            "GamificationLedgerEntrySD", "GamificationService", "RewardCalculator", "LevelCalculator",
            "BehaviorTransaction", "ModelConfiguration", "cloudKitDatabase",
        ]
        for path in Self.pureFiles {
            let source = try productionSource(path)
            XCTAssertEqual(imports(source), ["import Foundation"], path)
            for token in forbidden {
                XCTAssertFalse(source.contains(token), "\(path) contains \(token)")
            }
        }
        // Validation reuses the 4B resolution: no second calendar vocabulary, no fallback zone.
        let request = try productionSource("Core/Domain/GamificationEnrollmentRequest.swift")
        XCTAssertTrue(request.contains("BehaviorScheduleEnrollment.resolve("))
        XCTAssertTrue(request.contains("BehaviorSchedulingPolicy.gregorianCalendarIdentifier"))
        XCTAssertFalse(request.contains("\"gregorian\""))
        XCTAssertFalse(request.contains("\"UTC\"") || request.contains("\"GMT\""))
        // The service gates on the injected durability before persistence.
        let service = try productionSource("Core/Services/GamificationEnrollmentService.swift")
        XCTAssertTrue(service.contains("storageDurability.supportsDurableGamification"))
        XCTAssertLessThan(try XCTUnwrap(service.range(of: "supportsDurableGamification")).lowerBound,
                          try XCTUnwrap(service.range(of: "repository.enroll(")).lowerBound)
        // The error vocabulary has no catch-all case.
        let error = try productionSource("Core/Domain/GamificationEnrollmentError.swift")
        for token in ["case unknown", "somethingWentWrong", "case other"] {
            XCTAssertFalse(error.contains(token), token)
        }
    }

    func testStagingReusesPhase4BAnd4CAndWritesOnlyProfileAndRevisionRows() throws {
        let staging = try productionSource(Self.stagingFile)
        for token in [".save(", "makeContext(", "ModelContext(", "await ", "Date()", "Date.now", "Calendar.current",
                      "TimeZone.current", "Calendar(identifier", "TimeZone(identifier", "UUID(", "Hasher", "hashValue",
                      "ctx.delete(", ".rollback(", "HabitRecordSD", "records", "DeletedHabitSD",
                      "StatisticsPresetSD", "TaskOccurrenceSD(", "BehaviorEventSD(", "GamificationLedgerEntrySD(",
                      "GamificationService", "RewardCalculator", "LevelCalculator", "BehaviorTransaction",
                      "makeRevisionID", "scheduleRevisionPlanner", "applyMetadata", "priorityRaw = ", "title = ",
                      "totalXP = ", "honkerCoins = ", "lifetimeCoinsEarned = ", "lifetimeCoinsSpent = ",
                      "lastProcessedWeekKey = ", "aggregateFingerprint = "] {
            XCTAssertFalse(staging.contains(token), "staging contains \(token)")
        }
        // Never `fetch.first` / `.last` over physical rows, and no second actor declaration.
        XCTAssertFalse(matches(staging, #"\.(first|last)\b"#), "staging picks a row by position")
        XCTAssertFalse(matches(staging, #"(?m)^\s*(private |final )?actor\s"#), "no second actor")
        XCTAssertTrue(staging.contains("extension HabitsRepositorySwiftData"), "the same actor, no second one")
        // Exactly two inserts: the profile and each baseline.
        XCTAssertEqual(staging.components(separatedBy: "ctx.insert(").count - 1, 2)
        XCTAssertEqual(staging.components(separatedBy: "GamificationProfileSD(").count - 1, 1)
        // Baselines use the 4B mapper and normalization, and the frozen 4C key; no row is built by hand.
        XCTAssertFalse(staging.contains("BehaviorScheduleRevisionSD("))
        XCTAssertTrue(staging.contains("BehaviorScheduleRevisionMapper.makeOpenRow("))
        XCTAssertTrue(staging.contains("BehaviorScheduleRevisionMapper.source(from: habit)"))
        XCTAssertTrue(staging.contains("BehaviorScheduleSnapshot.normalized("))
        XCTAssertTrue(staging.contains("BehaviorLogicalIdentity.baselineRevisionID(targetID:"))
        XCTAssertTrue(staging.contains("BehaviorScheduleEnrollment.resolve("))
        XCTAssertFalse(staging.contains("\"rev:v1"), "no second baseline key format")
        XCTAssertFalse(staging.contains("\"profile:v1"), "no second profile key literal")
        // Every baseline starts at the one policy instant.
        XCTAssertTrue(staging.contains("effectiveFrom: policy.trackingStartedAt"))
        XCTAssertFalse(staging.contains("effectiveFrom: request.enrolledAt"))
        XCTAssertFalse(staging.contains("@Attribute(.unique)"))
    }

    func testEnrollmentIsOneActorOperationWithOneContextAndOneSave() throws {
        let actor = try productionSource(Self.actorFile)
        let window = try XCTUnwrap(actor.components(separatedBy: "func enrollGamification(").last)
        XCTAssertEqual(actor.components(separatedBy: "func enrollGamification(").count - 1, 1)
        XCTAssertEqual(window.components(separatedBy: "makeContext()").count - 1, 1, "one context")
        XCTAssertEqual(window.components(separatedBy: "stageGamificationEnrollment(").count - 1, 1)
        XCTAssertEqual(window.components(separatedBy: "try commit(ctx)").count - 1, 1, "one save, through the seam")
        for token in [".save()", "await ", "Date()", "TimeZone.current", "Calendar.current", "Task {", "Task.detached"] {
            XCTAssertFalse(window.contains(token), "enrollGamification contains \(token)")
        }
        // The Phase 2 guard still holds: the main actor file names no gamification model.
        for token in ["GamificationProfileSD", "BehaviorScheduleRevisionSD", "GamificationLedgerEntrySD"] {
            XCTAssertFalse(actor.contains(token), token)
        }
        // The adapter shares the existing actor; it builds no container and no actor.
        let adapter = try productionSource(Self.adapterFile)
        XCTAssertTrue(adapter.contains("private let repository: HabitsRepositorySwiftData"))
        XCTAssertTrue(adapter.contains("repository.enrollGamification(request)"))
        XCTAssertTrue(adapter.contains("struct SwiftDataGamificationEnrollmentRepository: GamificationEnrollmentRepositoryProtocol"))
        for token in ["ModelContainer", "HabitsRepositorySwiftData(", "ModelContext("] {
            XCTAssertFalse(adapter.contains(token), "adapter: \(token)")
        }
        XCTAssertFalse(matches(adapter, #"(?m)^\s*(private |final )?actor\s"#), "no second actor")
    }

    func testDependenciesBuildTheServiceOnTheSharedActorAndNothingEnrollsAutomatically() throws {
        let dependencies = try productionSource("App/AppDependencies.swift")
        XCTAssertTrue(dependencies.contains("let gamificationEnrollmentService: any GamificationEnrollmentServicing"))
        XCTAssertTrue(dependencies.contains("SwiftDataGamificationEnrollmentRepository(repository: swiftDataRepository)"))
        XCTAssertTrue(dependencies.contains("storageDurability: storageDurability)"))
        XCTAssertEqual(dependencies.components(separatedBy: "HabitsRepositorySwiftData(container:").count - 1, 1)
        XCTAssertFalse(dependencies.contains(".enroll("), "construction never enrolls")
        XCTAssertFalse(dependencies.contains("static var"))

        // Only the service calls the repository's enroll, only the adapter calls the actor, and only
        // the actor stages. No view, view model, app entry point or Habit service enrolls.
        let root = productionRoot()
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        var callers: [String: Set<String>] = [:]
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            for token in [".enroll(", "enrollGamification(", "stageGamificationEnrollment(", "gamificationEnrollmentService"]
            where source.contains(token) {
                callers[token, default: []].insert(url.lastPathComponent)
            }
        }
        XCTAssertEqual(callers[".enroll("], ["GamificationEnrollmentService.swift"])
        XCTAssertEqual(callers["enrollGamification("], ["SwiftDataGamificationEnrollmentRepository.swift",
                                                         "HabitsRepositorySwiftData.swift"])
        XCTAssertEqual(callers["stageGamificationEnrollment("], ["HabitsRepositorySwiftData.swift",
                                                                 "HabitsRepositorySwiftData+Enrollment.swift"])
        XCTAssertEqual(callers["gamificationEnrollmentService"], ["AppDependencies.swift"])
        for path in ["App/HabitHonkerApp.swift", "App/PersistentStoreFactory.swift", "App/AppCoordinator.swift",
                     "Screens/Navigation/RootTabsView.swift", "Screens/TaskList/HabitListViewModel.swift",
                     "Screens/SettingsScreen/SettingsViewModel.swift", "Core/Services/HabitService.swift",
                     "Core/Protocols/HabitServiceProtocol.swift"] {
            XCTAssertFalse(try productionSource(path).contains("Enrollment"), "\(path) must not reach enrollment")
        }
        // Live completion is still the legacy path.
        let habitService = try productionSource("Core/Services/HabitService.swift")
        let completion = try XCTUnwrap(habitService.components(separatedBy: "func completeHabit(").last?
            .components(separatedBy: "func changePriority(").first)
        XCTAssertTrue(completion.contains("repository.recordLegacyCompletion("))
        for token in ["BehaviorTransaction", "Gamification", "effectiveAt"] {
            XCTAssertFalse(completion.contains(token), "completeHabit: \(token)")
        }
    }

    func testFrozenIdentityStorageAndTransactionLayersAreUntouched() throws {
        XCTAssertEqual(BehaviorLogicalIdentity.defaultProfileKey, "profile:v1:default")
        XCTAssertTrue(try productionSource("Core/Domain/BehaviorLogicalIdentity.swift")
            .contains("\"rev:v1:\\(canonicalUUIDText(targetID.rawValue)):baseline\""))
        for path in ["App/PersistentStoreFactory.swift", "Core/Configuration/StorageDurabilityState.swift",
                     "Core/Services/BehaviorTransactionService.swift",
                     "Core/Repositories/SwiftDataBehaviorTransactionRepository.swift",
                     "Repository/SwiftDataRepository/BehaviorTransactionSD.swift",
                     "Repository/SwiftDataRepository/HabitsRepositorySwiftData+ScheduleHistory.swift",
                     "Core/Services/BehaviorScheduleRevisionPlanner.swift",
                     "Repository/SwiftDataRepository/BehaviorScheduleRevisionMapper.swift"] {
            let source = try productionSource(path)
            XCTAssertFalse(source.contains("GamificationEnrollment"), path)
            XCTAssertFalse(source.contains("baselineRevisionID"), "only enrollment mints baselines: \(path)")
        }
    }

    func testSchemaV2AndTheMigrationPlanAreUnchangedAndNoModelWasAdded() throws {
        let v2 = Schema(versionedSchema: HabitHonkerSchemaV2.self)
        XCTAssertEqual(v2.version, Schema.Version(2, 0, 0))
        XCTAssertEqual(Set(v2.entities.map(\.name)), ["HabitSD", "HabitRecordSD", "DeletedHabitSD", "StatisticsPresetSD",
                                                      "TaskOccurrenceSD", "BehaviorScheduleRevisionSD", "BehaviorEventSD",
                                                      "GamificationProfileSD", "GamificationLedgerEntrySD"])
        XCTAssertEqual(HabitHonkerMigrationPlan.schemas.count, 2)
        XCTAssertEqual(HabitHonkerMigrationPlan.stages.count, 1)
        XCTAssertEqual(Set(try XCTUnwrap(v2.entitiesByName["GamificationProfileSD"]).properties.map(\.name)),
                       ["id", "logicalProfileKey", "totalXP", "honkerCoins", "lifetimeCoinsEarned", "lifetimeCoinsSpent",
                        "trackingStartedAt", "schedulingTimeZoneIdentifier", "schedulingCalendarIdentifier",
                        "lastProcessedWeekKey", "aggregateFingerprint", "schemaVersion", "updatedAt"])
        let modelFiles: Set<String> = ["HabitItemSD.swift", "DeletedHabitSD.swift", "StatisticsPresetSD.swift",
                                       "BehaviorSD.swift", "GamificationSD.swift"]
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: productionRoot(), includingPropertiesForKeys: nil))
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

    private func matches(_ source: String, _ pattern: String) -> Bool {
        source.range(of: pattern, options: .regularExpression) != nil
    }

    private func imports(_ source: String) -> [String] {
        source.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("import ") }
    }
}
