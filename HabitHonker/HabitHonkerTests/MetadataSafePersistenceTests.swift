import Combine
import SwiftData
import SwiftUI
import XCTest
@testable import HabitHonker

/// Phase 4A: metadata writes never own completion history, never resurrect deleted
/// habits, and legacy completion is one repository operation.
/// Every test runs through the production service/repository/actor on a real in-memory V2 store.
@MainActor
final class MetadataSafePersistenceTests: XCTestCase {

    // MARK: A1 — stale Details draft

    func testStaleDraftSaveKeepsCompletionMadeAfterDraftWasLoaded() async throws {
        let store = try TxStore.memory()
        let service = makeService(store)
        let created = try await service.createHabit(sampleHabit(title: "Gym"))
        let loaded = try await service.fetchHabit(id: created.id)
        var draft = try XCTUnwrap(loaded)
        XCTAssertTrue(draft.record.isEmpty)

        _ = try await service.completeHabit(id: created.id)
        draft.title = "Gym (evening)"
        let saved = try await service.updateHabit(draft)

        XCTAssertEqual(saved.title, "Gym (evening)")
        XCTAssertEqual(totalCount(saved), 1, "Returned model must carry the authoritative records")
        let reloadedValue = try await service.fetchHabit(id: created.id)
        let reloaded = try XCTUnwrap(reloadedValue)
        XCTAssertEqual(reloaded.title, "Gym (evening)")
        XCTAssertEqual(totalCount(reloaded), 1)
    }

    func testListViewModelStaleDetailsSaveKeepsCompletion() async throws {
        let store = try TxStore.memory()
        let service = makeService(store)
        let viewModel = makeViewModel(service)
        let habit = sampleHabit(title: "Read")
        await viewModel.createItem(habit)
        let draftValue = viewModel.items.first { $0.id == habit.id }
        var draft = try XCTUnwrap(draftValue)

        await viewModel.habitCompleteWith(id: habit.id)
        draft.title = "Read 20 pages"
        await viewModel.saveItem(draft)

        XCTAssertNil(viewModel.error)
        let storedValue = try await service.fetchHabit(id: habit.id)
        let stored = try XCTUnwrap(storedValue)
        XCTAssertEqual(stored.title, "Read 20 pages")
        XCTAssertEqual(totalCount(stored), 1)
        let inMemory = viewModel.items.first { $0.id == habit.id }
        XCTAssertEqual(inMemory?.title, "Read 20 pages")
        XCTAssertEqual(inMemory.map(totalCount), 1, "List must hold the fresh persisted habit, not the stale draft")
    }

    // MARK: A2 — priority after completion

    func testPriorityChangeAfterCompletionPreservesCompletion() async throws {
        let store = try TxStore.memory()
        let service = makeService(store)
        let created = try await service.createHabit(sampleHabit(title: "Stretch"))
        _ = try await service.completeHabit(id: created.id)
        _ = try await service.completeHabit(id: created.id)

        let changedValue = try await service.changePriority(id: created.id, to: .notUrgentAndNotImportant)
        let changed = try XCTUnwrap(changedValue)

        XCTAssertEqual(changed.priority, .notUrgentAndNotImportant)
        XCTAssertEqual(totalCount(changed), 2)
        let reloadedValue = try await service.fetchHabit(id: created.id)
        XCTAssertEqual(reloadedValue.map(totalCount), 2)
        XCTAssertEqual(try recordRowCount(store), 1)
    }

    // MARK: A3/A4 — repeated metadata edits keep record identity and row count

