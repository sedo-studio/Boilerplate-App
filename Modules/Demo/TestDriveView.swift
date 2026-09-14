//
//  TestDriveView.swift
//

import SwiftUI

struct TestDriveView: View {
    @Environment(\.container) private var container
    @EnvironmentObject private var router: AppRouter
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding: Bool = true
    @AppStorage("forceOnboardingOnce") private var forceOnboardingOnce: Bool = false

    @State private var showAuth: Bool = false
    @State private var showRating: Bool = false
    @State private var bioTestResult: String? = nil
    @State private var showQuestionnaire: Bool = false
    var continueAction: (AppRoute?) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("tester.overview") {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        Text(container.config.appName)
                            .appFont(.title2)
                        Text("tester.subtitle")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, DS.Spacing.sm)
                }

                Section("tester.section.flow") {
                    Button { continueAction(nil) } label: {
                        Label("tester.launchapp", systemImage: "play.fill")
                    }
                    Button { hasSeenOnboarding = false } label: {
                        Label("tester.resetonboarding", systemImage: "arrow.counterclockwise")
                    }
                    Button { forceOnboardingOnce = true; hasSeenOnboarding = false; continueAction(nil) } label: {
                        Label("tester.showonboarding", systemImage: "sparkles")
                    }
                    Button { showAuth = true } label: {
                        Label("tester.showauth", systemImage: "person.crop.circle.badge.checkmark")
                    }
                    Button {
                        Task {
                            // Sign out to force auth, then run full flow: onboarding -> auth -> app (paywall removed)
                            await container.authRepository.signOut()
                            await container.purchasesService.logOut()
                            NotificationCenter.default.post(name: .authStatusDidChange, object: nil)
                            UserDefaults.standard.set(true, forKey: "forceOnboardingOnce")
                            UserDefaults.standard.set(false, forKey: "hasSeenOnboarding")
                            continueAction(nil)
                        }
                    } label: {
                        Label("tester.runfullflow", systemImage: "arrow.triangle.2.circlepath")
                    }
                }

                Section("tester.section.shortcuts") {
                    Button { continueAction(.home) } label: {
                        Label("tester.openhome", systemImage: "house.fill")
                    }
                    Button { continueAction(.settings) } label: {
                        Label("tester.opensettings", systemImage: "gearshape.fill")
                    }
                    if container.config.featureFlags.notifications {
                        Button { continueAction(.notifications) } label: {
                            Label("tester.opennotifs", systemImage: "bell.badge.fill")
                        }
                    }
                    if container.config.featureFlags.paywall {
                        Button { continueAction(.paywall) } label: {
                            Label("Open Paywall", systemImage: "sparkles")
                        }
                    }
                    NavigationLink {
                        LocalDataDemoView()
                    } label: { Label("Local DB Demo", systemImage: "internaldrive") }
                    
                    Button { showRating = true } label: {
                        Label("Show Rating Prompt", systemImage: "star.fill")
                    }
                }

                // ── PRO features — each row is flag-gated. To remove a feature
                //    entirely: delete its block here + delete its module folder. ──
                Section("tester.section.pro") {
                    if container.config.featureFlags.charts {
                        NavigationLink {
                            ChartsDemoView()
                        } label: { Label("tester.charts", systemImage: "chart.xyaxis.line") }
                    }
                    if container.config.featureFlags.inAppFeedback {
                        NavigationLink {
                            FeedbackView()
                        } label: { Label("tester.feedback", systemImage: "bubble.left.and.bubble.right") }
                    }
                    if container.config.featureFlags.localization {
                        NavigationLink {
                            LanguagePickerView()
                        } label: { Label("tester.language", systemImage: "globe") }
                    }
                    if container.config.featureFlags.paywallTemplates {
                        NavigationLink {
                            PaywallGalleryView()
                        } label: { Label("Paywall Templates", systemImage: "creditcard.fill") }
                    }
                    if container.config.featureFlags.gamification {
                        NavigationLink {
                            GamificationDemoView()
                        } label: { Label("Gamification", systemImage: "trophy.fill") }
                    }
                    if container.config.featureFlags.reminders {
                        NavigationLink {
                            RemindersDemoView()
                        } label: { Label("Reminders", systemImage: "bell.badge.fill") }
                    }
                    if container.config.featureFlags.questionnaireOnboarding {
                        Button { showQuestionnaire = true } label: {
                            Label("Questionnaire Onboarding", systemImage: "list.bullet.clipboard")
                        }
                    }
                    if container.config.featureFlags.swiftDataStore, #available(iOS 17, *) {
                        NavigationLink {
                            SwiftDataDemoView()
                        } label: { Label("SwiftData Store", systemImage: "internaldrive") }
                    }
                    if container.config.featureFlags.camera {
                        NavigationLink {
                            CaptureDemoView()
                        } label: { Label("Camera & OCR", systemImage: "doc.text.viewfinder") }
                    }
                    if container.config.featureFlags.aiPro {
                        NavigationLink {
                            AIProChatView()
                        } label: { Label("AI PRO Chat", systemImage: "sparkles.rectangle.stack") }
                    }
                    if container.config.featureFlags.widgets {
                        NavigationLink {
                            WidgetsDemoView()
                        } label: { Label("Widgets & Live Activities", systemImage: "square.stack.3d.up.fill") }
                    }
                    if container.config.featureFlags.reviewPrompt {
                        Button { ReviewManager.shared.requestNativeReviewNow() } label: {
                            Label("tester.review.native", systemImage: "star.bubble")
                        }
                        Button { ReviewManager.shared.registerSignificantEvent() } label: {
                            Label("tester.review.event", systemImage: "plus.circle")
                        }
                    }
                    if container.config.featureFlags.biometricLock {
                        Button { AppLockManager.shared.lockNow() } label: {
                            Label("tester.applock", systemImage: "lock.fill")
                        }
                        Button {
                            AppLockManager.shared.runBiometricTest { result in
                                bioTestResult = result
                            }
                        } label: {
                            Label("tester.applock.test", systemImage: "faceid")
                        }
                    }
                }

                Section("showcase.theme") {
                    HStack {
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(DS.primary)
                            .frame(width: 44, height: 44)
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(DS.accent)
                            .frame(width: 44, height: 44)
                        Text("showcase.colors")
                    }
                }
            }
            .navigationTitle(Text("tester.title"))
        }
        .fullScreenCover(isPresented: $showAuth) {
            AuthCoordinator { _ in showAuth = false }
        }
        .fullScreenCover(isPresented: $showQuestionnaire) {
            QuestionnaireOnboardingView()
        }
        .sheet(isPresented: $showRating) {
            // Replace __TESTFLIGHT_APP_ID__ via setup.sh or manually with your App Store app ID.
            RatingPromptView(isPresented: $showRating, appId: "__TESTFLIGHT_APP_ID__")
                .presentationDetents([.medium])
        }
        .animation(.easeInOut(duration: 0.25), value: showAuth)
        .animation(.easeInOut(duration: 0.25), value: showRating)
        .alert("applock.test.title", isPresented: .constant(bioTestResult != nil)) {
            Button("generic.ok") { bioTestResult = nil }
        } message: {
            Text(bioTestResult ?? "")
        }
    }
}
