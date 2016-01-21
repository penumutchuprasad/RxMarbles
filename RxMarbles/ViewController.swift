//
//  ViewController.swift
//  RxMarbles
//
//  Created by Roman Tutubalin on 06.01.16.
//  Copyright © 2016 Roman Tutubalin. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa

struct ColoredType: Equatable {
    var value: String
    var color: UIColor
    var shape: EventShape
}

struct Image {
    static var timeLine: UIImage { return UIImage(named: "timeLine")! }
    static var cross: UIImage { return UIImage(named: "cross")! }
    static var trash: UIImage { return UIImage(named: "Trash")! }
}

enum EventShape {
    case Circle
    case RoundedRect
    case Rhombus
    case Another
}

func ==(lhs: ColoredType, rhs: ColoredType) -> Bool {
    return lhs.value == rhs.value && lhs.color == rhs.color && lhs.shape == rhs.shape
}

typealias RecordedType = Recorded<Event<ColoredType>>

extension UIView {
    
    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform")
        let wobbleAngle: CGFloat = 0.3
        
        let valLeft = NSValue(CATransform3D:CATransform3DMakeRotation(wobbleAngle, 0.0, 0.0, 1.0))
        let valRight = NSValue(CATransform3D:CATransform3DMakeRotation(-wobbleAngle, 0.0, 0.0, 1.0))
        animation.values = [valLeft, valRight]
        
        animation.autoreverses = true
        animation.duration = 0.125
        animation.repeatCount = 10000
        
        if layer.animationKeys() == nil {
            layer.addAnimation(animation, forKey: "shake")
        }
    }
    
    func hideWithCompletion(completion: (Bool) -> Void) {
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.alpha = 0.01
            self.transform = CGAffineTransformMakeScale(0.1, 0.1)
        }, completion: completion)
    }
    
    func stopAnimations() {
        self.layer.removeAllAnimations()
    }
}

class EventView: UIView {
    private var _recorded = RecordedType(time: 0, event: .Completed)
    private weak var _animator: UIDynamicAnimator? = nil
    private var _snap: UISnapBehavior? = nil
    private var _gravity: UIGravityBehavior? = nil
    private var _removeBehavior: UIDynamicItemBehavior? = nil
    private weak var _timeLine: SourceTimelineView?
    private var _tapGestureRecognizer: UITapGestureRecognizer!
    private var _parentViewController: ViewController!
    private var _label = UILabel()
    
