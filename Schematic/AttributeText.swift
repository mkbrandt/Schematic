//
//  AttributeText.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let AttributeFont = NSFont.systemFontOfSize(GridSize - 3)

class AttributeText: PrimitiveGraphic
{
    var owner: AttributedGraphic?
    var format: String
    var angle: CGFloat
    var overbar: Bool = false
    
    override var selected: Bool {
        didSet {
            invalidateDrawing()
        }
    }
    
    override var description: String { return "Attribute(\(format))" }
    
    var textAttributes: [String: AnyObject] {
        return [NSForegroundColorAttributeName: color, NSFontAttributeName: AttributeFont]
    }
    
    override var inspectables: [Inspectable] {
        get {
            return [
                Inspectable(name: "color", type: .Color),
                Inspectable(name: "format", type: .String),
                Inspectable(name: "string", type: .String, displayName: "value"),
                Inspectable(name: "angle", type: .Angle),
                Inspectable(name: "overbar", type: .Bool)
            ]
        }
        set {}
    }
    
    override var inspectionName: String     { return "AttributeText" }
    
    var string: NSString {
        get {
            if let owner = owner {
                return owner.attributeValue(format)
            }
            return format
        }
        set {
            if format.hasPrefix("=") {
                if let name = owner?.stripPrefix(format) {
                    owner?.setAttribute(newValue as String, name: name)
                }
            }
        }
    }

    var textSize: CGSize            { return string.sizeWithAttributes(textAttributes) }
    override var bounds: CGRect     { return CGRect(origin: origin, size: textSize).rotatedAroundPoint(origin, angle: angle) }
    var size: CGSize                { return bounds.size }

    override var centerPoint: CGPoint { return bounds.center }
    
    init(origin: CGPoint, format: String, angle: CGFloat = 0, owner: AttributedGraphic?) {
        self.format = format
        self.angle = angle
        self.owner = owner
        super.init(origin: origin)
    }
    
    convenience init(format: String) {
        self.init(origin: CGPoint(x: 0, y: 0), format: format, owner: nil)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        return nil
    }
    
    required init?(coder decoder: NSCoder) {
        format = decoder.decodeObjectForKey("format") as? String ?? ""
        angle = decoder.decodeCGFloatForKey("angle")
        owner = decoder.decodeObjectForKey("owner") as? AttributedGraphic
        overbar = decoder.decodeBoolForKey("overbar")
        super.init(coder: decoder)
    }
    
    convenience init(copy attr: AttributeText) {
        self.init(origin: attr.origin, format: attr.format as String, angle: attr.angle, owner: attr.owner)
        overbar = attr.overbar
        color = attr.color
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(format, forKey: "format")
        coder.encodeCGFloat(angle, forKey: "angle")
        coder.encodeObject(owner, forKey: "owner")
        coder.encodeBool(overbar, forKey: "overbar")
        super.encodeWithCoder(coder)
    }
    
    override func closestPointToPoint(point: CGPoint) -> CGPoint {
        if bounds.contains(point) {
            return point
        }
        return origin
    }
    
    override func hitTest(point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if bounds.contains(point) {
            return .HitsOn(self)
        }
        return nil
    }
    
    var distanceFromOwner: CGFloat = 0

    func invalidateDrawing() {
        if let comp = owner as? Component {
            let dist = comp.origin.distanceToPoint(origin)
            if dist != distanceFromOwner {
                comp.cachedImage = nil
                distanceFromOwner = dist
            }
        }
    }
    
    override func moveBy(offset: CGPoint) {
        super.moveBy(offset)
        invalidateDrawing()
    }
    
    override func rotateByAngle(angle: CGFloat, center: CGPoint) {
        self.angle += angle
        if self.angle > PI { self.angle -= 2 * PI }
        if self.angle < -PI { self.angle += 2 * PI }
        origin = rotatePoint(origin, angle: angle, center: center)
    }
    
    override func showHandles() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextSaveGState(context)
        CGContextSetLineWidth(context, 0.1)
        NSColor.redColor().set()
        CGContextStrokeRect(context, bounds)
        if let owner = owner {
            let center = bounds.center
            let cp = owner.graphicBounds.center
            CGContextBeginPath(context)
            CGContextMoveToPoint(context, center.x, center.y)
            CGContextAddLineToPoint(context, cp.x, cp.y)
            CGContextStrokePath(context)
        }
        CGContextRestoreGState(context)
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        let size = string.sizeWithAttributes(textAttributes)
        if angle == 0 {                                                     // this really didn't seem to do much...
            string.drawAtPoint(origin, withAttributes: textAttributes)
            if overbar {
                let l = bounds.topLeft
                let r = bounds.topRight
                CGContextBeginPath(context)
                CGContextMoveToPoint(context, l.x, l.y)
                CGContextAddLineToPoint(context, r.x, r.y)
                CGContextStrokePath(context)
            }
        } else {
            CGContextSaveGState(context)
            CGContextTranslateCTM(context, origin.x, origin.y)
            CGContextRotateCTM(context, angle)

            string.drawAtPoint(CGPoint(), withAttributes: textAttributes)
            
            if overbar {
                
                CGContextBeginPath(context)
                CGContextSetLineWidth(context, 1.0)
                CGContextMoveToPoint(context, 0, size.height)
                CGContextAddLineToPoint(context, size.width, size.height)
                CGContextStrokePath(context)
            }
            CGContextRestoreGState(context)
        }
    }
}

