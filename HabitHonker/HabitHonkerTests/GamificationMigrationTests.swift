import Foundation
import SwiftData
import XCTest
@testable import HabitHonker

@MainActor
final class GamificationMigrationTests: XCTestCase {
    func testSchemaVersionsModelSetsAndLightweightStage() throws {
        let legacy = Set(["HabitSD", "HabitRecordSD", "DeletedHabitSD", "StatisticsPresetSD"])
        let added = Set(["TaskOccurrenceSD", "BehaviorScheduleRevisionSD", "BehaviorEventSD",
                         "GamificationProfileSD", "GamificationLedgerEntrySD"])
        let v1 = Schema(versionedSchema: HabitHonkerSchemaV1.self)
        let v2 = Schema(versionedSchema: HabitHonkerSchemaV2.self)
        XCTAssertEqual(Set(v1.entities.map(\.name)), legacy)
        XCTAssertEqual(Set(v2.entities.map(\.name)), legacy.union(added))
        XCTAssertEqual(v1.version, Schema.Version(1, 0, 0))
        XCTAssertEqual(v2.version, Schema.Version(2, 0, 0))
        XCTAssertEqual(HabitHonkerMigrationPlan.schemas.map { $0.versionIdentifier }, [v1.version, v2.version])
        XCTAssertEqual(HabitHonkerMigrationPlan.stages.count, 1)
        guard case let .lightweight(from, to) = try XCTUnwrap(HabitHonkerMigrationPlan.stages.first) else {
            return XCTFail("Adding entities must not require a data-transforming migration")
        }
        XCTAssertEqual(from.versionIdentifier, v1.version)
        XCTAssertEqual(to.versionIdentifier, v2.version)
        // Explicit legacy attribute inventory prevents accidental additions to the deployed schema.
        let expected: [String: Set<String>] = [
            "HabitSD": ["id", "icon", "iconColorHex", "title", "descriptionText", "tags", "priorityRaw", "typeRaw", "repeatingWeekdays", "dueDate", "notificationActivated", "records"],
            "HabitRecordSD": ["id", "date", "count", "habit", "deletedHabit"],
            "DeletedHabitSD": ["id", "icon", "iconColorHex", "title", "descriptionText", "tags", "priorityRaw", "typeRaw", "repeatingWeekdays", "dueDate", "notificationActivated", "deletedAt", "records"],
            "StatisticsPresetSD": ["id", "name", "isActive", "habitIDs"]
        ]
        for entity in v1.entities {
            XCTAssertEqual(Set(entity.properties.map(\.name)), expected[entity.name])
        }
        XCTAssertEqual(v1.entitiesByName["HabitSD"]?.relationshipsByName["records"]?.deleteRule, .cascade)
        XCTAssertEqual(v1.entitiesByName["DeletedHabitSD"]?.relationshipsByName["records"]?.deleteRule, .nullify)
        for name in ["habit", "deletedHabit"] {
            XCTAssertEqual(v1.entitiesByName["HabitRecordSD"]?.relationshipsByName[name]?.deleteRule, .nullify)
        }
    }

    func testDeployedUnversionedStoreMigratesOnDiskWithoutBackfill() throws {
        try verifyMigration(legacySchema: Schema([HabitSD.self, HabitRecordSD.self, DeletedHabitSD.self, StatisticsPresetSD.self]))
    }

    func testExplicitV1StoreMigratesOnDiskWithoutBackfill() throws {
        try verifyMigration(legacySchema: Schema(versionedSchema: HabitHonkerSchemaV1.self))
    }