    func testRepeatedMetadataEditsKeepRecordIDsDatesCountsAndRowCount() async throws {
        let store = try TxStore.memory()
        let service = makeService(store)
        let id = UUID()
        try seedHabit(store, id: id, records: [
            (UUID(), day(0, hour: 8), 1),
            (UUID(), day(1, hour: 19), 3),
            (UUID(), day(3, hour: 7), 2),
        ])
        let before = try recordFacts(store, habitID: id)
        XCTAssertEqual(try recordRowCount(store), 3)

        let loaded = try await service.fetchHabit(id: id)
        var draft = try XCTUnwrap(loaded)
        // The draft's record array is deliberately wrong: metadata writes must ignore it.
        draft.record = [HabitModel.HabitRecord(date: day(9, hour: 9), count: 42)]

        draft.title = "Renamed"
        _ = try await service.updateHabit(draft)
        draft.icon = "alarm"
        _ = try await service.updateHabit(draft)
        draft.iconColor = .green
        _ = try await service.updateHabit(draft)
        draft.isNotificationActivated.toggle()
        _ = try await service.updateHabit(draft)
        draft.repeating = [.tuesday, .thursday]
        draft.dueDate = day(5, hour: 18)
        _ = try await service.updateHabit(draft)
        draft.type = .dueDate
        _ = try await service.updateHabit(draft)
        draft.description = "More detail"
        draft.tags = ["health"]
        _ = try await service.updateHabit(draft)
        _ = try await service.changePriority(id: id, to: .importantButNotUrgent)
        _ = try await service.changePriority(id: id, to: .urgentButNotImportant)

        XCTAssertEqual(try recordFacts(store, habitID: id), before)
        XCTAssertEqual(try recordRowCount(store), 3, "Metadata writes must not add record rows")
        XCTAssertEqual(try orphanRecordRowCount(store), 0)
        let finalValue = try await service.fetchHabit(id: id)
        let finalHabit = try XCTUnwrap(finalValue)
        XCTAssertEqual(finalHabit.title, "Renamed")
        XCTAssertEqual(finalHabit.icon, "alarm")
        XCTAssertEqual(finalHabit.type, .dueDate)
        XCTAssertEqual(finalHabit.repeating, [.tuesday, .thursday])
        XCTAssertEqual(finalHabit.dueDate, day(5, hour: 18))
        XCTAssertEqual(finalHabit.description, "More detail")
        XCTAssertEqual(finalHabit.tags, ["health"])
        XCTAssertEqual(finalHabit.priority, .urgentButNotImportant)
    }

    // MARK: A6 — no resurrection

    func testUpdateAfterDeleteThrowsNotFoundAndDoesNotResurrect() async throws {
        let store = try TxStore.memory()
        let service = makeService(store)
        let created = try await service.createHabit(sampleHabit(title: "Original"))
        _ = try await service.completeHabit(id: created.id)
        var staleDraft = created
        staleDraft.title = "Stale edit"
        try await service.deleteHabit(id: created.id)

        do {
            _ = try await service.updateHabit(staleDraft)
            XCTFail("A stale update after delete must fail")
        } catch let error as HabitRepositoryError {
            XCTAssertEqual(error, .notFound(created.id))
        }
        let priorityResult = try await service.changePriority(id: created.id, to: .notUrgentAndNotImportant)
        XCTAssertNil(priorityResult)
        let completionResult = try await service.completeHabit(id: created.id)
        XCTAssertNil(completionResult)

        let active = try await service.fetchHabit(id: created.id)
        XCTAssertNil(active)
        XCTAssertEqual(try ModelContext(store).fetchCount(FetchDescriptor<HabitSD>()), 0)
        let archivedValue = try await service.fetchDeletedHabit(id: created.id)
        let archived = try XCTUnwrap(archivedValue)
        XCTAssertEqual(archived.title, "Original")
        XCTAssertEqual(totalCount(archived), 1)
    }

    // MARK: A7 — explicit create conflict

    func testCreateWithExistingIDThrowsAlreadyExistsAndDoesNotOverwrite() async throws {
        let store = try TxStore.memory()
        let service = makeService(store)
        let original = try await service.createHabit(sampleHabit(title: "Original"))
        _ = try await service.completeHabit(id: original.id)
        var impostor = sampleHabit(title: "Impostor")
        impostor.id = original.id

        do {
            _ = try await service.createHabit(impostor)
            XCTFail("Creating an existing ID must fail")
        } catch let error as HabitRepositoryError {
            XCTAssertEqual(error, .alreadyExists(original.id))
        }
        let storedValue = try await service.fetchHabit(id: original.id)
        let stored = try XCTUnwrap(storedValue)
        XCTAssertEqual(stored.title, "Original")
        XCTAssertEqual(totalCount(stored), 1)
        XCTAssertEqual(try ModelContext(store).fetchCount(FetchDescriptor<HabitSD>()), 1)
    }

    func testCreateIgnoresDraftRecordsAndStartsWithoutHistory() async throws {
        let store = try TxStore.memory()
        let service = makeService(store)
        var habit = sampleHabit(title: "Fresh")
        habit.record = [HabitModel.HabitRecord(date: day(0, hour: 9), count: 5)]

        let created = try await service.createHabit(habit)

        XCTAssertTrue(created.record.isEmpty)
        XCTAssertEqual(try recordRowCount(store), 0)
    }

    // MARK: A8/A9/A10 — legacy completion

