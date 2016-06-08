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
    
    override init(json: JSON) {
        let color = json["color"]
        let r = CGFloat(color["r"].doubleValue)
        let g = CGFloat(color["g"].doubleValue)
        let b = CGFloat(color["b"].doubleValue)
        self.color = NSColor(red: r, green: g, blue: b, alpha: 1)
        lineWeight = CGFloat(json["lineweight"].doubleValue)
        super.init(json: json)
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
    
    override var json: JSON {
        var json = super.json
        let color = self.color.colorUsingColorSpace(NSColorSpace.deviceRGBColorSpace())!
        json["color"] = JSON(["r": color.redComponent, "g": color.greenComponent, "b": color.blueComponent])
        json["lineWeight"] = JSON(lineWeight)
        return json
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("fuck me")
    }

    override func drawInRect(rect: CGRect) {
        if intersectsRect(rect) {
            let context = NSGraphicsContext.currentContext()?.CGContext
            
            CGContextSaveGState(context)
            CGContextSetLineWidth(context, lineWeight)
            setDrawingColor(color)
            draw()
            if selected {
                showHandles()
            }
            CGContextRestoreGState(context)
       }
    }
}
