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
                drawingView.addObserver(self, forKeyPath: "selection", options: .new, context: nil)
            }
        }
    }
    
    @IBOutlet var pinNameField: NSTextField!
    @IBOutlet var pinNumberField: NSTextField!
    @IBOutlet var bubbleCheckBox: NSButton!
    @IBOutlet var overbarCheckBox: NSButton!
    @IBOutlet var clockCheckBox: NSButton!
    @IBOutlet var orientationButton: NSPopUpButton!
    
    var pin: Pin! = Pin(origin: CGPoint(), component: nil, name: "Pin", number: "1", orientation: .right) {
        didSet {
            loadPinValues()
            bounds = CGRect(x: pin.origin.x - frame.size.width / 4, y: pin.origin.y - frame.size.height / 4, width: frame.size.width / 2, height: frame.size.height / 2)
        }
    }
    
    var pinCopy: Pin {
        let copiedPin = Pin(copy: pin)
        
        pinNameField.stringValue = updateTrailingDigits(pinNameField.stringValue)
        pinNumberField.stringValue = updateTrailingDigits(pinNumberField.stringValue)
        return copiedPin
    }
    
    var trailingNumberRE = RegularExpression(pattern: "([[:digit:]]+)$")
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if drawingView.selection.count == 1 {
            if let pin = drawingView.selection.first as? Pin {
                self.pin = pin
                needsDisplay = true
            }
        } else {
            pin = Pin(origin: CGPoint(), component: nil, name: "PIN", number: "1", orientation: .right)
        }
    }
    
    func loadPinValues() {
        pinNameField.stringValue = pin.pinName
        pinNumberField.stringValue = pin.pinNumber
        bubbleCheckBox.state = pin.hasBubble ? NSControl.StateValue.on : NSControl.StateValue.off
        overbarCheckBox.state = pin.pinNameText?.overbar ?? false ? NSControl.StateValue.on : NSControl.StateValue.off
        clockCheckBox.state = pin.hasClockFlag ? NSControl.StateValue.on : NSControl.StateValue.off
        switch pin.orientation {
        case .right: orientationButton.selectItem(at: 0)
        case .left: orientationButton.selectItem(at: 1)
        case .top: orientationButton.selectItem(at: 2)
        case .bottom: orientationButton.selectItem(at: 3)
        }
    }
    
    override func viewDidMoveToWindow() {
        bounds = CGRect(x: pin.origin.x - frame.size.width / 4, y: pin.origin.y - frame.size.height / 4, width: frame.size.width / 2, height: frame.size.height / 2)
        updatePinAttributes(self)
        needsDisplay = true
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        updatePinAttributes(self)
    }
    
    func updateTrailingDigits(_ string: String) -> String {
        if trailingNumberRE.matchesWithString(string) {
            if let digits = trailingNumberRE.match(1) {
                if let number = Int(digits) {
                    return trailingNumberRE.prefix + "\(number + 1)"
                }
            }
        }
        return string
    }
    
    @IBAction func updatePinAttributes(_ sender: AnyObject) {
        var orientation: PinOrientation = .right
        
        switch orientationButton.indexOfSelectedItem {
        case 0: orientation = .right
        case 1: orientation = .left
        case 2: orientation = .top
        case 3: orientation = .bottom
        default: break
        }
        
        pin?.orientation = orientation
        pin?.pinName = pinNameField.stringValue
        pin?.pinNumber = pinNumberField.stringValue
        pin?.pinNameText?.overbar = overbarCheckBox.state == NSControl.StateValue.on
        pin?.hasBubble = bubbleCheckBox.state == NSControl.StateValue.on
        pin?.hasClockFlag = clockCheckBox.state == NSControl.StateValue.on
        pin?.placeAttributes()
        needsDisplay = true
        drawingView.needsDisplay = true
    }
    
    override func draw(_ dirtyRect: NSRect) {
        let context = NSGraphicsContext.current?.cgContext
        
        NSColor.white.set()
        context?.fill(bounds)
        NSColor.black.set()
        context?.beginPath()
        switch pin.orientation {
        case .right, .left:
            context?.__moveTo(x: pin.origin.x, y: bounds.top)
            context?.__addLineTo(x: pin.origin.x, y: bounds.bottom)
        case .top, .bottom:
            context?.__moveTo(x: bounds.left, y: pin.origin.y)
            context?.__addLineTo(x: bounds.right, y: pin.origin.y)
        }
        context?.strokePath()
        pin?.drawInRect(bounds)
    }
    
    var pinImage: NSImage {
        let image = NSImage(size: pin.bounds.size)
        image.lockFocus()
        let context = NSGraphicsContext.current?.cgContext
        context?.translateBy(x: -pin.bounds.origin.x, y: -pin.bounds.origin.y)
        pin.drawInRect(pin.bounds)
        image.unlockFocus()
        return image
    }
    
    // Pin Dragging
    
    override func mouseDown(with theEvent: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: pin)
        item.setDraggingFrame(pin.bounds, contents: pinImage)
        beginDraggingSession(with: [item], event: theEvent, source: self)
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}
