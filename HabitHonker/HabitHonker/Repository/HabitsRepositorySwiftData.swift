//
//  HabitsRepositorySwiftData.swift
//  HabitHonker
//
//  Created by Vladyslav on 8/12/25.
//
import Foundation
import SwiftData

actor HabitsRepositorySwiftData {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - Helpers
    private func makeContext() -> ModelContext {
        let ctx = ModelContext(container)
        ctx.autosaveEnabled = false
        return ctx
    }

    // MARK: - CRUD
    func fetchAll() throws -> [ListHabitItem] {
        let ctx = makeContext()
        let descriptor = FetchDescriptor<HabitSD>(sortBy: [.init(\.title)])
        let rows = try ctx.fetch(descriptor)
        return rows.map(HabitMapper.toDomain)
    }

    func fetch(id: UUID) throws -> ListHabitItem? {
        let ctx = makeContext()
        let pred = #Predicate<HabitSD> { $0.id == id }
        var d = FetchDescriptor<HabitSD>(predicate: pred)
        d.fetchLimit = 1
        return try ctx.fetch(d).first.map(HabitMapper.toDomain)
    }

    func save(_ item: ListHabitItem) throws {
        let ctx = makeContext()
        let sd = HabitMapper.makeSD(from: item)
        ctx.insert(sd)
        try ctx.save()
    }

    func update(_ item: ListHabitItem) throws {
        let ctx = makeContext()

        // 👈 capture the value FIRST so RHS is a literal, not a key path
        let targetId = item.id

        let pred = #Predicate<HabitSD> { $0.id == targetId }

        var descriptor = FetchDescriptor<HabitSD>(predicate: pred)
        descriptor.fetchLimit = 1

        if let sd = try ctx.fetch(descriptor).first {
            HabitMapper.apply(item, to: sd)
            try ctx.save()
        }
    }

    func delete(id: UUID) throws {
        let ctx = makeContext()
        let pred = #Predicate<HabitSD> { $0.id == id }
        var d = FetchDescriptor<HabitSD>(predicate: pred)
        d.fetchLimit = 1
        if let sd = try ctx.fetch(d).first {
            ctx.delete(sd)
            try ctx.save()
        }
    }
}

//@MainActor
//final class HabitsRepositorySwiftData {
//    private let context: ModelContext
////    private let container: ModelContainer
//    
//    init(context: ModelContext) { self.context = context }
//    
//    func fetchAll() throws -> [ListHabitItem] {
//        try context.fetch(FetchDescriptor<HabitSD>(sortBy: [.init(\.title)]))
//            .map(HabitMapper.toDomain)
//    }
//    
//    func save(_ item: ListHabitItem) throws {
//        let sd = HabitMapper.makeSD(from: item)
//        context.insert(sd)
//        try context.save()
//    }
//    
//    func update(_ item: ListHabitItem) throws {
//        let targetId = item.id                      // capture VALUE, not key path
//        let pred = #Predicate<HabitSD> { $0.id == targetId }
//        
//        var descriptor = FetchDescriptor<HabitSD>(predicate: pred)
//        descriptor.fetchLimit = 1
//        
//        if let sd = try context.fetch(descriptor).first {
//            HabitMapper.apply(item, to: sd)
//            try context.save()
//        }
//    }
//    
//    func delete(id: UUID) throws {
//        let pred = #Predicate<HabitSD> { $0.id == id }
//        
//        var descriptor = FetchDescriptor<HabitSD>(predicate: pred)
//        descriptor.fetchLimit = 1
//        
//        if let sd = try context.fetch(descriptor).first {
//            context.delete(sd)
//            try context.save()
//        }
//    }
//    
//    func fetch(id: UUID) throws -> ListHabitItem? {
//        let targetId = id
//        let pred = #Predicate<HabitSD> { $0.id == targetId }
//        
//        var descriptor = FetchDescriptor<HabitSD>(predicate: pred)
//        descriptor.fetchLimit = 1
//        
//        guard let sd = try context.fetch(descriptor).first else { return nil }
//        return HabitMapper.toDomain(sd)
//    }
//}
