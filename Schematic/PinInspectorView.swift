//
//  PinInspectorView.swift
//  Schematic
//
//  Created by Matt Brandt on 5/17/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class PinInspectorPreview: NSBox, NSDraggingSource, NSTextFieldDelegate
{
    @IBOutlet var drawingView: SchematicView! {
        willSet {
            if drawingView != nil {
                drawingView.removeObserver(self, forKeyPath: "selection")
            }
        }
        didSet {
            if drawingView != nil {
                drawingView.addObserver(self, forKeyPath: "selection", options: .New, context: nil)
            }
        }
    }
    
    @IBOutlet var pinNameField: NSTextField!
    @IBOutlet var pinNumberField: NSTextField!
    @IBOutlet var bubbleCheckBox: NSButton!
    @IBOutlet var overbarCheckBox: NSButton!
    @IBOutlet var clockCheckBox: NSButton!
    @IBOutlet var orientationButton: NSPopUpButton!
    
    var pin: SCHPin! = SCHPin(origin: CGPoint(), component: nil, name: "Pin", number: "1", orientation: .Right) {
        didSet {
            loadPinValues()
            bounds = CGRect(x: pin.origin.x - frame.size.width / 4, y: pin.origin.y - frame.size.height / 4, width: frame.size.width / 2, height: frame.size.height / 2)
        }
    }
    
    var pinCopy: SCHPin {
        let copiedPin = SCHPin(copy: pin)
        
        pinNameField.stringValue = updateTrailingDigits(pinNameField.stringValue)
        pinNumberField.stringValue = updateTrailingDigits(pinNumberField.stringValue)
        return copiedPin
    }
    
    var trailingNumberRE = RegularExpression(pattern: "([[:digit:]]+)$")
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if drawingView.selection.count == 1 {
            if let pin = drawingView.selection[0] as? SCHPin {
                self.pin = pin
                needsDisplay = true
            }
        } else {
            pin = SCHPin(origin: CGPoint(), component: nil, name: "PIN", number: "1", orientation: .Right)
        }
    }
    
    func loadPinValues() {
        pinNameField.stringValue = pin.pinNameAttribute.string as String
        pinNumberField.stringValue = pin.pinNumberAttribute.string as String
        bubbleCheckBox.state = pin.hasBubble ? NSOnState : NSOffState
        overbarCheckBox.state = pin.pinNameAttribute.overbar ? NSOnState : NSOffState
        clockCheckBox.state = pin.hasClockFlag ? NSOnState : NSOffState
        switch pin.orientation {
        case .Right: orientationButton.selectItemAtIndex(0)
        case .Left: orientationButton.selectItemAtIndex(1)
        case .Top: orientationButton.selectItemAtIndex(2)
        case .Bottom: orientationButton.selectItemAtIndex(3)
        }
    }
    
    override func viewDidMoveToWindow() {
        bounds = CGRect(x: pin.origin.x - frame.size.width / 4, y: pin.origin.y - frame.size.height / 4, width: frame.size.width / 2, height: frame.size.height / 2)
        updatePinAttributes(self)
        needsDisplay = true
    }
    
    override func controlTextDidChange(obj: NSNotification) {
        updatePinAttributes(self)
    }
    
    func updateTrailingDigits(string: String) -> String {
        if trailingNumberRE.matchesWithString(string) {
            if let digits = trailingNumberRE.match(1) {
                if let number = Int(digits) {
                    return trailingNumberRE.prefix + "\(number + 1)"
                }
            }
        }
        return string
    }
    
    @IBAction func updatePinAttributes(sender: AnyObject) {
        var orientation: PinOrientation = .Right
        
        switch orientationButton.indexOfSelectedItem {
        case 0: orientation = .Right
        case 1: orientation = .Left
        case 2: orientation = .Top
        case 3: orientation = .Bottom
        default: break
        }
        
        pin?.orientation = orientation
        pin?.pinNameAttribute.string = pinNameField.stringValue
        pin?.pinNumberAttribute.string = pinNumberField.stringValue
        pin?.pinNameAttribute.overbar = overbarCheckBox.state == NSOnState
        pin?.hasBubble = bubbleCheckBox.state == NSOnState
        pin?.hasClockFlag = clockCheckBox.state == NSOnState
        pin?.placeAttributes()
        needsDisplay = true
        drawingView.needsDisplay = true
    }
    
    override func drawRect(dirtyRect: NSRect) {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        NSColor.whiteColor().set()
        CGContextFillRect(context, bounds)
        NSColor.blackColor().set()
        CGContextBeginPath(context)
        switch pin.orientation {
        case .Right, .Left:
            CGContextMoveToPoint(context, pin.origin.x, bounds.top)
            CGContextAddLineToPoint(context, pin.origin.x, bounds.bottom)
        case .Top, .Bottom:
            CGContextMoveToPoint(context, bounds.left, pin.origin.y)
            CGContextAddLineToPoint(context, bounds.right, pin.origin.y)
        }
        CGContextStrokePath(context)
        pin?.draw()
    }
    
    var pinImage: NSImage {
        let image = NSImage(size: pin.bounds.size)
        image.lockFocus()
        let context = NSGraphicsContext.currentContext()?.CGContext
        CGContextTranslateCTM(context, -pin.bounds.origin.x, -pin.bounds.origin.y)
        pin.draw()
        image.unlockFocus()
        return image
    }
    
    // Pin Dragging
    
    override func mouseDown(theEvent: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: pin)
        item.setDraggingFrame(pin.bounds, contents: pinImage)
        beginDraggingSessionWithItems([item], event: theEvent, source: self)
    }
    
    func draggingSession(session: NSDraggingSession, sourceOperationMaskForDraggingContext context: NSDraggingContext) -> NSDragOperation {
        return .Copy
    }
}