    init(recorded: RecordedType, shape: EventShape, viewController: ViewController!) {
        switch recorded.value {
        case let .Next(v):
            super.init(frame: CGRectMake(0, 0, 38, 38))
            center = CGPointMake(CGFloat(recorded.time), bounds.height)
            clipsToBounds = true
            backgroundColor = v.color
            layer.borderColor = UIColor.lightGrayColor().CGColor
            layer.borderWidth = 0.5
            _label.center = CGPointMake(19, 19)
            _label.textAlignment = .Center
            _label.font = UIFont(name: "", size: 17.0)
            _label.numberOfLines = 1
            _label.adjustsFontSizeToFitWidth = true
            _label.minimumScaleFactor = 0.6
            _label.lineBreakMode = .ByTruncatingTail
            _label.textColor = .whiteColor()
            addSubview(_label)
            
            if let value = recorded.value.element?.value {
                _label.text = String(value)
            }
            switch shape {
            case .Circle:
                layer.cornerRadius = bounds.width / 2.0
            case .RoundedRect:
                layer.cornerRadius = 5.0
            case .Rhombus:
                let width = layer.frame.size.width
                let height = layer.frame.size.height
                
                let mask = CAShapeLayer()
                mask.frame = layer.bounds
                
                let path = CGPathCreateMutable()
                CGPathMoveToPoint(path, nil, width / 2.0, 0)
                CGPathAddLineToPoint(path, nil, width, height / 2.0)
                CGPathAddLineToPoint(path, nil, width / 2.0, height)
                CGPathAddLineToPoint(path, nil, 0, height / 2.0)
                CGPathAddLineToPoint(path, nil, width / 2.0, 0)
                
                mask.path = path
                layer.mask = mask
                
                let border = CAShapeLayer()
                border.frame = bounds
                border.path = path
                border.lineWidth = 0.5
                border.strokeColor = UIColor.lightGrayColor().CGColor
                border.fillColor = UIColor.clearColor().CGColor
                layer.insertSublayer(border, atIndex: 0)
                
            case .Another:
                break
            }
            
        case .Completed:
            super.init(frame: CGRectMake(0, 0, 37, 38))
            center = CGPointMake(CGFloat(recorded.time), bounds.height)
            backgroundColor = .clearColor()
            
            let grayLine = UIView(frame: CGRectMake(17.5, 5, 3, 28))
            grayLine.backgroundColor = .grayColor()
            
            addSubview(grayLine)
            
            bringSubviewToFront(self)
        case .Error:
            super.init(frame: CGRectMake(0, 0, 37, 38))
            center = CGPointMake(CGFloat(recorded.time), bounds.height)
            backgroundColor = .clearColor()
            
            let firstLineCross = UIView(frame: CGRectMake(17.5, 7.5, 3, 23))
            firstLineCross.backgroundColor = .grayColor()
            firstLineCross.transform = CGAffineTransformMakeRotation(CGFloat(M_PI * 0.25))
            addSubview(firstLineCross)
            
            let secondLineCross = UIView(frame: CGRectMake(17.5, 7.5, 3, 23))
            secondLineCross.backgroundColor = .grayColor()
            secondLineCross.transform = CGAffineTransformMakeRotation(CGFloat(M_PI * 0.75))
            addSubview(secondLineCross)
            
            bringSubviewToFront(self)
        }
        
        _gravity = UIGravityBehavior(items: [self])
        _removeBehavior = UIDynamicItemBehavior(items: [self])
        _recorded = recorded
        _tapGestureRecognizer = UITapGestureRecognizer(target: self, action: "setEventView")
        _parentViewController = viewController
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if isNext {
            _label.frame = CGRectInset(frame, 3.0, 10.0)
            _label.center = CGPointMake(19, 19)
            _label.baselineAdjustment = .AlignCenters
        }
    }
    
    func use(animator: UIDynamicAnimator?, timeLine: SourceTimelineView?) {
        if let snap = _snap {
            _animator?.removeBehavior(snap)
        }
        _animator = animator
        _timeLine = timeLine
        if let timeLine = timeLine {
            center.y = timeLine.bounds.height / 2
        }

        _snap = UISnapBehavior(item: self, snapToPoint: CGPointMake(CGFloat(_recorded.time), center.y))
        userInteractionEnabled = _animator != nil
    }
    
    var isCompleted: Bool {
        if case .Completed = _recorded.value {
            return true
        } else {
            return false
        }
    }
    
    var isNext: Bool {
        if case .Next = _recorded.value {
            return true
        } else {
            return false
        }
    }
    
    func addTapRecognizer() {
        addGestureRecognizer(_tapGestureRecognizer!)
    }
    
    func removeTapRecognizer() {
        removeGestureRecognizer(_tapGestureRecognizer!)
    }
    
