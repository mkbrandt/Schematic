//
//  SCHPin.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

enum PinOrientation: Int {
    case Top, Left, Bottom, Right
}

class SCHPin: SCHElement
{
    var hasBubble: Bool = false
    var hasClockFlag: Bool = false
    
    var pinNameAttribute: SCHAttribute {
        get { return attributes["pinName"] ?? SCHAttribute(string: "unnamed") }
        set { attributes["pinName"] = newValue }
    }
    
    var pinNumberAttribute: SCHAttribute {
        get { return attributes["pinNumber"] ?? SCHAttribute(string: "--") }
        set { attributes["pinNumber"] = newValue }
    }
    
    override var description: String { return "Pin(\(pinNameAttribute.string):\(pinNumberAttribute.string)" }
    
    var nameRect: CGRect {
        let rect = pinNameAttribute.bounds.translateBy(origin)
        switch orientation {
        case .Left, .Right:
            return rect
        case .Top, .Bottom:
            return rect.rotatedAroundPoint(origin, angle: PI / 2)
        }
    }
    
    var numberRect: CGRect {
        let rect = pinNumberAttribute.bounds.translateBy(origin)
        switch orientation {
        case .Left, .Right:
            return rect
        case .Top, .Bottom:
            return rect.rotatedAroundPoint(origin, angle: PI / 2)
        }
    }
    
    let pinLength = GridSize * 2
    
    override var bounds: CGRect {
        return nameRect + numberRect + rectContainingPoints([origin, endPoint])
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
    
    var component: SCHComponent?
    var orientation: PinOrientation
    
    init(origin: CGPoint, component: SCHComponent?, name: String, number: String, orientation: PinOrientation) {
        self.component = component
        self.orientation = orientation
        super.init(origin: origin)
        
        pinNameAttribute = SCHAttribute(string: name)
        pinNumberAttribute = SCHAttribute(string: number)
        
        pinNameAttribute.color = NSColor.blueColor()
        pinNumberAttribute.color = NSColor.redColor()
        
        placeAttributes()
}
    
    required init?(coder decoder: NSCoder) {
        if let component = decoder.decodeObjectForKey("component") as? SCHComponent {
            self.component = component
            orientation = PinOrientation(rawValue: decoder.decodeIntegerForKey("orientation")) ?? .Right
        } else {
            return nil
        }
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    convenience init(copy pin: SCHPin) {
        self.init(origin: pin.origin, component: nil, name: pin.pinNameAttribute.string as String, number: pin.pinNumberAttribute.string as String, orientation: pin.orientation)
        pinNameAttribute.overbar = pin.pinNameAttribute.overbar
        pinNameAttribute.origin = pin.pinNameAttribute.origin
        pinNumberAttribute.origin = pin.pinNumberAttribute.origin
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(component, forKey: "component")
        coder.encodeInteger(orientation.rawValue, forKey: "orientation")
        super.encodeWithCoder(coder)
    }
    
    func placeAttributes() {
        let nameSize = pinNameAttribute.size
        let numberSize = pinNumberAttribute.size
        
        switch orientation {
        case .Right, .Top:
            pinNameAttribute.origin = CGPoint(x: -nameSize.width - 2, y: -nameSize.height / 2)
            pinNumberAttribute.origin = CGPoint(x: 4, y: 0.5)
        case .Bottom:
            pinNameAttribute.origin = CGPoint(x: 2, y: -nameSize.height / 2)
            pinNumberAttribute.origin = CGPoint(x: -numberSize.width - 4, y: 0.5)
        case .Left:
            pinNameAttribute.origin = CGPoint(x: 2, y: -nameSize.height / 2)
            pinNumberAttribute.origin = CGPoint(x: -numberSize.width - 4, y: 0.5)
        }
    }
    
    override func elementAtPoint(point: CGPoint) -> SCHGraphic? {
        let pinRect = CGRect(x: endPoint.x - 1, y: endPoint.y - 1, width: 2, height: 2)
        if pinRect.contains(point) {
            return self
        } else if nameRect.contains(point) {
            return pinNameAttribute
        } else if numberRect.contains(point) {
            return pinNumberAttribute
        }
        return nil
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextSaveGState(context)
        
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
        
        CGContextTranslateCTM(context, origin.x, origin.y)  // center origin on pin
        switch orientation {
        case .Left, .Right:
            break
        case .Top, .Bottom:
            CGContextRotateCTM(context, PI / 2)             // rotate labels
        }
        super.draw()                                        // draw labels
        
        CGContextRestoreGState(context)
    }
}
