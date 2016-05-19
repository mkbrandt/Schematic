//
//  SCHAttribute.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let AttributeFont = NSFont.systemFontOfSize(GridSize - 3)

class SCHAttribute: SCHGraphic
{
    var string: NSString
    var overbar: Bool = false
    
    override var description: String { return "Attribute(\(string))" }
    
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
    
    var size: CGSize                { return string.sizeWithAttributes(textAttributes) }
    override var bounds: CGRect     { return CGRect(origin: origin, size: size) }
    
    init(origin: CGPoint, string: String) {
        self.string = string
        super.init(origin: origin)
    }
    
    convenience init(string: String) {
        self.init(origin: CGPoint(x: 0, y: 0), string: string)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        return nil
    }
    
    required init?(coder decoder: NSCoder) {
        string = decoder.decodeObjectForKey("string") as? NSString ?? ""
        super.init(coder: decoder)
    }
    
    convenience init(copy attr: SCHAttribute) {
        self.init(origin: attr.origin, string: attr.string as String)
        overbar = attr.overbar
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(string, forKey: "string")
        super.encodeWithCoder(coder)
    }
    
    override func draw() {
        string.drawAtPoint(origin, withAttributes: textAttributes)
        if overbar {
            let context = NSGraphicsContext.currentContext()?.CGContext
            
            CGContextBeginPath(context)
            CGContextSetLineWidth(context, 1.0)
            CGContextMoveToPoint(context, bounds.topLeft.x, bounds.topLeft.y)
            CGContextAddLineToPoint(context, bounds.topRight.x, bounds.topRight.y)
            CGContextStrokePath(context)
        }
    }
}