    func setEventView() {
        let settingsAlertController = UIAlertController(title: nil, message: nil, preferredStyle: .Alert)
        
        if isNext {
            let contentViewController = UIViewController()
            contentViewController.preferredContentSize = CGSizeMake(200.0, 90.0)
            
            let eventView = EventView(recorded: _recorded, shape: (_recorded.value.element?.shape)!, viewController: _parentViewController)
            eventView.center = CGPointMake(100.0, 25.0)
            contentViewController.view.addSubview(eventView)
            
            let colors = [RXMUIKit.lightBlueColor(), RXMUIKit.darkYellowColor(), RXMUIKit.lightGreenColor(), RXMUIKit.blueColor(), RXMUIKit.orangeColor()]
            let currentColor = _recorded.value.element?.color
            let colorsSegment = UISegmentedControl(items: ["", "", "", "", ""])
            colorsSegment.tintColor = .clearColor()
            colorsSegment.frame = CGRectMake(0.0, 50.0, 200.0, 30.0)
            var counter = 0
            colorsSegment.subviews.forEach({ subview in
                subview.backgroundColor = colors[counter]
                if currentColor == colors[counter] {
                    colorsSegment.selectedSegmentIndex = counter
                }
                counter++
            })
            
            if colorsSegment.selectedSegmentIndex < 0 {
                colorsSegment.selectedSegmentIndex = 0
            }
            
            contentViewController.view.addSubview(colorsSegment)
            
            settingsAlertController.setValue(contentViewController, forKey: "contentViewController")
            
            settingsAlertController.addTextFieldWithConfigurationHandler({ (textField) -> Void in
                if let text = self._recorded.value.element?.value {
                    textField.text = text
                }
            })
            
            _ = Observable
                .combineLatest(settingsAlertController.textFields!.first!.rx_text, colorsSegment.rx_value, resultSelector: { text, segment in
                    return (text, segment)
                })
                .subscribeNext({ (text, segment) in
                    self.updatePreviewEventView(eventView, params: (color: colors[segment], value: text))
                })
            
            let saveAction = UIAlertAction(title: "Save", style: .Default) { (action) -> Void in
                self.saveAction(eventView)
            }
            settingsAlertController.addAction(saveAction)
        } else {
            settingsAlertController.message = "Delete event?"
        }
        let deleteAction = UIAlertAction(title: "Delete", style: .Destructive) { (action) -> Void in
            self.deleteAction()
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (action) -> Void in }
        settingsAlertController.addAction(deleteAction)
        settingsAlertController.addAction(cancelAction)
        if let parentViewController = self._parentViewController {
            parentViewController.presentViewController(settingsAlertController, animated: true) { () -> Void in }
        }
    }
    
    private func saveAction(eventView: EventView) {
        let index = _timeLine?._sourceEvents.indexOf(self)
        let time = eventView._recorded.time
        if index != nil {
            _timeLine?._sourceEvents.removeAtIndex(index!)
            removeFromSuperview()
            _timeLine?.addNextEventToTimeline(time, event: eventView._recorded.value, animator: _parentViewController._sceneView.animator, isEditing: true)
            _timeLine?.updateResultTimeline()
        }
    }
    
    private func deleteAction() {
        _animator!.removeAllBehaviors()
        _animator!.addBehavior(_gravity!)
        _animator!.addBehavior(_removeBehavior!)
        _removeBehavior?.action = {
            if let superView = self._parentViewController._sceneView {
                if let index = self._timeLine?._sourceEvents.indexOf(self) {
                    if CGRectIntersectsRect(superView.bounds, self.frame) == false {
                        self.removeFromSuperview()
                        self._timeLine?._sourceEvents.removeAtIndex(index)
                        self._timeLine?.updateResultTimeline()
                    }
                }
            }
        }
    }
    
    private func updatePreviewEventView(eventView: EventView, params: (color: UIColor, value: String)) {
        let time = eventView._recorded.time
        let shape = _recorded.value.element?.shape
        let event = Event.Next(ColoredType(value: params.value, color: params.color, shape: shape!))
        
        eventView._recorded = RecordedType(time: time, event: event)
        eventView._label.text = params.value
        eventView.backgroundColor = params.color
    }
    
