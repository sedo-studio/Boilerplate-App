//
//  PaywallTemplateHost.swift
//
//  Presents a chosen template, owns the selected-plan state, and routes the
//  purchase / restore / close actions. In the demo it just confirms + dismisses;
//  in production pass `onPurchase` / `onRestore` that call your PurchasesService:
//
//  ```swift
//  PaywallTemplateHost(template: .anchorDecoy, content: myContent,
//      onPurchase: { plan in Task { try await container.purchasesService.purchase(plan.id) } },
//      onRestore: { Task { try await container.purchasesService.restorePurchases() } })
//  ```
//

import SwiftUI

struct PaywallTemplateHost: View {
    let template: PaywallTemplate
    var content: PaywallContent = .sample
    var onPurchase: ((PaywallPlan) -> Void)? = nil
    var onRestore: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var selectedPlanID: String
    @State private var resultMessage: String?

    init(template: PaywallTemplate,
         content: PaywallContent = .sample,
         onPurchase: ((PaywallPlan) -> Void)? = nil,
         onRestore: (() -> Void)? = nil) {
        self.template = template
        self.content = content
        self.onPurchase = onPurchase
        self.onRestore = onRestore
        _selectedPlanID = State(initialValue: content.defaultPlanID)
    }

    var body: some View {
        templateView
            .alert(template.title, isPresented: .constant(resultMessage != nil)) {
                Button("OK") { resultMessage = nil; dismiss() }
            } message: {
                Text(resultMessage ?? "")
            }
    }

    @ViewBuilder
    private var templateView: some View {
        switch template {
        case .anchorDecoy:
            AnchorDecoyPaywall(content: content, selectedPlanID: $selectedPlanID,
                               onPurchase: handlePurchase, onRestore: handleRestore, onClose: { dismiss() })
        case .valueStack:
            ValueStackPaywall(content: content, selectedPlanID: $selectedPlanID,
                              onPurchase: handlePurchase, onRestore: handleRestore, onClose: { dismiss() })
        case .socialProof:
            SocialProofPaywall(content: content, selectedPlanID: $selectedPlanID,
                               onPurchase: handlePurchase, onRestore: handleRestore, onClose: { dismiss() })
        case .trialTimeline:
            TrialTimelinePaywall(content: content, selectedPlanID: $selectedPlanID,
                                 onPurchase: handlePurchase, onRestore: handleRestore, onClose: { dismiss() })
        case .nowOrNever:
            NowOrNeverPaywall(content: content, selectedPlanID: $selectedPlanID,
                              onPurchase: handlePurchase, onRestore: handleRestore, onClose: { dismiss() })
        case .allPlans:
            AllPlansPaywall(content: content, selectedPlanID: $selectedPlanID,
                            onPurchase: handlePurchase, onRestore: handleRestore, onClose: { dismiss() })
        case .featureCarousel:
            FeatureCarouselPaywall(content: content, selectedPlanID: $selectedPlanID,
                                   onPurchase: handlePurchase, onRestore: handleRestore, onClose: { dismiss() })
        case .smartTrialToggle:
            SmartTrialTogglePaywall(content: content, selectedPlanID: $selectedPlanID,
                                    onPurchase: handlePurchase, onRestore: handleRestore, onClose: { dismiss() })
        case .minimalist:
            MinimalistPaywall(content: content, selectedPlanID: $selectedPlanID,
                              onPurchase: handlePurchase, onRestore: handleRestore, onClose: { dismiss() })
        case .uiShowcase:
            UIShowcasePaywall(content: content, selectedPlanID: $selectedPlanID,
                              onPurchase: handlePurchase, onRestore: handleRestore, onClose: { dismiss() })
        }
    }

    private func handlePurchase(_ plan: PaywallPlan) {
        AppLogger.log("[Paywall:\(template.rawValue)] purchase tapped: \(plan.id)", level: .info)
        if let onPurchase {
            onPurchase(plan)
        } else {
            resultMessage = "Demo only — this would purchase “\(plan.name)” (\(plan.priceText)).\n\nWire `onPurchase` to your PurchasesService in production."
        }
    }

    private func handleRestore() {
        AppLogger.log("[Paywall:\(template.rawValue)] restore tapped", level: .info)
        if let onRestore {
            onRestore()
        } else {
            resultMessage = "Demo only — this would restore purchases."
        }
    }
}
