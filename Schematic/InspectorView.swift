//
//  InspectorView.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class InspectorSelectorView: NSView
{
    @IBOutlet var defaultSelectorButton: InspectorSelectorButton?
    @IBOutlet var horizontalLine: NSView!
    @IBOutlet var inspectorSplitView: NSSplitView!
    
    var inspectorConstraints: [NSLayoutConstraint] = []
    
    var inspector: NSView? {
        willSet {
            removeConstraints(inspectorConstraints)
            inspectorConstraints = []
            inspector?.removeFromSuperview()
        }
        didSet  {
            if let view = inspector {
                view.translatesAutoresizingMaskIntoConstraints = false
                addSubview(view)
                inspectorConstraints = [
                    NSLayoutConstraint(item: self, attribute: .Leading, relatedBy: .Equal, toItem: view, attribute: .Leading, multiplier: 1, constant: 0),
                    NSLayoutConstraint(item: self, attribute: .Trailing, relatedBy: .Equal, toItem: view, attribute: .Trailing, multiplier: 1, constant: 0),
                    NSLayoutConstraint(item: self, attribute: .Bottom, relatedBy: .Equal, toItem: view, attribute: .Bottom, multiplier: 1, constant: 0),
                    NSLayoutConstraint(item: horizontalLine, attribute: .Bottom, relatedBy: .Equal, toItem: view, attribute: .Top, multiplier: 1, constant: -2)
                ]
                addConstraints(inspectorConstraints)
            }
        }
    }
    
    override func awakeFromNib() {
        inspector = defaultSelectorButton?.auxView
    }
    
    override func drawRect(dirtyRect: NSRect) {
        NSEraseRect(dirtyRect)
    }
    
    @IBAction func toggleShowHide(sender: AnyObject) {
        if inspectorSplitView.hidden {
            inspectorSplitView.hidden = false
        } else {
            inspectorSplitView.hidden = true
        }
    }
    
    @IBAction func takeInspectorFrom(button: InspectorSelectorButton) {
        inspector = button.auxView
        for subview in subviews {
            if let b = subview as? InspectorSelectorButton {
                b.state = NSOffState
            }
        }
        button.state = NSOnState
    }
}

class InspectorSelectorButton: NSButton
{
    @IBOutlet var auxView: NSView!
}