    private func scaleAnimation() {
        UIView.animateWithDuration(0.3, animations: { () -> Void in
            self.transform = CGAffineTransformMakeScale(4.0, 4.0)
            self.transform = CGAffineTransformMakeScale(1.0, 1.0)
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}

class TimelineView: UIView {
    var _sourceEvents = [EventView]()
    let _timeArrow = UIImageView(image: Image.timeLine)
    private var _addButton: UIButton?
    var _parentViewController: ViewController!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(_timeArrow)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        frame = CGRectMake(10, frame.origin.y, (superview?.bounds.size.width)! - 20, 40)
        _timeArrow.frame = CGRectMake(0, 16, frame.width, Image.timeLine.size.height)
        if _addButton != nil {
            _addButton?.center.y = _timeArrow.center.y
            _addButton?.center.x = frame.size.width - 10.0
            let timeArrowFrame = _timeArrow.frame
            let newTimeArrowFrame = CGRectMake(timeArrowFrame.origin.x, timeArrowFrame.origin.y, timeArrowFrame.size.width - 23.0, timeArrowFrame.size.height)
            _timeArrow.frame = newTimeArrowFrame
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func maxNextTime() -> Int? {
        var times = Array<Int>()
        _sourceEvents.forEach { (eventView) -> () in
            if eventView.isNext {
                times.append(eventView._recorded.time)
            }
        }
        return times.maxElement()
    }
}

class SourceTimelineView: TimelineView {
    
    private let _longPressGestureRecorgnizer = UILongPressGestureRecognizer()
    private var _panEventView: EventView?
    private var _ghostEventView: EventView?
    private var _sceneView: SceneView!
    
    init(frame: CGRect, resultTimeline: ResultTimelineView) {
        super.init(frame: frame)
        userInteractionEnabled = true
        clipsToBounds = false
        
        _longPressGestureRecorgnizer.minimumPressDuration = 0.0
        
        addGestureRecognizer(_longPressGestureRecorgnizer)
        
        _ = _longPressGestureRecorgnizer.rx_event
            .subscribeNext { [weak self] r in
                
                let sourceEvents = self!._sourceEvents
               
                switch r.state {
                case .Began:
                    let location = r.locationInView(self)
                    if let i = sourceEvents.indexOf({ $0.frame.contains(location) }) {
                        self!._panEventView = sourceEvents[i]
                    }
                    if let panEventView = self!._panEventView {
                        let snap = panEventView._snap
                        panEventView._animator?.removeBehavior(snap!)
                        let shape: EventShape = (panEventView._recorded.value.element?.shape != nil) ? (panEventView._recorded.value.element?.shape)! : .Another
                        self!._ghostEventView = EventView(recorded: panEventView._recorded, shape: shape, viewController: self!._parentViewController)
                        if let ghostEventView = self!._ghostEventView {
                            ghostEventView.center.y = self!.bounds.height / 2
                            self!.changeGhostColorAndAlpha(ghostEventView, recognizer: r)
                            self!.addSubview(ghostEventView)
                            self!._sceneView.showTrashView()
                        }
                    }
                case .Changed:
                    if let panEventView = self!._panEventView {
                        
                        let time = Int(r.locationInView(self).x)
                        panEventView.center = r.locationInView(self)
                        panEventView._recorded = RecordedType(time: time, event: panEventView._recorded.value)
                        
                        if let ghostEventView = self!._ghostEventView {
                            self!.changeGhostColorAndAlpha(ghostEventView, recognizer: r)
                            
                            ghostEventView._recorded = panEventView._recorded
                            ghostEventView.center = CGPointMake(CGFloat(ghostEventView._recorded.time), self!.bounds.height / 2)
                        }
                        self!.updateResultTimeline()
                    }
                case .Ended:
                    self!._ghostEventView?.removeFromSuperview()
                    self!._ghostEventView = nil
                    
                    if let panEventView = self!._panEventView {
                        
                        self!.animatorAddBehaviorsToPanEventView(panEventView, recognizer: r, resultTimeline: resultTimeline)
                        
                        panEventView.superview?.bringSubviewToFront(panEventView)
                        self!.bringStopEventViewsToFront(sourceEvents)
                        
                        let time = Int(r.locationInView(self).x)
                        panEventView._recorded = RecordedType(time: time, event: panEventView._recorded.value)
                    }
                    self!._panEventView = nil
                    self!.updateResultTimeline()
                    self!._sceneView.hideTrashView()
                default: break
            }
        }
    }
    
    private func updateResultTimeline() {
        if let secondSourceTimeline = _sceneView._secondSourceTimeline {
            _sceneView._resultTimeline.updateEvents((_sceneView._sourceTimeline._sourceEvents, secondSourceTimeline._sourceEvents))
        } else {
            _sceneView._resultTimeline.updateEvents((_sceneView._sourceTimeline._sourceEvents, nil))
        }
    }
    
    func addNextEventToTimeline(time: Int, event: Event<ColoredType>, animator: UIDynamicAnimator!, isEditing: Bool) {
        let v = EventView(recorded: RecordedType(time: time, event: event), shape: (event.element?.shape)!, viewController: _parentViewController)
        if isEditing {
            v.addTapRecognizer()
        }
        addSubview(v)
        v.use(animator, timeLine: self)
        _sourceEvents.append(v)
    }
    
    func addCompletedEventToTimeline(time: Int, animator: UIDynamicAnimator!, isEditing: Bool) {
        let v = EventView(recorded: RecordedType(time: time, event: .Completed), shape: .Another, viewController: _parentViewController)
        if isEditing {
            v.addTapRecognizer()
        }
        addSubview(v)
        v.use(animator, timeLine: self)
        _sourceEvents.append(v)
    }
    
    func addErrorEventToTimeline(time: Int!, animator: UIDynamicAnimator!, isEditing: Bool) {
        let v = EventView(recorded: RecordedType(time: time, event: .Error(Error.CantParseStringToInt)), shape: .Another, viewController: _parentViewController)
        if isEditing {
            v.addTapRecognizer()
        }
        addSubview(v)
        v.use(animator, timeLine: self)
        _sourceEvents.append(v)
    }
    
    private func changeGhostColorAndAlpha(ghostEventView: EventView, recognizer: UIGestureRecognizer) {

        if onDeleteZone(recognizer) == true {
            ghostEventView.shake()
            _sceneView._trashView?.shake()
            _sceneView._trashView?.alpha = 0.5
        } else {
            ghostEventView.stopAnimations()
            _sceneView._trashView?.stopAnimations()
            _sceneView._trashView?.alpha = 0.2
        }
        
        let color: UIColor = onDeleteZone(recognizer) ? .redColor() : .grayColor()
        let alpha: CGFloat = onDeleteZone(recognizer) ? 1.0 : 0.2
        
        switch ghostEventView._recorded.value {
        case .Next:
            ghostEventView.alpha = alpha
            ghostEventView.backgroundColor = color
        case .Completed, .Error:
            ghostEventView.subviews.forEach({ (subView) -> () in
                subView.alpha = alpha
                subView.backgroundColor = color
            })
        }
    }
    
    private func animatorAddBehaviorsToPanEventView(panEventView: EventView, recognizer: UIGestureRecognizer, resultTimeline: ResultTimelineView) {
        if let animator = panEventView._animator {
            animator.removeAllBehaviors()
            let time = Int(recognizer.locationInView(self).x)
            
            if onDeleteZone(recognizer) == true {
                panEventView.hideWithCompletion({ _ in
                    if let index = self._sourceEvents.indexOf(panEventView) {
                        self._sourceEvents.removeAtIndex(index)
                        self.updateResultTimeline()
                    }
                })
            } else {
                let snap = panEventView._snap
                snap!.snapPoint.x = CGFloat(time + 10)
                snap!.snapPoint.y = center.y
                animator.addBehavior(snap!)
            }
        }
    }
    
    private func onDeleteZone(recognizer: UIGestureRecognizer) -> Bool {
        if let trash = _sceneView._trashView {
            let loc = recognizer.locationInView(superview)
            let eventViewFrame = CGRectMake(loc.x - 19, loc.y - 19, 38, 38)
            if CGRectIntersectsRect(trash.frame, eventViewFrame) {
                return true
            }
        }
        return false
    }
    
    private func bringStopEventViewsToFront(sourceEvents: [EventView]) {
        sourceEvents.forEach({ (eventView) -> () in
            if eventView._recorded.value.isStopEvent == true {
                eventView.superview!.bringSubviewToFront(eventView)
            }
        })
    }
    
    func showAddButton() {
        _addButton = UIButton(type: .ContactAdd)
        addSubview(_addButton!)
        removeGestureRecognizer(_longPressGestureRecorgnizer)
    }
    
    func hideAddButton() {
        if _addButton != nil {
            _addButton!.removeFromSuperview()
            _addButton = nil
        }
        addGestureRecognizer(_longPressGestureRecorgnizer)
    }
    
    func addTapRecognizers() {
        _sourceEvents.forEach { (eventView) -> () in
            eventView.addTapRecognizer()
        }
    }
    
    func removeTapRecognizers() {
        _sourceEvents.forEach { (eventView) -> () in
            eventView.removeTapRecognizer()
        }
    }
    
    private func allEventViewsAnimation() {
        _sourceEvents.forEach { eventView in
            eventView.scaleAnimation()
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ResultTimelineView: TimelineView {
    
    private var _operator: Operator!
    
    init(frame: CGRect, currentOperator: Operator) {
        super.init(frame: frame)
        _operator = currentOperator
    }
    
    func updateEvents(sourceEvents: (first: [EventView], second: [EventView]?)) {
        let scheduler = TestScheduler(initialClock: 0)
        
        let events = sourceEvents.first.map({ $0._recorded })
        let first = scheduler.createColdObservable(events)
        
        var second: TestableObservable<ColoredType>? = nil
        if let s = sourceEvents.second {
            let secondEvents = s.map({ $0._recorded })
            second = scheduler.createColdObservable(secondEvents)
        }
        
        let o = _operator.map((first, second), scheduler: scheduler)
        var res: TestableObserver<ColoredType>?
        
        res = scheduler.start(0, subscribed: 0, disposed: Int(frame.width)) {
            return o
        }
        
        addEventsToTimeline(res!.events)
    }
    
    func addEventsToTimeline(events: [RecordedType]) {
        _sourceEvents.forEach { (eventView) -> () in
            eventView.removeFromSuperview()
        }

        _sourceEvents.removeAll()
        
        events.forEach { (event) -> () in
            let shape: EventShape = (event.value.element?.shape != nil) ? (event.value.element?.shape)! : .Another
            let eventView = EventView(recorded: RecordedType(time: event.time, event: event.value), shape: shape, viewController: _parentViewController)
            eventView.center.y = bounds.height / 2
            _sourceEvents.append(eventView)
            addSubview(eventView)
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError()
    }
}

class SceneView: UIView {
    var animator: UIDynamicAnimator?
    var _sourceTimeline: SourceTimelineView!
    var _secondSourceTimeline: SourceTimelineView!
    var _resultTimeline: ResultTimelineView!
    var _trashView: UIImageView?
    
    init() {
        super.init(frame: CGRectZero)
    }
    
    private func showTrashView() {
        if _trashView != nil {
            _trashView?.removeFromSuperview()
            _trashView = nil
        }
        let trashView = UIImageView(image: Image.trash)
        trashView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trashView)
        addConstraint(NSLayoutConstraint(item: trashView, attribute: .CenterX, relatedBy: .Equal, toItem: self, attribute: .CenterX, multiplier: 1.0, constant: 0.0))
        let metrics = ["size" : 60.0]
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:[trash(==size)]", options: NSLayoutFormatOptions(rawValue: 0), metrics: metrics, views: ["trash" : trashView]))
        addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:[trash(==size)]-|", options: NSLayoutFormatOptions(rawValue: 0), metrics: metrics, views: ["trash" : trashView]))
        _trashView = trashView
        
        _trashView!.transform = CGAffineTransformMakeScale(0.1, 0.1)
        _trashView?.alpha = 0.05
        UIView.animateWithDuration(0.3) { _ in
            trashView.alpha = 0.2
            self._trashView!.transform = CGAffineTransformMakeScale(1.5, 1.5)
            self._trashView!.transform = CGAffineTransformMakeScale(1.0, 1.0)
        }
    }
    
    private func hideTrashView() {
        if _trashView == nil {
            return
        }
        _trashView?.hideWithCompletion({ _ in
            self._trashView?.removeFromSuperview()
            self._trashView = nil
        })
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ViewController: UIViewController, UISplitViewControllerDelegate {
    var currentOperator = Operator.Delay
    private var _sceneView: SceneView!
    private var _isEditing: Bool = false {
        didSet {
            isEnableEditing(_isEditing)
        }
    }
    
    private func isEnableEditing(isEdit: Bool) {
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: isEdit ? .Done : .Edit, target: self, action: "enableEditing")
        navigationItem.setHidesBackButton(isEdit, animated: true)
        UIView.animateWithDuration(0.3) { _ in
            self._sceneView._resultTimeline.alpha = isEdit ? 0.5 : 1.0
        }
        if let sourceTimeline = _sceneView._sourceTimeline {
            sourceTimelineEditActions(sourceTimeline, isEdit: isEdit)
        }
        if currentOperator.multiTimelines {
            if let secondSourceTimeline = _sceneView._secondSourceTimeline {
                sourceTimelineEditActions(secondSourceTimeline, isEdit: isEdit)
            }
        }
    }
    
    private func sourceTimelineEditActions(sourceTimeline: SourceTimelineView, isEdit: Bool) {
        if isEdit {
            sourceTimeline.addTapRecognizers()
            sourceTimeline.showAddButton()
            sourceTimeline._addButton!.addTarget(self, action: "addElementToTimeline:", forControlEvents: .TouchUpInside)
        } else {
            sourceTimeline.removeTapRecognizers()
            sourceTimeline.hideAddButton()
        }
        sourceTimeline.allEventViewsAnimation()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = currentOperator.description
        view.backgroundColor = .whiteColor()
        navigationItem.leftItemsSupplementBackButton = true
        navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem()
        setupSceneView()
        _isEditing = false
    }
    
    func setupSceneView() {
        if _sceneView != nil {
            _sceneView.removeFromSuperview()
        }
        let orientation = UIApplication.sharedApplication().statusBarOrientation
        _sceneView = SceneView()
        view.addSubview(_sceneView)
        _sceneView.frame = view.frame
        _sceneView.translatesAutoresizingMaskIntoConstraints = false
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|[sceneView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["sceneView" : _sceneView]))
        view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|[sceneView]|", options: NSLayoutFormatOptions(rawValue: 0), metrics: nil, views: ["sceneView" : _sceneView]))
        
        _sceneView.animator = UIDynamicAnimator(referenceView: _sceneView)
        
        let width = _sceneView.frame.width - 20
        
        let resultTimeline = ResultTimelineView(frame: CGRectMake(10, 0, width, 40), currentOperator: currentOperator)
        resultTimeline.center.y = 200
        _sceneView.addSubview(resultTimeline)
        _sceneView._resultTimeline = resultTimeline
        
        let sourceTimeLine = SourceTimelineView(frame: CGRectMake(10, 0, width, 40), resultTimeline: resultTimeline)
        sourceTimeLine._parentViewController = self
        sourceTimeLine._sceneView = _sceneView
        sourceTimeLine.center.y = 120
        _sceneView.addSubview(sourceTimeLine)
        _sceneView._sourceTimeline = sourceTimeLine
        
        for t in 1..<4 {
            let time = orientation.isPortrait ? t * 40 : Int(CGFloat(t) * 40.0 * scaleKoefficient())
            let event = Event.Next(ColoredType(value: String(randomNumber()), color: RXMUIKit.randomColor(), shape: .Circle))
            sourceTimeLine.addNextEventToTimeline(time, event: event, animator: _sceneView.animator, isEditing: _isEditing)
        }
        let completedTime = orientation.isPortrait ? 150 : Int(150.0 * scaleKoefficient())
        sourceTimeLine.addCompletedEventToTimeline(completedTime, animator: _sceneView.animator, isEditing: _isEditing)
        
        if currentOperator.multiTimelines {
            resultTimeline.center.y = 280
            let secondSourceTimeline = SourceTimelineView(frame: CGRectMake(10, 0, width, 40), resultTimeline: resultTimeline)
            secondSourceTimeline._parentViewController = self
            secondSourceTimeline._sceneView = _sceneView
            secondSourceTimeline.center.y = 200
            _sceneView.addSubview(secondSourceTimeline)
            _sceneView._secondSourceTimeline = secondSourceTimeline
            
            for t in 1..<3 {
                let time = orientation.isPortrait ? t * 40 : Int(CGFloat(t) * 40.0 * scaleKoefficient())
                let event = Event.Next(ColoredType(value: String(randomNumber()), color: RXMUIKit.randomColor(), shape: .RoundedRect))
                secondSourceTimeline.addNextEventToTimeline(time, event: event, animator: _sceneView.animator, isEditing: _isEditing)
            }
            let secondCompletedTime = orientation.isPortrait ? 110 : Int(110.0 * scaleKoefficient())
            secondSourceTimeline.addCompletedEventToTimeline(secondCompletedTime, animator: _sceneView.animator, isEditing: _isEditing)
        }
        
        sourceTimeLine.updateResultTimeline()
    }
    
    func enableEditing() {
        _isEditing = !_isEditing
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        currentOperator.userActivity().becomeCurrent()
    }
    
    func addElementToTimeline(sender: UIButton) {
        if let timeline: SourceTimelineView = sender.superview as? SourceTimelineView {
            var time = Int(timeline.bounds.size.width / 2.0)
            
            let elementSelector = UIAlertController(title: "Add event", message: nil, preferredStyle: .ActionSheet)
            
            let nextAction = UIAlertAction(title: "Next", style: .Default) { (action) -> Void in
                let shape: EventShape = (timeline == self._sceneView._sourceTimeline) ? .Circle : .RoundedRect
                let event = Event.Next(ColoredType(value: String(self.randomNumber()), color: RXMUIKit.randomColor(), shape: shape))
                timeline.addNextEventToTimeline(time, event: event, animator: self._sceneView.animator, isEditing: self._isEditing)
                timeline.updateResultTimeline()
            }
            let completedAction = UIAlertAction(title: "Completed", style: .Default) { (action) -> Void in
                if let t = timeline.maxNextTime() {
                    time = t + 20
                } else {
                    time = Int(self._sceneView._sourceTimeline.bounds.size.width - 60.0)
                }
                timeline.addCompletedEventToTimeline(time, animator: self._sceneView.animator, isEditing: self._isEditing)
                timeline.updateResultTimeline()
            }
            let errorAction = UIAlertAction(title: "Error", style: .Default) { (action) -> Void in
                timeline.addErrorEventToTimeline(time, animator: self._sceneView.animator, isEditing: self._isEditing)
                timeline.updateResultTimeline()
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel) { (action) -> Void in }
            
            elementSelector.addAction(nextAction)
            let sourceEvents: [EventView] = timeline._sourceEvents
            if sourceEvents.indexOf({ $0.isCompleted == true }) == nil {
                elementSelector.addAction(completedAction)
            }
            elementSelector.addAction(errorAction)
            elementSelector.addAction(cancelAction)
            elementSelector.popoverPresentationController?.sourceRect = sender.frame
            elementSelector.popoverPresentationController?.sourceView = sender.superview
            presentViewController(elementSelector, animated: true) { () -> Void in }
        }
    }
    
    private func randomNumber() -> Int {
        return Int(arc4random_uniform(10) + 1)
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        coordinator.animateAlongsideTransition({ (context) -> Void in
                self._sceneView._resultTimeline._sourceEvents.forEach({ (eventView) -> () in
                    eventView.removeFromSuperview()
                })
            }) { (context) -> Void in
                self.scaleTimesOnChangeOrientation(self._sceneView._sourceTimeline)
                if self.currentOperator.multiTimelines {
                    self.scaleTimesOnChangeOrientation(self._sceneView._secondSourceTimeline)
                }
        }
    }
    
    private func scaleTimesOnChangeOrientation(timeline: SourceTimelineView) {
        let scaleKoef = scaleKoefficient()
        var sourceEvents = timeline._sourceEvents
        timeline._sourceEvents.forEach({ eventView in
            eventView.removeFromSuperview()
        })
        timeline._sourceEvents.removeAll()
        sourceEvents.forEach({ eventView in
            let time = Int(CGFloat(eventView._recorded.time) * scaleKoef)
            if eventView.isNext {
                timeline.addNextEventToTimeline(time, event: eventView._recorded.value, animator: _sceneView.animator, isEditing: _isEditing)
            } else if eventView.isCompleted {
                timeline.addCompletedEventToTimeline(time, animator: _sceneView.animator, isEditing: _isEditing)
            } else {
                timeline.addErrorEventToTimeline(time, animator: _sceneView.animator, isEditing: _isEditing)
            }
        })
        sourceEvents.removeAll()
        timeline.allEventViewsAnimation()
        timeline.updateResultTimeline()
    }
    
    private func scaleKoefficient() -> CGFloat {
        let width = view.frame.width
        let height = view.frame.height
        return width / height
    }

}