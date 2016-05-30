//
//  PrimitiveGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/25/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class PrimitiveGraphic: Graphic
{
    var color: NSColor = NSColor.blackColor()
    var lineWeight: CGFloat = 1.0

    override var inspectables: [Inspectable] {
        return [
            Inspectable(name: "color", type: .Color),
            Inspectable(name: "lineWeight", type: .Float)
        ]
    }

    override init(origin: CGPoint) {
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        color = decoder.decodeObjectForKey("color") as? NSColor ?? NSColor.blackColor()
        lineWeight = decoder.decodeCGFloatForKey("lineWeight")
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(color, forKey: "color")
        coder.encodeCGFloat(lineWeight, forKey: "lineWeight")
        super.encodeWithCoder(coder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("fuck me")
    }

    override func drawInRect(rect: CGRect) {
        if intersectsRect(rect) {
            let context = NSGraphicsContext.currentContext()?.CGContext
            
            CGContextSaveGState(context)
            CGContextSetLineWidth(context, lineWeight)
            color.set()
            draw()
            if selected {
                showHandles()
            }
            CGContextRestoreGState(context)
       }
    }
}
