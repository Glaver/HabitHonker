import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

@MainActor
final class BehaviorTransactionDITests: XCTestCase {
    func testDependenciesAreScopedToEachContainerAndConstructionDoesNotEnroll() async throws {
        let first = try TxStore.memory(); let second = try TxStore.memory()
        try TxStore.seed(first); try TxStore.seed(second)
        let a = AppDependencies.make(container: first)
        let b = AppDependencies.make(container: second)
        let secondBefore = try TxStore.state(second)
        _ = try await a.behaviorTransactionService.complete(TxCommand.make())
        XCTAssertEqual(try TxStore.state(second), secondBefore)
        _ = try await b.behaviorTransactionService.complete(TxCommand.make())
        for store in [first, second] {
            XCTAssertEqual(try ModelContext(store).fetch(FetchDescriptor<GamificationProfileSD>()).first?.totalXP, 41)
        }
        let empty = try TxStore.memory()
        _ = AppDependencies.make(container: empty)
        try Phase2TestStore.assertNewTablesEmpty(ModelContext(empty))
    }
    func testCurrentHabitServiceViaNewDIStillWritesNoGamificationRows() async throws {
        let store = try TxStore.memory(); try TxStore.seed(store, profile: false)
        let dependencies = AppDependencies.make(container: store)
        let result = try await dependencies.habitService.completeHabit(id: TxCommand.target.rawValue)
        XCTAssertEqual(result?.record.reduce(0) { $0 + $1.count }, 1)
        try Phase2TestStore.assertNewTablesEmpty(ModelContext(store))
    }
    func testOneSaveOwnerNoHiddenClockAndNoLiveConsumer() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("HabitHonker")
        let paths = ["Core/Domain/BehaviorTransactionModels.swift", "Core/Protocols/BehaviorTransactionServiceProtocol.swift",
            "Core/Protocols/BehaviorTransactionRepositoryProtocol.swift", "Core/Services/BehaviorTransactionService.swift",
            "Core/Repositories/SwiftDataBehaviorTransactionRepository.swift", "Repository/SwiftDataRepository/BehaviorTransactionSD.swift"]
        for path in paths {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            for forbidden in ["SwiftUI", "NotificationCenter", "HabitEventCenter", "Date()", "Calendar.current", "TimeZone.current", "Locale.current", "UserDefaults", "StoreKit", ".save()", "ModelContext(", "static var"] {
                XCTAssertFalse(source.contains(forbidden), "\(path): \(forbidden)")
            }
            if path.contains("Core/Protocols") || path.contains("Core/Services") || path.contains("Core/Domain") {
                XCTAssertFalse(source.contains("import SwiftData"), path)
            }
        }
        let helper = try String(contentsOf: root.appendingPathComponent(paths.last!), encoding: .utf8)
        XCTAssertFalse(helper.contains("await "))
        let actor = try String(contentsOf: root.appendingPathComponent("Repository/SwiftDataRepository/HabitsRepositorySwiftData.swift"), encoding: .utf8)
        let window = try XCTUnwrap(actor.components(separatedBy: "private func executeBehavior").last?.components(separatedBy: "// MARK: - CRUD").first)
        XCTAssertEqual(window.components(separatedBy: "context.save()").count - 1, 1)
        XCTAssertEqual(window.components(separatedBy: "makeContext()").count - 1, 1)
        XCTAssertTrue(window.contains("context.rollback()")); XCTAssertFalse(window.contains("await "))
        for path in ["Core/Services/HabitService.swift", "Screens/TaskList/HabitListViewModel.swift", "Screens/TaskList/HabitModel.swift", "Screens/Navigation/RootTabsView.swift"] {
            let source = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
            for forbidden in ["BehaviorTransactionService", "BehaviorTransactionRepository", "GamificationLedgerEntrySD", "TaskOccurrenceSD", "behaviorTransactionService"] {
                XCTAssertFalse(source.contains(forbidden), path)
            }
        }
        let di = try String(contentsOf: root.appendingPathComponent("App/AppDependencies.swift"), encoding: .utf8)
        XCTAssertEqual(di.components(separatedBy: "HabitsRepositorySwiftData(container:").count - 1, 1)
        XCTAssertTrue(di.contains("SwiftDataBehaviorTransactionRepository(repository: swiftDataRepository"))
        XCTAssertTrue(di.contains("SwiftDataHabitRepository(repository: swiftDataRepository"))
    }
}
