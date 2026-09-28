//
//  PersistentStoreFactory.swift
//  HabitHonker
//

import Foundation
import SwiftData
import os

/// Builds the app's SwiftData container and classifies how durable it is.
///
/// This is the only code that knows which `ModelConfiguration` was actually opened, so it is the
/// only code that decides `StorageDurabilityState`. `HabitHonkerApp` (the composition root) passes
/// the result into `AppDependencies`; repositories and services never guess it.
enum PersistentStoreFactory {
    /// The storage world the user asked for: iCloud sync on and available means `.cloud`.
    enum Request: Equatable, Sendable {
        case cloud
        case local
    }

    /// A container together with the durability of the store it actually opened.
    struct OpenedStore {
        let container: ModelContainer
        let durability: StorageDurabilityState
    }

    typealias ContainerBuilder = (Schema, ModelConfiguration) throws -> ModelContainer

    static let cloudKitContainerIdentifier = "iCloud.com.flyingwhale.habithonker"
    static let cloudConfigurationName = "Cloud"
    static let fallbackConfigurationName = "FallbackInMemory"

    // MARK: - Configurations

    /// Cloud world, unchanged by Phase 4F: the named "Cloud" store (`Cloud.store`) mirrored to the
    /// private database of the app's CloudKit container.
    static func cloudConfiguration() -> ModelConfiguration {
        ModelConfiguration(cloudConfigurationName,
                           schema: nil,
                           isStoredInMemoryOnly: false,
                           allowsSave: true,
                           groupContainer: .automatic,
                           cloudKitDatabase: .private(cloudKitContainerIdentifier))
    }

    /// Local world: the SAME store the "sync off" path opened before Phase 4F (same configuration
    /// name, same file), now with CloudKit explicitly disabled. LOCAL MEANS NO CLOUDKIT.
    ///
    /// Before 4F, the local path called `ModelContainer(for:migrationPlan:)` without a configuration,
    /// i.e. SwiftData's default configuration, whose CloudKit setting followed the app's iCloud
    /// entitlement, so it was never guaranteed to be local. Name and location are taken from that
    /// same default configuration, so existing on-device data is reopened, never a new empty store.
    /// `storeURL` exists only so tests can use a scratch file with the same name.
    static func localConfiguration(schema: Schema, storeURL: URL? = nil) -> ModelConfiguration {
        let preFourFDefault = preFourFLocalConfiguration(schema: schema)
        return ModelConfiguration(preFourFDefault.name,
                                  schema: schema,
                                  url: storeURL ?? preFourFDefault.url,
                                  allowsSave: true,
                                  cloudKitDatabase: .none)
    }

    /// SwiftData's default configuration: what the pre-4F sync-off path opened. Used only for its
    /// store name and location; never opened as is.
    static func preFourFLocalConfiguration(schema: Schema) -> ModelConfiguration {
        ModelConfiguration(schema: schema)
    }

    /// Ephemeral world: in memory only, and never mirrored to CloudKit.
    static func fallbackConfiguration(schema: Schema) -> ModelConfiguration {
        ModelConfiguration(fallbackConfigurationName,
                           schema: schema,
                           isStoredInMemoryOnly: true,
                           allowsSave: true,
                           cloudKitDatabase: .none)
    }

    // MARK: - Opening

    /// Opens the requested persistent world. If that fails, falls back to an in-memory store so
    /// the app still starts (the pre-4F fallback policy), now classified as `.ephemeralFallback`
    /// instead of masquerading as durable storage. Returns nil only if even that fails.
    static func openStore(for request: Request,
                          schema: Schema,
                          localStoreURL: URL? = nil,
                          logger: Logger = Log.storage,
                          build: ContainerBuilder = PersistentStoreFactory.buildVersionedContainer(schema:configuration:)) -> OpenedStore? {
        let configuration: ModelConfiguration
        let durability: StorageDurabilityState
        switch request {
        case .cloud:
            configuration = cloudConfiguration()
            durability = .durableCloud
        case .local:
            configuration = localConfiguration(schema: schema, storeURL: localStoreURL)
            durability = .durableLocal
        }

        do {
            let container = try build(schema, configuration)
            logger.info("🗄️ Opened \(durability.rawValue, privacy: .public) store")
            return OpenedStore(container: container, durability: durability)
        } catch {
            let failure = error as NSError
            logger.error("❌ Could not open \(durability.rawValue, privacy: .public) store: \(failure.domain, privacy: .public) \(failure.code, privacy: .public) \(failure.localizedDescription, privacy: .private)")
        }

        do {
            let container = try build(schema, fallbackConfiguration(schema: schema))
            logger.fault("⚠️ Using the EPHEMERAL in-memory fallback store. Changes are lost when the app quits.")
            return OpenedStore(container: container, durability: .ephemeralFallback)
        } catch {
            let failure = error as NSError
            logger.fault("❌ The in-memory fallback store failed too: \(failure.domain, privacy: .public) \(failure.code, privacy: .public) \(failure.localizedDescription, privacy: .private)")
            return nil
        }
    }

    /// The production container: versioned V2 schema with the existing migration plan.
    static func buildVersionedContainer(schema: Schema, configuration: ModelConfiguration) throws -> ModelContainer {
        try ModelContainer(for: schema, migrationPlan: HabitHonkerMigrationPlan.self, configurations: configuration)
    }
}
