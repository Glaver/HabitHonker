
//  SettingsView.swift
//  HabitHonker
//
//  Created by Vladyslav on 9/19/25.
//

import SwiftUI

struct SettingsView: View {
    @State private var path = NavigationPath()
    @State private var isLoggedIn: Bool = false
    @State private var isSynchronized: Bool = false
    
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
                    HStack {
                        Text("Theme")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .scaledToFill()
                            .frame(width: 6, height: 22)
                            .tint(Color.gray.opacity(0.5))
                    }
                    .onTapGesture() {
                        print("Check how to make swither inside app (auto/dark/light)")
                    }
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
                    HStack {
                        Text("Setup background")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .scaledToFill()
                            .frame(width: 6, height: 22)
                            .tint(Color.gray.opacity(0.5))
                    }
                    .onTapGesture {
                        print("Need to check how to set up background in apps and how to advice presets for best fit liquid glass")
                    }
                }
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
            
            .listStyle(.insetGrouped)
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