    func testLegacyCompletionSameDayIncrementsAndKeepsRecordIDAndDate() async throws {
        let store = try TxStore.memory()
        let clock = TestClock(day(0, hour: 9))
        let service = makeService(store, clock: clock)
        let created = try await service.createHabit(sampleHabit(title: "Water"))

        let firstValue = try await service.completeHabit(id: created.id)
        let first = try XCTUnwrap(firstValue?.record.first)
        clock.now = day(0, hour: 21)
        let secondValue = try await service.completeHabit(id: created.id)
        let second = try XCTUnwrap(secondValue)

        XCTAssertEqual(second.record.count, 1)
        XCTAssertEqual(second.record.first?.id, first.id)
        XCTAssertEqual(second.record.first?.date, day(0, hour: 9), "Original timestamp is preserved")
        XCTAssertEqual(second.record.first?.count, 2)
        XCTAssertEqual(try recordRowCount(store), 1)
    }

    func testLegacyCompletionNextLocalDayInsertsNewRecord() async throws {
        let store = try TxStore.memory()
        let clock = TestClock(day(0, hour: 23, minute: 30))
        let service = makeService(store, clock: clock)
        let created = try await service.createHabit(sampleHabit(title: "Journal"))

        _ = try await service.completeHabit(id: created.id)
        clock.now = day(1, hour: 0, minute: 15)
        let resultValue = try await service.completeHabit(id: created.id)
        let result = try XCTUnwrap(resultValue)

        XCTAssertEqual(result.record.count, 2)
        XCTAssertEqual(result.record.map(\.count).sorted(), [1, 1])
        XCTAssertEqual(try recordRowCount(store), 2)
    }

    func testSuppliedCalendarTimeZoneDecidesLegacyDayGrouping() async throws {
        let store = try TxStore.memory()
        let repository = SwiftDataHabitRepository(container: store)
        let utcHabit = try await repository.createHabit(id: UUID(), metadata: HabitMetadata(sampleHabit(title: "UTC")))
        let laHabit = try await repository.createHabit(id: UUID(), metadata: HabitMetadata(sampleHabit(title: "LA")))
        // 2027-01-15 07:30Z and 09:30Z: the same UTC day, but different Los Angeles days
        // (Jan 14 23:30 and Jan 15 01:30 PST).
        let early = Date(timeIntervalSince1970: 1_799_998_200)
        let late = early.addingTimeInterval(2 * 3_600)
        let utc = gregorianCalendar("UTC")
        let losAngeles = gregorianCalendar("America/Los_Angeles")

        _ = try await repository.recordLegacyCompletion(id: utcHabit.id, at: early, calendar: utc)
        let utcResult = try await repository.recordLegacyCompletion(id: utcHabit.id, at: late, calendar: utc)
        _ = try await repository.recordLegacyCompletion(id: laHabit.id, at: early, calendar: losAngeles)
        let laResult = try await repository.recordLegacyCompletion(id: laHabit.id, at: late, calendar: losAngeles)

        XCTAssertEqual(utcResult.record.map(\.count), [2])
        XCTAssertEqual(laResult.record.map(\.count).sorted(), [1, 1])
    }

    func testLegacyCompletionOnMissingHabitThrowsNotFoundAndInsertsNothing() async throws {
        let store = try TxStore.memory()
        let repository = SwiftDataHabitRepository(container: store)
        let missing = UUID()

        do {
            _ = try await repository.recordLegacyCompletion(id: missing, at: day(0, hour: 9), calendar: gregorianCalendar("UTC"))
            XCTFail("Completion of a missing habit must fail")
        } catch let error as HabitRepositoryError {
            XCTAssertEqual(error, .notFound(missing))
        }
        XCTAssertEqual(try ModelContext(store).fetchCount(FetchDescriptor<HabitSD>()), 0)
        XCTAssertEqual(try recordRowCount(store), 0)
    }

    func testLegacyCompletionWithSeveralSameDayRecordsIncrementsOnlyTheEarliest() async throws {
        let store = try TxStore.memory()
        let clock = TestClock(day(2, hour: 20))
        let service = makeService(store, clock: clock)
        let id = UUID()
        let earlier = UUID()
        let later = UUID()
        try seedHabit(store, id: id, records: [(later, day(2, hour: 18), 1), (earlier, day(2, hour: 7), 4)])

        _ = try await service.completeHabit(id: id)

        let facts = try recordFacts(store, habitID: id)
        XCTAssertEqual(facts.first { $0.id == earlier }?.count, 5)
        XCTAssertEqual(facts.first { $0.id == later }?.count, 1, "The other same-day record is not merged or changed")
        XCTAssertEqual(try recordRowCount(store), 2)
    }

