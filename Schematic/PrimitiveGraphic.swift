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
    override class var supportsSecureCoding: Bool { return true }
    
   var color: NSColor = NSColor.black
    var lineWeight: CGFloat = 1.0
    
    override var inspectables: [Inspectable] {
        return [
            Inspectable(name: "color", type: .color),
            Inspectable(name: "lineWeight", type: .float)
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
        color = decoder.decodeObject(of: NSColor.self, forKey: "color") ?? NSColor.black
        lineWeight = decoder.decodeCGFloatForKey("lineWeight")
        super.init(coder: decoder)
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(color, forKey: "color")
        coder.encodeCGFloat(lineWeight, forKey: "lineWeight")
        super.encode(with: coder)
    }
    
    override var json: JSON {
        var json = super.json
        let color = self.color.usingColorSpace(NSColorSpace.deviceRGB)!
        json["color"] = JSON(["r": color.redComponent, "g": color.greenComponent, "b": color.blueComponent])
        json["lineWeight"] = JSON(lineWeight)
        return json
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("fuck me")
    }

    override func drawInRect(_ rect: CGRect) {
        if intersectsRect(rect) {
            let context = NSGraphicsContext.current?.cgContext
            
            context?.saveGState()
            context?.setLineWidth(lineWeight)
            setDrawingColor(color)
            draw()
            if selected {
                showHandles()
            }
            context?.restoreGState()
       }
    }
}
