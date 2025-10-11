//
//  SyncManager.swift
//  HabitHonker
//
//  Created by Vladyslav on 10/9/25.
//

import CloudKit
import SwiftUI

@MainActor
final class SyncManager: ObservableObject {
    @AppStorage("syncOn") var isOn: Bool = false
    @Published var iCloudAvailable: Bool = false
    
    func refreshAccountStatusAndWait() async {
        do {
            let status = try await CKContainer.default().accountStatus()
            await MainActor.run { self.iCloudAvailable = (status == .available) }
        } catch {
            await MainActor.run { self.iCloudAvailable = false }
        }
    }
}