    func testV2CloudCompatibleMetadataAndLocalEquivalentConfiguration() throws {
        let schema = Schema(versionedSchema: HabitHonkerSchemaV2.self)
        let newNames = Set(["TaskOccurrenceSD", "BehaviorScheduleRevisionSD", "BehaviorEventSD", "GamificationProfileSD", "GamificationLedgerEntrySD"])
        for entity in schema.entities {
            XCTAssertTrue(entity.uniquenessConstraints.isEmpty, entity.name)
            for attribute in entity.attributes {
                XCTAssertFalse(attribute.isUnique, "\(entity.name).\(attribute.name)")
                XCTAssertTrue(attribute.isOptional || attribute.defaultValue != nil,
                              "CloudKit requires a default/optional: \(entity.name).\(attribute.name)")
            }
            if newNames.contains(entity.name) { XCTAssertTrue(entity.relationships.isEmpty, entity.name) }
        }
        let cloudShape = ModelConfiguration("Cloud", schema: nil, isStoredInMemoryOnly: false,
            allowsSave: true, groupContainer: .automatic,
            cloudKitDatabase: .private("iCloud.com.flyingwhale.habithonker"))
        let legacyDefault = ModelConfiguration(schema: Schema(versionedSchema: HabitHonkerSchemaV1.self))
        let currentDefault = ModelConfiguration(schema: schema)
        XCTAssertEqual(legacyDefault.url, currentDefault.url, "Versioning must not relocate the default store")
        let legacyCloud = ModelConfiguration("Cloud", schema: nil, isStoredInMemoryOnly: false,
            allowsSave: true, groupContainer: .automatic,
            cloudKitDatabase: .private("iCloud.com.flyingwhale.habithonker"))
        XCTAssertEqual(cloudShape.url, legacyCloud.url)
        print("Phase2 default store URL: \(currentDefault.url); Cloud store URL: \(cloudShape.url)")
        // Exercise the production model set and migration plan without cloud/account/network effects.
        let dir = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try autoreleasepool {
            let config = ModelConfiguration("Cloud", schema: nil, url: dir.appendingPathComponent("Cloud.store"),
                                            allowsSave: true, cloudKitDatabase: .none)
            let container = try ModelContainer(for: schema, migrationPlan: HabitHonkerMigrationPlan.self, configurations: config)
            try Phase2TestStore.assertNewTablesEmpty(ModelContext(container))
        }
    }

    private func verifyMigration(legacySchema: Schema) throws {
        let dir = try Phase2TestStore.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("legacy.store")
        // Scope all managed objects and contexts to release the old store before reopening it.
        let expected = try autoreleasepool {
            let config = ModelConfiguration(schema: legacySchema, url: url, cloudKitDatabase: .none)
            let container = try ModelContainer(for: legacySchema, configurations: config)
            let context = ModelContext(container)
            context.autosaveEnabled = false
            let repeatHabit = HabitSD(id: Phase2TestStore.id(1), icon: "biceps-flexed", iconColorHex: "#123456",
                title: "Repeating", descriptionText: "Legacy repeat", tags: ["a", "b"], priorityRaw: 2, typeRaw: HabitType.repeating.rawValue,
                repeatingWeekdays: [2, 4, 6], dueDate: Phase2TestStore.date(1), notificationActivated: true,
                records: [HabitRecordSD(id: Phase2TestStore.id(11), date: Phase2TestStore.date(2), count: 3),
                          HabitRecordSD(id: Phase2TestStore.id(12), date: Phase2TestStore.date(3), count: 2)])
            let once = HabitSD(id: Phase2TestStore.id(2), icon: nil, iconColorHex: nil,
                title: "One time", descriptionText: "Legacy due", tags: [], priorityRaw: 0, typeRaw: HabitType.dueDate.rawValue,
                repeatingWeekdays: [], dueDate: Phase2TestStore.date(4), notificationActivated: false,
                records: [HabitRecordSD(id: Phase2TestStore.id(13), date: Phase2TestStore.date(5), count: 1)])
            let archive = DeletedHabitSD(id: Phase2TestStore.id(3), icon: "bed", iconColorHex: "#ABCDEF",
                title: "Archived", descriptionText: "Legacy archive", tags: ["rest"], priorityRaw: 3, typeRaw: HabitType.repeating.rawValue,
                repeatingWeekdays: [1, 7], dueDate: Phase2TestStore.date(6), notificationActivated: true,
                deletedAt: Phase2TestStore.date(7), records: [HabitRecordSD(id: Phase2TestStore.id(14), date: Phase2TestStore.date(8), count: 4)])
            context.insert(repeatHabit); context.insert(once); context.insert(archive)
            context.insert(StatisticsPresetSD(id: Phase2TestStore.id(4), name: "My statistics", isActive: true,
                                             habitIDs: [repeatHabit.id, once.id, archive.id]))
            try context.save()
            return try Phase2TestStore.legacySnapshot(context)
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        for _ in 0..<2 {
            try autoreleasepool {
                let container = try Phase2TestStore.container(url: url)
                let context = ModelContext(container)
                XCTAssertEqual(try Phase2TestStore.legacySnapshot(context), expected)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitSD>()), 2)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<HabitRecordSD>()), 4)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<DeletedHabitSD>()), 1)
                XCTAssertEqual(try context.fetchCount(FetchDescriptor<StatisticsPresetSD>()), 1)
                try Phase2TestStore.assertNewTablesEmpty(context)
            }
        }
    }
}