    // MARK: A11 — concurrency through the real service/repository boundary

    func testConcurrentPriorityAndMetadataEditsNeverLoseCommittedCompletions() async throws {
        let store = try TxStore.memory()
        let repository = SwiftDataHabitRepository(container: store)
        let clock = TestClock(day(0, hour: 12))
        // Two independent services (as used by the list and the priority matrix) share one repository actor.
        let listService = HabitService(repository: repository, habitEvents: SilentEvents(),
                                       now: { clock.now }, calendar: { gregorianCalendar("America/Los_Angeles") })
        let matrixService = HabitService(repository: repository, habitEvents: SilentEvents(),
                                         now: { clock.now }, calendar: { gregorianCalendar("America/Los_Angeles") })
        let created = try await listService.createHabit(sampleHabit(title: "Concurrent"))
        var staleDraft = created
        let priorities: [PriorityEisenhower] = [.importantAndUrgent, .urgentButNotImportant,
                                                .importantButNotUrgent, .notUrgentAndNotImportant]
        var tasks: [Task<Void, Error>] = []
        for index in 0..<20 {
            tasks.append(Task { _ = try await listService.completeHabit(id: created.id) })
            tasks.append(Task { _ = try await matrixService.changePriority(id: created.id, to: priorities[index % 4]) })
            if index % 2 == 0 {
                staleDraft.title = "Edit \(index)"
                let draft = staleDraft
                tasks.append(Task { _ = try await listService.updateHabit(draft) })
            }
        }
        for task in tasks { try await task.value }

        let storedValue = try await listService.fetchHabit(id: created.id)
        let stored = try XCTUnwrap(storedValue)
        XCTAssertEqual(totalCount(stored), 20, "Every committed completion must survive concurrent metadata writes")
        XCTAssertEqual(try recordRowCount(store), 1)
        XCTAssertEqual(try orphanRecordRowCount(store), 0)
    }

    // MARK: Source guard — metadata paths cannot write completion records

    func testMetadataWritePathsDoNotTouchRecordsAndBroadUpsertIsGone() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("HabitHonker")
        let mapper = try String(contentsOf: root.appendingPathComponent("Repository/SwiftDataRepository/HabitMapper.swift"), encoding: .utf8)
        let applyMetadata = try XCTUnwrap(mapper.components(separatedBy: "static func applyMetadata").last?
            .components(separatedBy: "// MARK: Domain -> DeletedHabitSD").first)
        XCTAssertFalse(applyMetadata.contains("records"))
        XCTAssertFalse(mapper.contains("static func apply("), "Whole-model apply (record rebuild) must not exist")

