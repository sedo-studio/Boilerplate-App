//
//  OnboardingView.swift
//
//  Three screens: what it does, what it honestly cannot do, and the Bluetooth
//  permission ask. The permission prompt is deliberately last so the system
//  dialog arrives after the explanation, not before it.
//

import SwiftUI

struct OnboardingView: View {
    var done: () -> Void

    @State private var pageIndex = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(systemImage: "airpodspro",
                       title: "onb.find.title",
                       body: "onb.find.body"),
        OnboardingPage(systemImage: "wave.3.right",
                       title: "onb.honest.title",
                       body: "onb.honest.body"),
        OnboardingPage(systemImage: "dot.radiowaves.left.and.right",
                       title: "onb.bluetooth.title",
                       body: "onb.bluetooth.body")
    ]

    private var isLastPage: Bool { pageIndex == pages.count - 1 }

    var body: some View {
        ZStack {
            AnimatedBackground().ignoresSafeArea()

            VStack(spacing: DS.Spacing.xl) {
                TabView(selection: $pageIndex) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        OnboardingPageView(page: page).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .animation(.easeInOut(duration: DS.Motion.normal), value: pageIndex)

                VStack(spacing: DS.Spacing.md) {
                    Button(action: advance) {
                        Text(isLastPage ? "onb.bluetooth.cta" : "onb.continue")
                    }
                    .buttonStyle(DSPrimaryButtonStyle())

                    if isLastPage {
                        Text("onb.bluetooth.note")
                            .appFont(.caption)
                            .foregroundStyle(DS.Colors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xl)
            }
        }
    }

    private func advance() {
        guard isLastPage else {
            withAnimation { pageIndex += 1 }
            return
        }
        // Creating the central manager is what shows the system prompt.
        BluetoothFinder.shared.prepare()
        done()
    }
}

private struct OnboardingPage {
    let systemImage: String
    let title: LocalizedStringKey
    let body: LocalizedStringKey
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(DS.accent.opacity(0.12)).frame(width: 150, height: 150)
                Image(systemName: page.systemImage)
                    .font(.system(size: 60, weight: .semibold))
                    .foregroundStyle(DS.accent)
            }
            VStack(spacing: DS.Spacing.md) {
                Text(page.title)
                    .appFont(.title)
                    .multilineTextAlignment(.center)
                Text(page.body)
                    .appFont(.body)
                    .foregroundStyle(DS.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Spacing.xl)
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View { OnboardingView(done: {}) }
}
