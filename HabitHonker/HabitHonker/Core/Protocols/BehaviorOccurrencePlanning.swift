import Foundation

protocol BehaviorOccurrencePlanning: Sendable {
    func plan(_ input: BehaviorOccurrencePlanningInput) -> BehaviorOccurrencePlan
}
