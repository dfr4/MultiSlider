//
//  MultiSlider+Drag.swift
//  MultiSlider
//
//  Created by Yonat Sharon on 25.10.2018.
//

extension MultiSlider: UIGestureRecognizerDelegate {
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }

    @objc open func didDrag(_ panGesture: UIPanGestureRecognizer) {
        switch panGesture.state {
        case .began:
            if isHapticSnap { selectionFeedbackGenerator.prepare() }
            // determine thumb to drag
            let location = panGesture.location(in: slideView)
            draggedThumbIndex = closestThumb(point: location)
        case .ended, .cancelled, .failed:
            if isHapticSnap { selectionFeedbackGenerator.end() }
            sendActions(for: .touchUpInside) // no bounds check for now (.touchUpInside vs .touchUpOutside)
            if !isContinuous { sendActions(for: [.valueChanged, .primaryActionTriggered]) }
        default:
            break
        }
        guard draggedThumbIndex >= 0 else { return }

        let slideViewLength = slideView.bounds.size(in: orientation)
        var targetPosition = panGesture.location(in: slideView).coordinate(in: orientation)
        let stepSizeInView = (snapStepSize / (maximumValue - minimumValue)) * slideViewLength

        // snap translation to stepSizeInView
        if snapStepSize > 0 {
            let translationSnapped = panGesture.translation(in: slideView).coordinate(in: orientation).rounded(stepSizeInView)
            if 0 == Int(translationSnapped) { return }
            panGesture.setTranslation(.zero, in: slideView)
        }

        // don't cross prev/next thumb and total range
        targetPosition = boundedDraggedThumbPosition(targetPosition: targetPosition, stepSizeInView: stepSizeInView)

        // change corresponding value
        updateDraggedThumbValue(relativeValue: targetPosition / slideViewLength)

        UIView.animate(withDuration: 0.1) {
            self.updateDraggedThumbPositionAndLabel()
            self.layoutIfNeeded()
        }

        if isContinuous { sendActions(for: [.valueChanged, .primaryActionTriggered]) }
        
        updatingThumbs(panGesture)
    }
    
    @objc open func updatingThumbs(_ panGesture: UIPanGestureRecognizer) {
        
    }

    /// adjusted position that doesn't cross prev/next thumb and total range
    private func boundedDraggedThumbPosition(targetPosition: CGFloat, stepSizeInView: CGFloat) -> CGFloat {
        var delta = snapStepSize > 0 ? stepSizeInView : thumbViews[draggedThumbIndex].frame.size(in: orientation) / 2
        delta = keepsDistanceBetweenThumbs ? delta : 0
        if orientation == .horizontal { delta = -delta }
        
        var bottomLimit: CGFloat!
        var topLimit: CGFloat!
        
        if orientation == .vertical {
            bottomLimit = slideView.bounds.bottom(in: orientation)
            topLimit = slideView.bounds.top(in: orientation)
        } else {
            bottomLimit = draggedThumbIndex > 0
                ? thumbViews[draggedThumbIndex - 1].center.coordinate(in: orientation) - delta
                : slideView.bounds.bottom(in: orientation)
            
            topLimit = draggedThumbIndex < thumbViews.count - 1
                ? thumbViews[draggedThumbIndex + 1].center.coordinate(in: orientation) + delta
                : slideView.bounds.top(in: orientation)
        }
        
        if orientation == .vertical {
            return min(bottomLimit, max(targetPosition, topLimit))
        } else {
            return max(bottomLimit, min(targetPosition, topLimit))
        }
    }

    private func updateDraggedThumbValue(relativeValue: CGFloat) {
        var newValue = relativeValue * (maximumValue - minimumValue)
        if orientation == .vertical {
            newValue = maximumValue - newValue
        } else {
            newValue += minimumValue
        }
        newValue = newValue.rounded(snapStepSize)
        guard newValue != value[draggedThumbIndex] else { return }
        isSettingValue = true
        value[draggedThumbIndex] = newValue
        isSettingValue = false
        if (isHapticSnap && snapStepSize > 0) || relativeValue == 0 || relativeValue == 1 {
            selectionFeedbackGenerator.generateFeedback()
        }
    }

    private func updateDraggedThumbPositionAndLabel() {
        positionThumbView(draggedThumbIndex)
        if draggedThumbIndex < valueLabels.count {
            updateValueLabel(draggedThumbIndex)
            if isValueLabelRelative && draggedThumbIndex + 1 < valueLabels.count {
                updateValueLabel(draggedThumbIndex + 1)
            }
        }
    }

    private func closestThumb(point: CGPoint) -> Int {
        var closest = -1
        var minimumDistance = CGFloat.greatestFiniteMagnitude
        for i in 0 ..< thumbViews.count {
            guard !disabledThumbIndices.contains(i) else { continue }
            let distance = point.distanceTo(thumbViews[i].center)
            if distance > minimumDistance { break }
            minimumDistance = distance
            if distance < thumbViews[i].diagonalSize {
                closest = i
            }
        }
        return closest
    }
}
