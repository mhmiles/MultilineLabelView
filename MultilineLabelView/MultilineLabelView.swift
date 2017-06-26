//
//  MultilineLabelView.swift
//  Master Control
//
//  Created by Miles Hollingsworth on 9/11/16.
//  Copyright © 2016 Miles Hollingsworth. All rights reserved.
//

import UIKit
import ReactiveSwift
import NotificationCenter
import enum Result.NoError

public class MultilineLabelView: UIView {
  fileprivate var stackView = UIStackView() {
    didSet {
      stackView.axis = .vertical
      stackView.alignment = .fill
      stackView.translatesAutoresizingMaskIntoConstraints = false
      
      addSubview(stackView)
      stackView.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
      stackView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
      
      UIView.animate(withDuration: 0.3, animations: {
        oldValue.alpha = 0.0
      }, completion: { (success) in
        oldValue.removeFromSuperview()
      })
    }
  }
  
  fileprivate var labelCenterConstraints: [NSLayoutConstraint]?
  
  public var dataSource = MutableProperty<MultilaneLabelViewDataSource?>(nil)
  
  override init(frame: CGRect) {
    super.init(frame: frame)
    
    configureLabels()
  }
  
  public required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
    
    configureLabels()
  }
  
  fileprivate var deallocDisposable: ScopedDisposable<AnyDisposable>?
  
  private func configureLabels() {
    _ = dataSource.producer.flatMap(.latest, { dataSource -> SignalProducer<[NSAttributedString], NoError> in
      return dataSource?.stringsProducer ?? SignalProducer(value: [NSAttributedString]())
    }).skipRepeats({ current, previous in
      let extractString: (NSAttributedString) -> String = {
        $0.string
      }
      
      return current.map(extractString).elementsEqual(previous.map(extractString))
    }).map({ strings -> [UILabel] in
      strings.map { string in
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        
        label.attributedText = string
        
        return label
      }
    }).startWithValues(configureNewStackView)
    
    let disposable = NotificationCenter.default.reactive.notifications(forName: Notification.Name.UIApplicationWillEnterForeground).observeValues { _ in
      self.animationDisposable.inner = self.animationProducer?.start()
    }
    
    if let disposable = disposable {
      deallocDisposable = ScopedDisposable(disposable)
    }
  }
  
  private var animationProducer: SignalProducer<(), NoError>?
  private let animationDisposable = SerialDisposable()
  
  private func configureNewStackView(labels: [UILabel]) {
    self.stackView = UIStackView()
    
    let stackCenterXConstraint = stackView.centerXAnchor.constraint(equalTo: centerXAnchor, constant: frame.width)
    addConstraint(stackCenterXConstraint)
    
    if labels.count == 0 {
      return
    }
    
    let viewsTuples = labels.map { ($0, UIView()) }
    let animationSpeed = CGFloat(40)
    
    let animationProducers = viewsTuples.flatMap { viewTuple -> SignalProducer<(), NoError>? in
      let (label, view) = viewTuple
      view.isOpaque = false
      view.translatesAutoresizingMaskIntoConstraints = false
      
      view.addSubview(label)
      
      view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|[label]|",
                                                         options: [],
                                                         metrics: nil,
                                                         views: ["label": label]))
      
      if let attributedStringWidth = label.attributedText?.size().width , attributedStringWidth > bounds.width {
        let leadingConstraint = label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10)
        leadingConstraint.isActive = true
        
        let labelCopy = UILabel()
        labelCopy.translatesAutoresizingMaskIntoConstraints = false
        labelCopy.attributedText = label.attributedText
        
        view.addSubview(labelCopy)
        
        label.bottomAnchor.constraint(equalTo: labelCopy.bottomAnchor).isActive = true
        labelCopy.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 30).isActive = true
        
        return SignalProducer<(), NoError> { observer, disposable in
          leadingConstraint.constant = 10
          view.layoutIfNeeded()
          
          UIView.animate(withDuration: TimeInterval(attributedStringWidth/animationSpeed),
                         delay: 3,
                         options: [.curveLinear],
                         animations: {
                          leadingConstraint.constant = 10-(attributedStringWidth+30)
                          view.layoutIfNeeded()
          }, completion: { success in
            observer.sendCompleted()
          })
          
          let animationDisposable = AnyDisposable(view.layer.removeAllAnimations)
          disposable.observeEnded(animationDisposable.dispose)
        }
      } else {
        view.centerXAnchor.constraint(equalTo: label.centerXAnchor).isActive = true
        return nil
      }
    }
    
    viewsTuples.map({ $0.1 }).forEach(stackView.addArrangedSubview)
    
    layoutIfNeeded()
    
    if animationProducers.count > 0 {
      animationProducer = SignalProducer<SignalProducer<(), NoError>, NoError>(animationProducers).flatMap(.merge, {
        $0
      }).repeat(Int.max)
    }
    
    UIView.animate(withDuration: 1.0, delay: 0.0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0.0, options: [], animations: {
      stackCenterXConstraint.constant = 0.0
      self.layoutIfNeeded()
    }) { (success: Bool) -> Void in
      if success {
        self.animationDisposable.inner = self.animationProducer?.start()
      }
      
    }
  }
}

public typealias MultilineLabelStringsProducer = SignalProducer<[NSAttributedString], NoError>

public protocol MultilaneLabelViewDataSource {
  var stringsProducer: MultilineLabelStringsProducer { get }
}
