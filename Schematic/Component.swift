//
//  Component.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class Component: AttributedGraphic
{
    var refDes: String {
        get { return package?.refDes ?? "UNPACKAGED" }
        set { package?.refDes = newValue }
    }
    
    var partNumber: String {
        get { return package?.partNumber ?? "UNPACKAGED" }
        set { package?.partNumber = newValue }
    }
    
    var value: String? {
        get { return attributes["value"] }
        set { attributes["value"] = newValue }
    }
    
    var refDesText: AttributeText?          { return attributeTextsForAttribute("refDes").first }
    var partNumberText: AttributeText?      { return attributeTextsForAttribute("partNumber").first }
    var nameText: AttributeText?            { return attributeTextsForAttribute("name").first }
    
    var pins: Set<Pin> = []     {
        didSet {
            pins.forEach{
                if $0.component != self {
                    $0.component = self
                }
            }
        }
    }
    
    var package: Package?
    var outline: Graphic?
    
    override var origin: CGPoint {
        get { return bounds.origin }
        set { moveBy(newValue - origin) }
    }
    
    override var bounds: CGRect {
        let pinBounds = pins.reduce(CGRect(), combine: {$0 + $1.bounds})
        let b = outline?.bounds ?? CGRect()
        let attrBounds = super.bounds
        return pinBounds + b + attrBounds
    }
    
    override var centerPoint: CGPoint { return graphicBounds.center }
    
    override var graphicBounds: CGRect { return outline?.bounds ?? bounds }
    
    override var elements: Set<Graphic>     { return pins + super.elements }

    override var inspectionName: String     { return "Component" }
    
    var cachedImage: NSImage?
    
    var image: NSImage {
        if let image = cachedImage {
            return image
        } else {
            let image = preview
            cachedImage = image
            return image
        }
    }
    
    var preview: NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        let context = NSGraphicsContext.currentContext()?.CGContext
        CGContextSaveGState(context)
        CGContextTranslateCTM(context, -bounds.origin.x, -bounds.origin.y)
        drawImage()
        CGContextRestoreGState(context)
        image.unlockFocus()
        return image
    }
    
    init(origin: CGPoint, pins: Set<Pin>, outline: Graphic) {
        self.pins = pins
        self.outline = outline
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        pins = decoder.decodeObjectForKey("pins") as? Set<Pin> ?? []
        package = decoder.decodeObjectForKey("package") as? Package
        outline = decoder.decodeObjectForKey("outline") as? Graphic
        super.init(coder: decoder)
        pins.forEach({$0.component = self})
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(value, forKey: "value")
        coder.encodeObject(pins, forKey: "pins")
        coder.encodeObject(package, forKey: "package")
        coder.encodeObject(outline, forKey: "outline")
        super.encodeWithCoder(coder)
    }
    
    override var attributeNames: [String] {
        return super.attributeNames + (package?.attributeNames ?? [])
    }
    
    override func attributeValue(name: String) -> String {
        return package?.attributes[name] ?? super.attributeValue(name)
    }
    
    override func setAttribute(value: String, name: String) {
        if let package = package where package.attributes[name] != nil {
            package.setAttribute(value, name: name)
        } else {
            super.setAttribute(value, name: name)
        }
    }
        
    override func isSettable(key: String) -> Bool {
        switch key {
        case "refDes", "partNumber":
            return package != nil
        default:
            return super.isSettable(key)
        }
    }
    
    override func setValue(value: AnyObject?, forUndefinedKey key: String) {
        switch key {
        case "refDes", "partNumber":
            package?.setValue(value, forKey: key)
        default:
            break
        }
        cachedImage = nil
    }
    
    override func moveBy(offset: CGPoint) {
        outline?.moveBy(offset)
        elements.forEach { $0.moveBy(offset) }
    }
    
    override func rotateByAngle(angle: CGFloat, center: CGPoint) {
        cachedImage = nil
        outline?.rotateByAngle(angle, center: center)
        pins.forEach({ $0.rotateByAngle(angle, center: center)})
        super.rotateByAngle(angle, center: center)
    }
    
    override func intersectsRect(rect: CGRect) -> Bool {
        return graphicBounds.intersects(rect) || super.intersectsRect(rect)
    }
    
    override func showHandles() {
        drawPoint(graphicBounds.origin, color: NSColor.blackColor())
        drawPoint(graphicBounds.topLeft, color: NSColor.blackColor())
        drawPoint(graphicBounds.topRight, color: NSColor.blackColor())
        drawPoint(graphicBounds.bottomRight, color: NSColor.blackColor())
    }
    
    func drawImage() {
        let rect = bounds
        outline?.drawInRect(rect)
        pins.forEach { $0.drawInRect(rect) }
        super.drawInRect(rect)            // draws all of the attributes
    }
    
    override func drawInRect(rect: CGRect) {
        if rect.intersects(bounds.insetBy(dx: -5, dy: -5)) {
            drawImage()
            //image.drawInRect(bounds)
            if selected {
                showHandles()
            }
        }
    }
}
