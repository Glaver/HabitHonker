import Foundation
import XCTest
@testable import HabitHonker

final class PredictionCoreTests: XCTestCase {
    func testSnapshotCanRepresentTargetWithNoHistory() {
        let target = makeTarget()
        let capturedAt = Date(timeIntervalSince1970: 1_800_000_000)

        let snapshot = UserStateSnapshot(target: target, capturedAt: capturedAt)

        XCTAssertEqual(snapshot.target, target)
        XCTAssertEqual(snapshot.capturedAt, capturedAt)
        XCTAssertTrue(snapshot.recentCompletionEvents.isEmpty)
        XCTAssertTrue(snapshot.recentMissedDates.isEmpty)
    }

    func testSnapshotCanRepresentRecentCompletionsAndMissesConceptually() {
        let targetID = BehaviorTargetID(UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let target = makeTarget(id: targetID)
        let completedAt = Date(timeIntervalSince1970: 1_800_000_100)
        let missedAt = Date(timeIntervalSince1970: 1_800_000_200)
        let completion = BehaviorEvent(
            targetID: targetID,
            occurredAt: completedAt,
            kind: .completed(count: 1)
        )

        let snapshot = UserStateSnapshot(
            target: target,
            capturedAt: Date(timeIntervalSince1970: 1_800_000_300),
            recentCompletionEvents: [completion],
            recentMissedDates: [missedAt]
        )

        XCTAssertEqual(snapshot.recentCompletionEvents, [completion])
        XCTAssertEqual(snapshot.recentMissedDates, [missedAt])
    }

    func testRiskAssessmentCanRepresentLowMediumAndHighRisk() {
        let targetID = BehaviorTargetID(UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
        let assessedAt = Date(timeIntervalSince1970: 1_800_000_400)

        let low = RiskAssessment(
            targetID: targetID,
            level: .low,
            score: 0.1,
            assessedAt: assessedAt
        )
        let medium = RiskAssessment(
            targetID: targetID,
            level: .medium,
            score: 0.5,
            assessedAt: assessedAt
        )
        let high = RiskAssessment(
            targetID: targetID,
            level: .high,
            score: 0.9,
            assessedAt: assessedAt
        )

        XCTAssertEqual(RiskLevel.allCases, [.low, .medium, .high])
        XCTAssertEqual(low.level, .low)
        XCTAssertEqual(medium.level, .medium)
        XCTAssertEqual(high.level, .high)
    }

    func testInterventionDecisionReferencesTargetAssessmentInterventionAndExplanationCodes() {
        let targetID = BehaviorTargetID(UUID(uuidString: "33333333-3333-3333-3333-333333333333")!)
        let signalObservedAt = Date(timeIntervalSince1970: 1_800_000_500)
        let decidedAt = Date(timeIntervalSince1970: 1_800_000_600)
        let signal = RiskSignal(
            targetID: targetID,
            kind: .recentMiss,
            strength: 0.7,
            observedAt: signalObservedAt,
            explanationCode: "recent_miss"
        )
        let assessment = RiskAssessment(
            targetID: targetID,
            level: .high,
            score: 0.85,
            signals: [signal],
            explanationCodes: ["recent_miss", "priority_weight"],
            assessedAt: signalObservedAt
        )
        let intervention = Intervention(
            kind: .planningPrompt,
            explanationCode: "suggest_plan"
        )

        let decision = InterventionDecision(
            targetID: targetID,
            riskAssessment: assessment,
            selectedIntervention: intervention,
            explanationCodes: ["high_risk", "suggest_plan"],
            decidedAt: decidedAt
        )

        XCTAssertEqual(decision.targetID, targetID)
        XCTAssertEqual(decision.riskAssessment, assessment)
        XCTAssertEqual(decision.selectedIntervention, intervention)
        XCTAssertEqual(decision.explanationCodes, ["high_risk", "suggest_plan"])
        XCTAssertEqual(decision.decidedAt, decidedAt)
    }

    func testDeliveryPolicyResultCanRepresentAllowedAndSuppressedDecisions() {
        let targetID = BehaviorTargetID(UUID(uuidString: "44444444-4444-4444-4444-444444444444")!)
        let evaluatedAt = Date(timeIntervalSince1970: 1_800_000_700)

        let allowed = DeliveryPolicyResult(
            targetID: targetID,
            isDeliveryAllowed: true,
            reasonCodes: ["within_policy"],
            evaluatedAt: evaluatedAt
        )
        let suppressed = DeliveryPolicyResult(
            targetID: targetID,
            isDeliveryAllowed: false,
            reasonCodes: ["quiet_window"],
            evaluatedAt: evaluatedAt
        )

        XCTAssertTrue(allowed.isDeliveryAllowed)
        XCTAssertFalse(suppressed.isDeliveryAllowed)
        XCTAssertEqual(allowed.reasonCodes, ["within_policy"])
        XCTAssertEqual(suppressed.reasonCodes, ["quiet_window"])
    }

    func testPredictionCoreDoesNotImportUIOrPersistenceFrameworks() throws {
        let forbiddenFrameworks = ["SwiftUI", "SwiftData", "UserNotifications", "CloudKit"]
        let predictionDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("HabitHonker/Core/Prediction")
        let fileManager = FileManager.default
        let sourceFiles = try XCTUnwrap(
            fileManager.enumerator(
                at: predictionDirectory,
                includingPropertiesForKeys: nil
            )?
            .compactMap { $0 as? URL }
            .filter { $0.pathExtension == "swift" }
        )

        XCTAssertFalse(sourceFiles.isEmpty)

        for fileURL in sourceFiles {
            let contents = try String(contentsOf: fileURL)

            for framework in forbiddenFrameworks {
                XCTAssertFalse(
                    contents.contains("import \(framework)"),
                    "\(fileURL.lastPathComponent) must not import \(framework)"
                )
            }
        }
    }

    private func makeTarget(
        id: BehaviorTargetID = BehaviorTargetID(UUID(uuidString: "55555555-5555-5555-5555-555555555555")!)
    ) -> BehaviorTarget {
        BehaviorTarget(
            id: id,
            title: "Read",
            schedule: .repeating(weekdays: [.monday, .wednesday, .friday])
        )
    }
}
