
//  SettingsView.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/19/25.
//

import SwiftUI
import PhotosUI

struct SettingsView: View {
    @AppStorage("appearance") private var appearanceRaw: String = HonkerColorSchema.auto.rawValue
    @State private var path = NavigationPath()
    @State private var isLoggedIn: Bool = false
    @State private var isSynchronized: Bool = false

    @EnvironmentObject private var viewModel: HabitListViewModel
    
    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
//                    SignInWithAppleView()
                    Toggle(isOn: $isLoggedIn) {
                        Text("Sign in")
                    }
                    Toggle(isOn: $isSynchronized) {
                        Text("iCloud sync")
                    }
                }
                Section {
                    VStack {
                        Text("Color schema")
                        let options: [HonkerColorSchema] = [.auto, .light, .dark]
                                Picker("", selection: $appearanceRaw) {
                                    ForEach(options) { opt in
                                        Text(opt.title).tag(opt.rawValue)
                                    }
                                }
                                .pickerStyle(.segmented)
//                        Divider()
                            .padding(.top, 15)
                    }
                    VStack {
                        HStack {
                            Text("Change colors")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .scaledToFill()
                                .frame(width: 6, height: 22)
                                .tint(Color.gray.opacity(0.5))
                        }
                        .onTapGesture {
                            path.append(Route.priorityMatrixEditor)
                        }
                        
                    }
                    
                    
                    // ... your color schema + "Change colors" UI ...
                    
                    HStack {
                        PhotosPicker(
                            selection: $viewModel.backgroundPickerItem,
                            matching: .images
                        ) {
                            HStack(spacing: 8) {
                                Image(systemName: "photo.on.rectangle")
                                Text("Choose Background")
                                    .font(.headline)
                            }
//                            .padding(.horizontal, 160)
//                            .padding(.vertical, 120)
                            .clipShape(Capsule())
                            .glassEffect(.regular, in: Capsule())
                            .background(.ultraThinMaterial, in: Capsule())
                        }
                        .tint(.primary)
                        
                        if viewModel.hasCustomBackground {
                            Button {
                                viewModel.clearBackground()
                            } label: {
                                Label("Remove Background", systemImage: "trash")
                            }
                            .frame(width: 100, height: 60)
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .listRowSeparator(.hidden)
//                    HStack {
//                        ZStack {
//                            RoundedRectangle(cornerRadius: 26)
//                                .frame(width: 150, height: 50)
//                            
//                            PhotosPicker("", selection: $viewModel.backgroundPickerItem, matching: .images)
//                                .buttonStyle(.plain)
//                                .background(.clear)
//                                .frame(width: 160)
//                        }
//                           
//                        PhotosPicker(selection: $viewModel.backgroundPickerItem, matching: .images) {
//                            HStack(spacing: 8) {
//                                Image(systemName: "photo.on.rectangle")
//                                Text("Choose Background")
//                                    .font(.headline)
//                            }
//                            .padding(.horizontal, 160).padding(.vertical, 120)
//                            .clipShape(Capsule())
//                            .glassEffect(.regular, in: Capsule())
//                            .background(.ultraThinMaterial, in: Capsule())
//                        }
//                        .tint(.primary)
//                        
//                        
//                        if imageData != nil {
//                            Button {
//                                imageData = nil
//                                BackgroundStorage.clear()
//                            } label: {
//                                Label("Remove Background", systemImage: "trash")
//                                    
//                            }
//                            .frame(width: 160, height: 60)
//                            
//                            .buttonStyle(.bordered)
//                        }
//                    }
//                }
//                .listRowSeparator(.hidden)
                Section("Support and Feedback") {
                    VStack {
                            VStack(alignment: .center) {
                                PrimaryButton(title: "Share With Frined", color: Color(.systemGray4), foregroundStyle: .black) {
                                    print("Share app")
                                }
                                PrimaryButton(title: "Rate App support and Feedback", color: Color(.systemGray4), foregroundStyle: .black) {
                                    print("Rate App")
                                }
                                PrimaryButton(title: "Send fast feedback", color: .blue, foregroundStyle: .white) {
                                    print("Send fast feedback")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Settings")
            .listStyle(.insetGrouped)
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
                    PriorityMatrixEditorView()//viewModel: PriorityMatrixEditorViewModel())
                default:
                    EmptyView()
                }
            }
        }
    }
}

import AuthenticationServices

struct SignInWithAppleView: View {
    var body: some View {
        SignInWithAppleButton(
            .signIn,
            onRequest: { request in
                request.requestedScopes = [.fullName, .email]
            },
            onCompletion: { result in
                switch result {
                case .success(let authResults):
                    if let credential = authResults.credential as? ASAuthorizationAppleIDCredential {
                        let userID = credential.user  // unique per app + user
                        print("Signed in with Apple ID: \(userID)")
                        // Save userID in Keychain for persistence
                    }
                case .failure(let error):
                    print("Authorization failed: \(error)")
                }
            }
        )
        .signInWithAppleButtonStyle(.black) // or .white, .whiteOutline
        .frame(height: 50)
    }
}
