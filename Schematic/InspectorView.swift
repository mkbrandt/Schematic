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
                    NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: view, attribute: .leading, multiplier: 1, constant: 0),
                    NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: view, attribute: .trailing, multiplier: 1, constant: 0),
                    NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .bottom, multiplier: 1, constant: 0),
                    NSLayoutConstraint(item: horizontalLine, attribute: .bottom, relatedBy: .equal, toItem: view, attribute: .top, multiplier: 1, constant: -2)
                ]
                addConstraints(inspectorConstraints)
            }
        }
    }
    
    override func awakeFromNib() {
        inspector = defaultSelectorButton?.auxView
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSEraseRect(dirtyRect)
    }
    
    @IBAction func toggleShowHide(_ sender: AnyObject) {
        if inspectorSplitView.isHidden {
            inspectorSplitView.isHidden = false
        } else {
            inspectorSplitView.isHidden = true
        }
    }
    
    @IBAction func takeInspectorFrom(_ button: InspectorSelectorButton) {
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
