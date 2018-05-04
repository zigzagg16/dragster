import Foundation
import UIKit

protocol DragsterProtocol {
    var configuration: DragsterConfig { get set }
    func start(with configuration: DragsterConfig, constraint: NSLayoutConstraint)
    func open(animated: Bool, completion: @escaping (() -> Void))
    func close(animated: Bool, completion: @escaping (() -> Void))
    var percentage: CGFloat { get }
}

struct DragsterConfig {
    let opened: CGFloat
    let closed: CGFloat
    let tolerance: CGFloat
}

class Dragster: UIView, DragsterProtocol {
    var percentage: CGFloat = 0.0
    var configuration: DragsterConfig = DragsterConfig(opened: 0, closed: 0, tolerance: 0)
    private var originalConstant: CGFloat = 0.0
    private var panningStartConstant: CGFloat = 0.0
    private var constraint: NSLayoutConstraint = NSLayoutConstraint()

    func start(with configuration: DragsterConfig,
               constraint: NSLayoutConstraint) {
        self.constraint = constraint
        self.originalConstant = constraint.constant
        self.configuration = configuration
        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        addGestureRecognizer(panGesture)
        close(animated: false, completion: {})
    }

    ///Called when the view moves (Panned by the user)
    @objc func panned(_ sender: UIPanGestureRecognizer) {
        if sender.state == .began { startedPanning() }

        let translation = sender.translation(in: self).y
        handlePanning(translation: translation)

        if sender.state == UIGestureRecognizerState.ended { endedPanning() }
    }

    private func startedPanning() {
        panningStartConstant = constraint.constant
        haptickFeedback()
    }

    private func handlePanning(translation: CGFloat) {
        let range = ClosedRange(uncheckedBounds: (lower: configuration.opened, upper: configuration.closed))
        let constantValue = movingValue(translation: translation,
                                        constant: panningStartConstant,
                                        tolerance: configuration.tolerance,
                                        range: range)
        constraint.constant = constantValue

        percentage = calculatePercentage(originalValue: range.upperBound,
                                         value: constraint.constant,
                                         max: range.lowerBound)
    }

    private func calculatePercentage(originalValue: CGFloat,
                                     value: CGFloat,
                                     max: CGFloat) -> CGFloat {
        let totalDistance = originalValue - max
        let positionValue = value - originalValue
        return (100.0 / (totalDistance / positionValue)) * -1
    }

    private func endedPanning() {
        if percentage < 25.0 {
            close(animated: true, completion: {})
        } else if percentage > 75 {
            open(animated: true, completion: {})
        }
    }

    func open(animated: Bool, completion: @escaping (() -> Void)) {
        animateToValue(value: configuration.opened, animated: animated, completion: completion)
    }

    func close(animated: Bool, completion: @escaping (() -> Void)) {
        animateToValue(value: configuration.closed, animated: animated, completion: completion)
    }

    private func animateToValue(value: CGFloat, animated: Bool, completion: @escaping (() -> Void)) {
        if animated {
            constraint.constant = value
            UIView.animate(withDuration: 0.3,
                           delay: 0,
                           usingSpringWithDamping: 0.5,
                           initialSpringVelocity: 5,
                           options: UIViewAnimationOptions.allowUserInteraction,
                           animations: { () -> Void in
                            self.superview!.layoutIfNeeded()
            }, completion: { _ in
                self.haptickFeedback()
                completion()
            })
        } else {
            constraint.constant = value
            completion()
        }
    }

    ///Haptick feedback, if supported. Min iOS 10.0.
    private func haptickFeedback() {
        if #available(iOS 10.0, *) {
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        }
    }

    ///Calculates the value to move the view
    /// - Parameter translation: The gesture translation value
    /// - Parameter constant: The constraint's actual constant
    /// - Returns: CGFloat: The new value to apply to the constraint's constant.
    private func movingValue(translation: CGFloat,
                             constant: CGFloat,
                             tolerance: CGFloat,
                             range: ClosedRange<CGFloat>) -> CGFloat {
        let expectedValue = constant + translation
        if expectedValue > range.upperBound { //if lower than the closed value
            let log = logarithm(tolerance, translation)
            let finalValue = constant + log
            return finalValue
        } else if expectedValue < range.lowerBound {
            let log = logarithm(tolerance, abs(translation)) - (tolerance * 2)
            let finalValue = range.lowerBound - (log.isInfinite ? 0 : log)
            return finalValue
        }
        return expectedValue
    }

    ///Calculate the value for the rubber effect
    /// - Parameter limit: the dragging limit of the view
    /// - Parameter yPosition: the position of the view
    /// - Returns: CGFloat: The updated position for the rubber effect
    private func logarithm(_ limit: CGFloat, _ yPosition: CGFloat) -> CGFloat {
        return limit * (1 + log10(yPosition / limit))
    }
}