        let actor = try String(contentsOf: root.appendingPathComponent("Repository/SwiftDataRepository/HabitsRepositorySwiftData.swift"), encoding: .utf8)
        for (start, end) in [("func createHabit(", "/// Replaces the editable fields"),
                             ("func updateMetadata(", "/// Changes only the priority"),
                             ("func updatePriority(", "/// Legacy same-day completion")] {
            let window = try XCTUnwrap(actor.components(separatedBy: start).last?.components(separatedBy: end).first)
            XCTAssertFalse(window.contains("records"), "\(start) must not touch records")
        }

        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil))
        for case let url as URL in enumerator where url.pathExtension == "swift" {
            let source = try String(contentsOf: url, encoding: .utf8)
            XCTAssertFalse(source.contains(".upsert("), url.lastPathComponent)
            XCTAssertFalse(source.contains("func upsert("), url.lastPathComponent)
            XCTAssertFalse(source.contains("HabitMapper.apply("), url.lastPathComponent)
        }
    }

    // MARK: - Helpers

    private struct RecordFact: Equatable {
        let id: UUID
        let date: Date
        let count: Int
    }

    private func makeService(_ store: ModelContainer, clock: TestClock? = nil) -> HabitService {
        let clock = clock ?? TestClock(day(0, hour: 12))
        return HabitService(repository: SwiftDataHabitRepository(container: store), habitEvents: SilentEvents(),
                            now: { clock.now }, calendar: { gregorianCalendar("America/Los_Angeles") })
    }

    private func makeViewModel(_ service: HabitService) -> HabitListViewModel {
        HabitListViewModel(habitService: service, habitEvents: SilentEvents(),
                           priorityThemeService: StaticTheme(), backgroundService: NoBackground(),
                           notifier: RecordingNotifier())
    }

    private func sampleHabit(title: String) -> HabitModel {
        HabitModel(icon: "atom", iconColor: .red, title: title, priority: .importantAndUrgent,
                   type: .repeating, repeating: [.monday, .wednesday], dueDate: day(0, hour: 18),
                   notificationActivated: false)
    }

    /// Wall-clock instant on day `offset` after 2027-01-11 (a Monday) in Los Angeles.
    private func day(_ offset: Int, hour: Int, minute: Int = 0) -> Date {
        let calendar = gregorianCalendar("America/Los_Angeles")
        let components = DateComponents(year: 2027, month: 1, day: 11 + offset, hour: hour, minute: minute)
        return calendar.date(from: components)!
    }

    private func totalCount(_ habit: HabitModel) -> Int {
        habit.record.reduce(0) { $0 + $1.count }
    }

    private func seedHabit(_ store: ModelContainer, id: UUID, records: [(UUID, Date, Int)]) throws {
        let context = ModelContext(store)
        let habit = HabitSD(id: id, icon: "atom", title: "Seeded", priorityRaw: PriorityEisenhower.importantAndUrgent.rawValue,
                            typeRaw: HabitType.repeating.rawValue, repeatingWeekdays: [2, 4], dueDate: day(0, hour: 18),
                            notificationActivated: false, records: [])
        context.insert(habit)
        var rows: [HabitRecordSD] = []
        for (recordID, date, count) in records {
            let row = HabitRecordSD(id: recordID, date: date, count: count, habit: habit)
            context.insert(row)
            rows.append(row)
        }
        habit.records = rows
        try context.save()
    }

    private func recordFacts(_ store: ModelContainer, habitID: UUID) throws -> [RecordFact] {
        let context = ModelContext(store)
        var descriptor = FetchDescriptor<HabitSD>(predicate: #Predicate<HabitSD> { $0.id == habitID })
        descriptor.fetchLimit = 1
        let habit = try XCTUnwrap(try context.fetch(descriptor).first)
        return (habit.records ?? [])
            .map { RecordFact(id: $0.id, date: $0.date, count: $0.count) }
            .sorted { $0.id.uuidString < $1.id.uuidString }
    }

    /// Every HabitRecordSD row in the store, including rows with no inverse habit/archive.
    private func recordRowCount(_ store: ModelContainer) throws -> Int {
        try ModelContext(store).fetchCount(FetchDescriptor<HabitRecordSD>())
    }

    private func orphanRecordRowCount(_ store: ModelContainer) throws -> Int {
        try ModelContext(store).fetch(FetchDescriptor<HabitRecordSD>())
            .filter { $0.habit == nil && $0.deletedHabit == nil }
            .count
    }
}

/// Mutable test clock read by the injected `now` closure.
private final class TestClock {
    var now: Date
    init(_ now: Date) { self.now = now }
}

private func gregorianCalendar(_ identifier: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: identifier)!
    return calendar
}

/// Suppresses list reloads so assertions observe each mutation's own memory update.
private final class SilentEvents: HabitEventsPublishing {
    var events: AnyPublisher<HabitEvent, Never> { Empty(completeImmediately: false).eraseToAnyPublisher() }
    func send(_ event: HabitEvent) {}
}

private final class RecordingNotifier: HabitNotificationScheduling {
    private(set) var rescheduled: [UUID] = []
    private(set) var cancelled: [UUID] = []
    func requestAuthorization() async throws {}
    func reschedule(for habit: HabitModel) async throws { rescheduled.append(habit.id) }
    func cancel(for habitID: UUID) async { cancelled.append(habitID) }
    func cancelAll() async {}
}

private struct StaticTheme: PriorityThemeServiceProtocol {
    func loadColors() async -> [Color] { [.red, .yellow, .green, .blue] }
    func loadTitles() async -> [String] { ["", "", "", ""] }
    func setColor(_ color: Color, at index: Int) async {}
    func setTitle(_ title: String, for priority: PriorityEisenhower) async {}
    func setColors(_ colors: [Color]) async {}
    func setTitles(_ titles: [String]) async {}
    func resetToDefaults() async {}
}

private struct NoBackground: BackgroundServiceProtocol {
    func loadBackgroundData() async -> Data? { nil }
    func saveBackgroundData(_ data: Data) async {}
    func optimizedBackgroundData(from data: Data, maxDimension: CGFloat) async -> Data { data }
    func clearBackground() async {}
}