@MainActor
enum Phase2TestStore {
    static func id(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }
    static func date(_ value: Int) -> Date { Date(timeIntervalSince1970: 1_800_000_000 + Double(value)) }
    static func directory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Phase2-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
    static func container(url: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: HabitHonkerSchemaV2.self)
        let config = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try ModelContainer(for: schema, migrationPlan: HabitHonkerMigrationPlan.self, configurations: config)
    }
    static func assertNewTablesEmpty(_ context: ModelContext, file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskOccurrenceSD>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BehaviorScheduleRevisionSD>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<BehaviorEventSD>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GamificationProfileSD>()), 0, file: file, line: line)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<GamificationLedgerEntrySD>()), 0, file: file, line: line)
    }
    static func legacySnapshot(_ context: ModelContext) throws -> [String: [String: AnyHashable?]] {
        var result: [String: [String: AnyHashable?]] = [:]
        for row in try context.fetch(FetchDescriptor<HabitSD>()) {
            result["habit:\(row.id)"] = ["id": row.id, "icon": row.icon, "iconColorHex": row.iconColorHex,
                "title": row.title, "descriptionText": row.descriptionText, "tags": row.tags,
                "priorityRaw": row.priorityRaw, "typeRaw": row.typeRaw, "repeatingWeekdays": row.repeatingWeekdays,
                "dueDate": row.dueDate, "notificationActivated": row.notificationActivated,
                "records": row.records?.map { $0.id.uuidString }.sorted()]
        }
        for row in try context.fetch(FetchDescriptor<DeletedHabitSD>()) {
            result["archive:\(row.id)"] = ["id": row.id, "icon": row.icon, "iconColorHex": row.iconColorHex,
                "title": row.title, "descriptionText": row.descriptionText, "tags": row.tags,
                "priorityRaw": row.priorityRaw, "typeRaw": row.typeRaw, "repeatingWeekdays": row.repeatingWeekdays,
                "dueDate": row.dueDate, "notificationActivated": row.notificationActivated, "deletedAt": row.deletedAt,
                "records": row.records?.map { $0.id.uuidString }.sorted()]
        }
        for row in try context.fetch(FetchDescriptor<HabitRecordSD>()) {
            result["record:\(row.id)"] = ["id": row.id, "date": row.date, "count": row.count,
                                        "habit": row.habit?.id, "deletedHabit": row.deletedHabit?.id]
        }
        for row in try context.fetch(FetchDescriptor<StatisticsPresetSD>()) {
            result["preset:\(row.id)"] = ["id": row.id, "name": row.name, "isActive": row.isActive, "habitIDs": row.habitIDs]
        }
        return result
    }
}
