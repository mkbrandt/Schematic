//
//  Pin.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

enum PinOrientation: Int {
    case Top, Left, Bottom, Right
}

class Pin: AttributedGraphic
{
    var component: Component?
    var orientation: PinOrientation     { didSet { placeAttributes() }}
    var hasBubble: Bool = false
    var hasClockFlag: Bool = false
    var namesNet: Bool = false
    var pinName: String
    var pinNumber: String
    
    var pinNameText: AttributeText
    var pinNumberText: AttributeText
    
    override var attributes: [AttributeText] {
        get { return [pinNameText, pinNumberText] }
        set {}
    }
    
    override var origin: CGPoint        { didSet { placeAttributes() }}
    override var description: String    { return "Pin(\(pinName):\(pinNumber)" }
    
    let pinLength = GridSize * 2
    
    override var bounds: CGRect {
        return rectContainingPoints([origin, endPoint]) + pinNameText.bounds + pinNumberText.bounds
    }
    
    var endPoint: CGPoint {
        switch orientation {
        case .Left:
            return origin - CGPoint(x: pinLength, y: 0)
        case .Right:
            return origin + CGPoint(x: pinLength, y: 0)
        case .Bottom:
            return origin - CGPoint(x: 0, y: pinLength)
        case .Top:
            return origin + CGPoint(x: 0, y: pinLength)
        }
    }
    
    override var inspectionName: String     { return "Pin" }

    init(origin: CGPoint, component: Component?, name: String, number: String, orientation: PinOrientation) {
        self.component = component
        self.orientation = orientation
        self.pinName = name
        self.pinNumber = number
        pinNameText = AttributeText(origin: CGPoint(), format: "=name", angle: 0, owner: nil)
        pinNumberText = AttributeText(origin: CGPoint(), format: "=number", angle: 0, owner: nil)
        super.init(origin: origin)
        
        pinNameText.owner = self
        pinNumberText.owner = self
        pinNameText.color = NSColor.blueColor()
        pinNumberText.color = NSColor.redColor()
        
        placeAttributes()
}
    
    required init?(coder decoder: NSCoder) {
        if let component = decoder.decodeObjectForKey("component") as? Component,
        let pinNameText = decoder.decodeObjectForKey("pinNameText") as? AttributeText,
        let pinNumberText = decoder.decodeObjectForKey("pinNumberText") as? AttributeText {
            self.component = component
            orientation = PinOrientation(rawValue: decoder.decodeIntegerForKey("orientation")) ?? .Right
            hasBubble = decoder.decodeBoolForKey("bubble")
            hasClockFlag = decoder.decodeBoolForKey("clock")
            namesNet = decoder.decodeBoolForKey("namesNet")
            pinName = decoder.decodeObjectForKey("pinName") as? String ?? "PIN"
            pinNumber = decoder.decodeObjectForKey("pinNumber") as? String ?? "0"
            self.pinNameText = pinNameText
            self.pinNumberText = pinNumberText
        } else {
            return nil
        }
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    convenience init(copy pin: Pin) {
        self.init(origin: pin.origin, component: nil, name: pin.pinName, number: pin.pinNumber, orientation: pin.orientation)
        hasBubble = pin.hasBubble
        hasClockFlag = pin.hasClockFlag
        namesNet = pin.namesNet
        pinNameText = AttributeText(copy: pin.pinNameText)
        pinNumberText = AttributeText(copy: pin.pinNumberText)
        pinNameText.owner = self
        pinNumberText.owner = self
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(component, forKey: "component")
        coder.encodeInteger(orientation.rawValue, forKey: "orientation")
        coder.encodeBool(hasBubble, forKey: "bubble")
        coder.encodeBool(hasClockFlag, forKey: "clock")
        coder.encodeBool(namesNet, forKey: "namesNet")
        coder.encodeObject(pinName, forKey: "pinName")
        coder.encodeObject(pinNumber, forKey: "pinNumber")
        coder.encodeObject(pinNameText, forKey: "pinNameText")
        coder.encodeObject(pinNumberText, forKey: "pinNumberText")
        super.encodeWithCoder(coder)
    }
    
    override func attributeValue(format: String) -> String {
        switch format {
        case "=name": return pinName
        case "=number": return pinNumber
        default: return format
        }
    }
    
    func placeAttributes() {
        let nameSize = pinNameText.size
        let numberSize = pinNumberText.size
        
        switch orientation {
        case .Right:
            pinNameText.angle = 0
            pinNumberText.angle = 0
            pinNameText.origin = CGPoint(x: origin.x - nameSize.width - 2, y: origin.y - nameSize.height / 2)
            pinNumberText.origin = CGPoint(x: origin.x + 4, y: origin.y + 0.5)
        case .Top:
            pinNameText.angle = PI / 2
            pinNumberText.angle = PI / 2
            pinNameText.origin = CGPoint(x: origin.x + nameSize.width / 2, y: origin.y - nameSize.height - 2)
            pinNumberText.origin = CGPoint(x: origin.x - 0.5, y: origin.y + 4)
        case .Bottom:
            pinNameText.angle = PI / 2
            pinNumberText.angle = PI / 2
            pinNameText.origin = CGPoint(x: origin.x + nameSize.width / 2, y: origin.y + 2)
            pinNumberText.origin = CGPoint(x: origin.x - 0.5, y: origin.y - numberSize.height - 2)
        case .Left:
            pinNameText.angle = 0
            pinNumberText.angle = 0
            pinNameText.origin = CGPoint(x: origin.x + 2, y: origin.y - nameSize.height / 2)
            pinNumberText.origin = CGPoint(x: origin.x - numberSize.width - 4, y: origin.y + 0.5)
        }
    }
    
    override func elementAtPoint(point: CGPoint) -> Graphic? {
        if pinNameText.bounds.contains(point) {
            return pinNameText
        } else if pinNumberText.bounds.contains(point) {
            return pinNumberText
        }
        return self
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext

        CGContextBeginPath(context)
        CGContextMoveToPoint(context, origin.x, origin.y)
        if hasBubble {
            let bsize = GridSize / 2
            var bubbleRect: CGRect
            switch orientation {
            case .Right:    bubbleRect = CGRect(x: origin.x, y: origin.y - bsize / 2, width: bsize, height: bsize)
            case .Left:     bubbleRect = CGRect(x: origin.x - bsize, y: origin.y - bsize / 2, width: bsize, height: bsize)
            case .Top:      bubbleRect = CGRect(x: origin.x - bsize / 2, y: origin.y, width: bsize, height: bsize)
            case .Bottom:   bubbleRect = CGRect(x: origin.x - bsize / 2, y: origin.y - bsize, width: bsize, height: bsize)
            }
            CGContextStrokeEllipseInRect(context, bubbleRect)
            CGContextMoveToPoint(context, (3 * origin.x + endPoint.x) / 4, (3 * origin.y + endPoint.y) / 4)
        }
        CGContextAddLineToPoint(context, endPoint.x, endPoint.y)
        CGContextStrokePath(context)
        super.draw()
    }
}
