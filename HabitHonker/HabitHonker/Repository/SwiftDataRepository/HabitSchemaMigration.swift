import SwiftData

/// The deployed, formerly unversioned model set. Keep these model definitions frozen
/// across V1/V2; a future field change needs a separate historical model definition.
enum HabitHonkerSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [HabitSD.self, HabitRecordSD.self, DeletedHabitSD.self, StatisticsPresetSD.self]
    }
}

enum HabitHonkerSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        HabitHonkerSchemaV1.models + [TaskOccurrenceSD.self, BehaviorScheduleRevisionSD.self,
            BehaviorEventSD.self, GamificationProfileSD.self, GamificationLedgerEntrySD.self]
    }
}

enum HabitHonkerMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [HabitHonkerSchemaV1.self, HabitHonkerSchemaV2.self] }
    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: HabitHonkerSchemaV1.self, toVersion: HabitHonkerSchemaV2.self)]
    }
}
