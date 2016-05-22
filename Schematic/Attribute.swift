//
//  AttributeText.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let AttributeFont = NSFont.systemFontOfSize(GridSize - 3)

class AttributeText: Graphic
{
    var owner: AttributedGraphic?
    var format: String
    var angle: CGFloat
    var overbar: Bool = false
    
    override var description: String { return "Attribute(\(format))" }
    
    var textAttributes: [String: AnyObject] {
        return [NSForegroundColorAttributeName: color, NSFontAttributeName: AttributeFont]
    }
    
    override var inspectables: [Inspectable] {
        get {
            return super.inspectables + [
                Inspectable(name: "color", type: .Color),
                Inspectable(name: "overbar", type: .Bool)
            ]
        }
        set {}
    }
    
    override var inspectionName: String     { return "Attribute" }
    
    var string: NSString {
        if let owner = owner {
            return owner.attributeValue(format)
        }
        return format
    }

    var textSize: CGSize            { return string.sizeWithAttributes(textAttributes) }
    override var bounds: CGRect     { return CGRect(origin: origin, size: textSize).rotatedAroundPoint(origin, angle: angle) }
    var size: CGSize                { return bounds.size }
    
    init(origin: CGPoint, format: String, angle: CGFloat = 0, owner: AttributedGraphic?) {
        self.format = format
        self.angle = angle
        self.owner = owner
        super.init(origin: origin)
    }
    
    convenience init(string: String) {
        self.init(origin: CGPoint(x: 0, y: 0), format: string, owner: nil)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        return nil
    }
    
    required init?(coder decoder: NSCoder) {
        format = decoder.decodeObjectForKey("format") as? String ?? ""
        angle = decoder.decodeCGFloatForKey("angle")
        owner = decoder.decodeObjectForKey("owner") as? AttributedGraphic
        super.init(coder: decoder)
    }
    
    convenience init(copy attr: AttributeText) {
        self.init(origin: attr.origin, format: attr.format as String, angle: attr.angle, owner: attr.owner)
        overbar = attr.overbar
        color = attr.color
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(string, forKey: "format")
        coder.encodeCGFloat(angle, forKey: "angle")
        coder.encodeObject(owner, forKey: "owner")
        super.encodeWithCoder(coder)
    }
    
    override func showHandlesInView(view: SchematicView) {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextSaveGState(context)
        CGContextSetLineWidth(context, 0.1)
        NSColor.redColor().set()
        CGContextStrokeRect(context, bounds)
        if let owner = owner {
            let center = bounds.center
            let cp = owner.closestPointToPoint(center)
            CGContextBeginPath(context)
            CGContextMoveToPoint(context, center.x, center.y)
            CGContextAddLineToPoint(context, cp.x, cp.y)
            CGContextStrokePath(context)
        }
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        let size = string.sizeWithAttributes(textAttributes)
        
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

