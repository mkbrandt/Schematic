//
//  Component.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa
import CloudKit

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
    
    var netpins: String? {
        get { return package?.netpins }
        set { package?.netpins = newValue }
    }
    
    var refDesText: AttributeText?          { return attributeTextsForAttribute("refDes").first }
    var partNumberText: AttributeText?      { return attributeTextsForAttribute("partNumber").first }
    var nameText: AttributeText?            { return attributeTextsForAttribute("name").first }
    var record: CKRecord?
    
    var name: String    { return package?.partNumber ?? value ?? "UNNAMED" }
    
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
    
    override var json: JSON {
        var json = super.json
        json["__class__"] = "Component"
        if let outline = outline {
            json["outline"] = outline.json
        }
        json["pins"] = JSON(pins.map { $0.json })
        return json
    }
    
    var connectedNets: Set<Net>    { return Set(pins.flatMap { $0.node?.attachments.first }) }
    
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
    
    var sortName: String { return (package?.partNumber ?? "_") + (value ?? "UNNAMED") }
    
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
            //cachedImage = image
            return image
        }
    }
    
    var preview: NSImage {
        let image = NSImage(size: bounds.size)
        image.lockFocus()
        let context = NSGraphicsContext.current()?.cgContext
        context?.saveGState()
        context?.translate(x: -bounds.origin.x, y: -bounds.origin.y)
        drawImage()
        context?.restoreGState()
        image.unlockFocus()
        return image
    }
    
    init(origin: CGPoint, pins: Set<Pin>, outline: Graphic) {
        self.pins = pins
        self.outline = outline
        super.init(origin: origin)
        pins.forEach({ $0.component = self })
    }
    
    required init?(coder decoder: NSCoder) {
        pins = decoder.decodeObject(forKey: "pins") as? Set<Pin> ?? []
        package = decoder.decodeObject(forKey: "package") as? Package
        outline = decoder.decodeObject(forKey: "outline") as? Graphic
        record = decoder.decodeObject(forKey: "record") as? CKRecord
        super.init(coder: decoder)
        pins.forEach({$0.component = self})
        if let netpins = attributes["netpins"] ?? attributes["NetPins"] {
            self.netpins = netpins
            attributes["netpins"] = nil
            attributes["NetPins"] = nil
        }
    }
    
    override init(json: JSON) {
        outline = jsonToGraphic(json["outline"])
        pins = Set(json["pins"].arrayValue.map { Pin(json: $0) })
        super.init(json: json)
        pins.forEach { $0.component = self }
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(value, forKey: "value")
        coder.encode(pins, forKey: "pins")
        coder.encode(package, forKey: "package")
        coder.encode(outline, forKey: "outline")
        if let record = record {
            coder.encode(record, forKey: "record")
        }
        super.encode(with: coder)
    }
    
    override var attributeNames: [String] {
        return super.attributeNames + (package?.attributeNames ?? [])
    }
    
    override func attributeValue(_ name: String) -> String {
        return package?.attributes[name] ?? super.attributeValue(name)
    }
    
    override func setAttribute(_ value: String, name: String) {
        if let package = package where package.attributes[name] != nil {
            package.setAttribute(value, name: name)
        } else {
            super.setAttribute(value, name: name)
        }
    }
        
    override func isSettable(_ key: String) -> Bool {
        switch key {
        case "refDes", "partNumber":
            return package != nil
        default:
            return super.isSettable(key)
        }
    }
    
    override func setValue(_ value: AnyObject?, forUndefinedKey key: String) {
        switch key {
        case "refDes", "partNumber":
            package?.setValue(value, forKey: key)
        default:
            break
        }
        cachedImage = nil
    }
    
    override func designCheck(_ view: SchematicView) {
        pins.forEach { pin in
            pin.designCheck(view)
        }
    }
    
    override func moveBy(_ offset: CGPoint) {
        outline?.moveBy(offset)
        elements.forEach { $0.moveBy(offset) }
        cachedBounds = nil
    }
    
    override func rotateByAngle(_ angle: CGFloat, center: CGPoint) {
        cachedImage = nil
        outline?.rotateByAngle(angle, center: center)
        pins.forEach({ $0.rotateByAngle(angle, center: center)})
        //super.rotateByAngle(angle, center: center)                // attributeTexts
    }
    
    func flipAttributeHorizontal(_ attribute: AttributeText, center: CGPoint) {
        let c2o = attribute.bounds.center.x - attribute.origin.x
        var ac = attribute.bounds.center.x
        ac = center.x - (ac - center.x)
        attribute.origin.x = ac - c2o
        attribute.cachedBounds = nil
    }
    
    func flipAttributeVertical(_ attribute: AttributeText, center: CGPoint) {
        let c2o = attribute.bounds.center.y - attribute.origin.y
        var ac = attribute.bounds.center.y
        ac = center.y - (ac - center.y)
        attribute.origin.y = ac - c2o
        attribute.cachedBounds = nil
    }
    
    override func flipHorizontalAroundPoint(_ center: CGPoint) {
        cachedImage = nil
        outline?.flipHorizontalAroundPoint(center)
        pins.forEach({ $0.flipHorizontalAroundPoint(center) })
        attributeTexts.forEach({ flipAttributeHorizontal($0, center: center) })
    }
    
    override func flipVerticalAroundPoint(_ center: CGPoint) {
        cachedImage = nil
        outline?.flipVerticalAroundPoint(center)
        pins.forEach({ $0.flipVerticalAroundPoint(center) })
        attributeTexts.forEach({ flipAttributeVertical($0, center: center) })
    }
    
    func relink(_ nodeInfo: [(Pin, Node?)], view: SchematicView) {
        nodeInfo.forEach { (pin, node) in pin.node = node; node?.pin = pin }
        view.undoManager?.registerUndoWithTarget(self) { _ in
            self.unlink(view)
        }
        view.setNeedsDisplay(self.bounds.insetBy(dx: -5, dy: -5))
    }
    
    override func unlink(_ view: SchematicView) {
        let nodeInfo = pins.map { (pin: Pin) in (pin, pin.node) }
        pins.forEach { $0.node?.pin = nil }
        view.undoManager?.registerUndoWithTarget(self) { _ in
            self.relink(nodeInfo, view: view)
        }
        view.setNeedsDisplay(self.bounds.insetBy(dx: -5, dy: -5))
    }
    
    override func intersectsRect(_ rect: CGRect) -> Bool {
        return graphicBounds.intersects(rect) || super.intersectsRect(rect)
    }
    
    override func closestPointToPoint(_ point: CGPoint) -> CGPoint {
        if graphicBounds.contains(point) {
            return point
        }
        return origin
    }
    
    override func elementAtPoint(_ point: CGPoint) -> Graphic? {
        for pin in pins {
            if pin.graphicBounds.contains(point) {
                return pin
            }
        }
        return super.elementAtPoint(point)
    }
    
    override func showHandles() {
        drawPoint(graphicBounds.origin, color: NSColor.black())
        drawPoint(graphicBounds.topLeft, color: NSColor.black())
        drawPoint(graphicBounds.topRight, color: NSColor.black())
        drawPoint(graphicBounds.bottomRight, color: NSColor.black())
    }
    
    func drawImage() {
        let rect = bounds
        outline?.drawInRect(rect)
        pins.forEach { $0.drawInRect(rect) }
        super.drawInRect(rect)            // draws all of the attributes
    }
    
    override func drawInRect(_ rect: CGRect) {
        if rect.intersects(bounds.insetBy(dx: -5, dy: -5)) {
            drawImage()
            //image.drawInRect(bounds)
            if selected {
                showHandles()
            }
        }
    }
}
