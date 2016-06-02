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
    weak var component: Component? {
        didSet {
            if let component = component {
                if !component.pins.contains(self) {
                    component.pins.insert(self)
                }
            }
        }
    }
    
    var node: Node?

    var orientation: PinOrientation             { didSet { placeAttributes() }}
    var hasBubble: Bool = false
    var hasClockFlag: Bool = false
    var netName: String? {
        get { return attributes["net"] }
        set {
            if let newValue = newValue where newValue != "" {
                attributes["net"] = newValue
            } else {
                attributes["net"] = nil
            }
        }
    }
    
    var pinName: String {
        get { return attributes["pinName"] ?? "" }
        set { attributes["pinName"] = newValue }
    }
        
    var pinNumber: String {
        get {return attributes["pinNumber"] ?? "" }
        set { attributes["pinNumber"] = newValue }
    }
    
    weak var pinNameText: AttributeText?        { return attributeTextsForAttribute("pinName").first }
    weak var pinNumberText: AttributeText?      { return attributeTextsForAttribute("pinNumber").first }
    
    override var origin: CGPoint                { didSet { placeAttributes() }}
    override var description: String            { return "Pin(\(pinName):\(pinNumber))" }
    
    var pinLength = GridSize * 1
    
    override var bounds: CGRect {
        return graphicBounds + super.bounds
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
    
    override var graphicBounds: CGRect { return rectContainingPoints([origin, endPoint]).insetBy(dx: -2, dy: -2) }
    override var centerPoint: CGPoint { return origin }
    
    override var inspectionName: String     { return "Pin" }

    init(origin: CGPoint, component: Component?, name: String, number: String, orientation: PinOrientation) {
        self.component = component
        self.orientation = orientation
        super.init(origin: origin)
        
        let pinNameText = AttributeText(origin: CGPoint(), format: "=pinName", angle: 0, owner: nil)
        let pinNumberText = AttributeText(origin: CGPoint(), format: "=pinNumber", angle: 0, owner: nil)
        pinNameText.color = NSColor.blueColor()
        pinNumberText.color = NSColor.redColor()
        attributeTexts.insert(pinNameText)
        attributeTexts.insert(pinNumberText)
        
        attributes = [
            "pinName": name,
            "pinNumber": number
        ]
        
        placeAttributes()
}
    
    required init?(coder decoder: NSCoder) {
        self.component = decoder.decodeObjectForKey("component") as? Component
        orientation = PinOrientation(rawValue: decoder.decodeIntegerForKey("orientation")) ?? .Right
        hasBubble = decoder.decodeBoolForKey("bubble")
        hasClockFlag = decoder.decodeBoolForKey("clock")
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    convenience init(copy pin: Pin) {
        self.init(origin: pin.origin, component: nil, name: pin.pinName, number: pin.pinNumber, orientation: pin.orientation)
        hasBubble = pin.hasBubble
        hasClockFlag = pin.hasClockFlag
        attributeTexts = Set(pin.attributeTexts.map { AttributeText(copy: $0) })
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(component, forKey: "component")
        coder.encodeInteger(orientation.rawValue, forKey: "orientation")
        coder.encodeBool(hasBubble, forKey: "bubble")
        coder.encodeBool(hasClockFlag, forKey: "clock")
        super.encodeWithCoder(coder)
    }
    
    func placeAttributes() {
        let nameSize = pinNameText?.size ?? CGSize()
        let numberSize = pinNumberText?.size ?? CGSize()
        
        switch orientation {
        case .Right:
            pinNameText?.angle = 0
            pinNumberText?.angle = 0
            pinNameText?.origin = CGPoint(x: origin.x - nameSize.width - 2, y: origin.y - nameSize.height / 2)
            pinNumberText?.origin = CGPoint(x: origin.x + 4, y: origin.y + 0.5)
        case .Top:
            pinNameText?.angle = PI / 2
            pinNumberText?.angle = PI / 2
            pinNameText?.origin = CGPoint(x: origin.x + nameSize.width / 2, y: origin.y - nameSize.height - 2)
            pinNumberText?.origin = CGPoint(x: origin.x - 0.5, y: origin.y + 4)
        case .Bottom:
            pinNameText?.angle = PI / 2
            pinNumberText?.angle = PI / 2
            pinNameText?.origin = CGPoint(x: origin.x + nameSize.width / 2, y: origin.y + 2)
            pinNumberText?.origin = CGPoint(x: origin.x - 0.5, y: origin.y - numberSize.height - 2)
        case .Left:
            pinNameText?.angle = 0
            pinNumberText?.angle = 0
            pinNameText?.origin = CGPoint(x: origin.x + 2, y: origin.y - nameSize.height / 2)
            pinNumberText?.origin = CGPoint(x: origin.x - numberSize.width - 4, y: origin.y + 0.5)
        }
    }
    
    override func moveBy(offset: CGPoint) -> CGRect {
        guard offset.x != 0 || offset.y != 0 else { return CGRect() }
        var changed = bounds
        if let node = node {
            node.pin = nil
            node.attachments.forEach { changed = changed + $0.moveBy(offset) }
            node.pin = self
        }
        super.moveBy(offset)
        origin = origin + offset
        return changed + bounds
    }
    
    override func rotateByAngle(angle: CGFloat, center: CGPoint) {
        origin = rotatePoint(origin, angle: angle, center: center)
        let angle = normalizeAngle((endPoint - origin).angle + angle)
        var orient = Int(round(angle / (PI / 2)))
        while orient < 0 { orient += 4 }
        while orient >= 4 { orient -= 4 }
        switch orient {
        case 0: orientation = .Right
        case 1: orientation = .Top
        case 2: orientation = .Left
        case 3: orientation = .Bottom
        default: break
        }
        placeAttributes()
        cachedBounds = nil
    }
    
    override func drawInRect(rect: CGRect) {
        let context = NSGraphicsContext.currentContext()?.CGContext

        NSColor.blackColor().set()
        CGContextSetLineWidth(context, 1)
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
            CGContextMoveToPoint(context, (origin.x + endPoint.x) / 2, (origin.y + endPoint.y) / 2)
        }
        CGContextAddLineToPoint(context, endPoint.x, endPoint.y)
        CGContextStrokePath(context)
        if node == nil {
            CGContextBeginPath(context)
            CGContextAddArc(context, endPoint.x, endPoint.y, 2, 0, 2 * PI, 1)
            CGContextSetLineWidth(context, 0.2)
            NSColor.redColor().set()
            CGContextStrokePath(context)
        }
        super.drawInRect(rect)
    }
}
