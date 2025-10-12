
//  SettingsView.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/19/25.
//

import SwiftUI
import PhotosUI
import AuthenticationServices

@MainActor
struct SettingsView: View {
    @AppStorage("appearance") private var appearanceRaw: String = HonkerColorSchema.auto.rawValue
    @State private var path = NavigationPath()
    @EnvironmentObject private var sync: SyncManager
    @State private var showiCloudHint = false
    
    @EnvironmentObject private var viewModel: HabitListViewModel
    
    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section("Sync") {
                        ZStack {
                            Toggle("iCloud sync", isOn: Binding(
                                get: { sync.isOn },
                                set: { newVal in
                                    if newVal && !sync.iCloudAvailable {
                                        showiCloudHint = true
                                    } else {
                                        sync.isOn = newVal
                                    }
                                }
                            ))
                            HStack {
                                Spacer()
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20)
                                        .frame(width: 42, height: 42)
                                        .foregroundStyle(Color("cellContentColor"))
                                        .shadow(color: .gray.opacity(0.3), radius: 6, x: 1, y: 1)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                    Image(systemName: sync.isOn ? "checkmark.icloud" : "icloud.slash")
                                        .foregroundColor(sync.isOn ? .green.opacity(0.7) : .red.opacity(0.7))
                                }
                                .padding(.trailing, 75)
                            }
                    }
                }
                
                Section("Color schema") {
                    VStack {
                        let options: [HonkerColorSchema] = [.auto, .light, .dark]
                        Picker("", selection: $appearanceRaw) {
                            ForEach(options) { opt in
                                Text(opt.title).tag(opt.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, 15)
                    }
                    NavigationLink(value: Route.priorityMatrixEditor) {
                        HStack {
                            Text("Change colors")
                            Spacer()
//                            Image(systemName: "chevron.right")
//                                .scaledToFill()
//                                .frame(width: 6, height: 22)
//                                .tint(Color.gray.opacity(0.5))
                        }
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                    // MARK: - Choose background
                    
                    PhotosPicker(
                        selection: $viewModel.backgroundPickerItem,
                        matching: .images
                    ) {
                        HStack(spacing: 12) {
                            Text("Choose background")
                                .tint(.primary)
                            Spacer()
                            if viewModel.hasCustomBackground {
                                ZStack {
                                    Image(systemName: "trash")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .foregroundStyle(.primary)
                                        .frame(width: 24, height: 24)
                                        .zIndex(2)
                                    
                                    RoundedRectangle(cornerRadius: 20)
                                        .frame(width: 42, height: 42)
                                        .foregroundStyle(Color("cellContentColor"))
                                        .shadow(color: .gray.opacity(0.3), radius: 6, x: 1, y: 1)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 20)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                        .onTapGesture {
                                            Task { @MainActor in
                                                viewModel.clearBackground()
                                            }
                                        }
                                }
                            }
                            Image(systemName: "chevron.right")
                                .frame(width: 6, height: 22)
                                .tint(Color.gray.opacity(0.5))
                                .padding(.trailing, 5)
                        }
                        .padding(.vertical, 5)
                        .contentShape(Rectangle())
                    }
                }
//                .listRowSeparator(.hidden)
                
                
//                Section("Support and Feedback") {
//                    VStack {
//                        VStack(alignment: .center) {
//                            PrimaryButton(title: "Share With Frined", color: Color(.systemGray4), foregroundStyle: .black) {
//                                print("Share app")
//                            }
//                            PrimaryButton(title: "Rate App support and Feedback", color: Color(.systemGray4), foregroundStyle: .black) {
//                                print("Rate App")
//                            }
//                            PrimaryButton(title: "Send fast feedback", color: .blue, foregroundStyle: .white) {
//                                print("Send fast feedback")
//                            }
//                        }
//                    }
//                }
            }
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
            .alert("Sign in to iCloud", isPresented: $showiCloudHint) {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            Button("OK", role: .cancel) { }
                        } message: {
                            Text("To enable sync, sign in to iCloud on this device.")
                        }
            .task {
                // Fires every time backgroundPickerItem changes (regardless of identifier)
                for await _ in viewModel.$backgroundPickerItem.values {
                    await viewModel.processPickedBackgroundIfNeeded()
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("Version \(Bundle.main.appVersion) (\(Bundle.main.buildNumber))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(.clear)   // subtle, matches the screenshot vibe
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .priorityMatrixEditor:
                    PriorityMatrixEditorView()
                default:
                    EmptyView()
                }
            }
        }
    }
}
