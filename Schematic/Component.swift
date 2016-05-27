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
    var refDes: String         { return package?.refDes ?? "UNPACKAGED" }
    var partNumber: String     { return package?.partNumber ?? "UNPACKAGED" }
    var name: String = ""
    
    var refDesText: AttributeText?
    var partNumberText: AttributeText?
    var nameText: AttributeText?
    
    override var boundAttributes: Set<AttributeText> {
        return attributeTexts + [refDesText, partNumberText, nameText].flatMap({$0})
    }
    
    var pins: Set<Pin> = []     { didSet { pins.forEach({$0.component = self}) }}
    
    var package: Package?
    var outline: Graphic?
    
    override var origin: CGPoint {
        get { return bounds.origin }
        set { moveBy(newValue - origin) }
    }
    
    override var bounds: CGRect {
        let pinBounds = pins.reduce(CGRect(), combine: {$0 + $1.bounds})
        let b = outline?.bounds ?? CGRect()
        return pinBounds + b + super.bounds
    }
    
    override var centerPoint: CGPoint { return graphicBounds.center }
    
    override var graphicBounds: CGRect { return outline?.bounds ?? bounds }
    
    override var elements: Set<Graphic>     { return pins + [refDesText, partNumberText, nameText].flatMap{$0} }

    override var inspectionName: String     { return "Component" }
    override var inspectables: [Inspectable] {
        return [
            Inspectable(name: "name", type: .String, displayName: "Function Name"),
            Inspectable(name: "refDes", type: .String, displayName: "Reference Designator"),
            Inspectable(name: "partNumber", type: .String, displayName: "Part Number")
        ]
    }
    
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
        name = decoder.decodeObjectForKey("name") as? String ?? ""
        pins = decoder.decodeObjectForKey("pins") as? Set<Pin> ?? []
        package = decoder.decodeObjectForKey("package") as? Package
        outline = decoder.decodeObjectForKey("outline") as? Graphic
        refDesText = decoder.decodeObjectForKey("refDesText") as? AttributeText
        partNumberText = decoder.decodeObjectForKey("partNumberText") as? AttributeText
        nameText = decoder.decodeObjectForKey("nameText") as? AttributeText
        super.init(coder: decoder)
        pins.forEach({$0.component = self})
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(name, forKey: "name")
        coder.encodeObject(pins, forKey: "pins")
        coder.encodeObject(package, forKey: "package")
        coder.encodeObject(outline, forKey: "outline")
        coder.encodeObject(refDesText, forKey: "refDesText")
        coder.encodeObject(partNumberText, forKey: "partNumberText")
        coder.encodeObject(nameText, forKey: "nameText")
        super.encodeWithCoder(coder)
    }
    
    override func attributeValue(name: String) -> String {
        if name.hasPrefix("=") {
            let name = stripPrefix(name)
            
            switch name.lowercaseString {
            case "refdes": return refDes
            case "partnumber": return partNumber
            case "name": return self.name
            default: return super.attributeValue(name)
            }
        }
        return super.attributeValue(name)
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
        outline?.rotateByAngle(angle, center: center)
        pins.forEach({ $0.rotateByAngle(angle, center: center)})
        //boundAttributes.forEach({ $0.rotateByAngle(angle, center: center) })
        //super.rotateByAngle(angle, center: center)
    }
    
    override func intersectsRect(rect: CGRect) -> Bool {
        for attr in boundAttributes {
            if attr.intersectsRect(rect) {
                return true
            }
        }
        for pin in pins {
            if pin.intersectsRect(rect) {
                return true
            }
        }
        return graphicBounds.intersects(rect)
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
        refDesText?.drawInRect(rect)
        partNumberText?.drawInRect(rect)
        nameText?.drawInRect(rect)
        super.drawInRect(rect)            // draws all of the attributes
    }
    
    override func drawInRect(rect: CGRect) {
        if rect.intersects(bounds.insetBy(dx: -SelectRadius, dy: -SelectRadius)) {
            drawImage()
            if selected {
                showHandles()
            }
        }
    }
}

class AutoComponent: Component
{
    var text: String {
        didSet { rejigger() }
    }
    
    init(origin: CGPoint, text: String) {
        self.text = text
        super.init(origin: origin, pins: [], outline: Graphic(origin: CGPoint()))
        rejigger()
    }
    
    required init?(coder decoder: NSCoder) {
        text = decoder.decodeObjectForKey("text") as? String ?? ""
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(text, forKey: "text")
        super.encodeWithCoder(coder)
    }
    
    override func attributeValue(format: String) -> String {
        switch format {
        case "=RefDes": return refDes ?? "?"
        default: return format
        }
    }
    
    func pinInfo(name: String, text: String) -> [(String, String)] {
        let re = RegularExpression(pattern: name + "[[:space:]]*\\{([^}]*)\\}")
        if re.matchesWithString(text) {
            if let s = re.match(1) {
                let pins = s.componentsSeparatedByString(",")
                return pins.map { ss in
                    let fields = ss.componentsSeparatedByString(":")
                    let sf = fields.map { $0.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet()) }
                    if sf.count == 2 {
                        return (sf[0], sf[1])
                    } else {
                        return ("", "")
                    }
                }
            }
        }
        return []
    }
    
    func distributePins(pins: [Pin], start: CGPoint, offset: CGPoint) {
        var org = start
        pins.forEach {
            $0.origin = org
            org = org + offset
        }
    }
    
    func rejigger() {
        let rowHeight = GridSize
        
        let leftPinInfo = pinInfo("left", text: text)
        let rightPinInfo = pinInfo("right", text: text)
        let topPinInfo = pinInfo("top", text: text)
        let bottomPinInfo = pinInfo("bottom", text: text)
        
        let leftPins = leftPinInfo.map { Pin(origin: CGPoint(x: 0, y: 0), component: self, name: $0.0, number: $0.1, orientation: .Left) }
        let rightPins = rightPinInfo.map { Pin(origin: CGPoint(x: 0, y: 0), component: self, name: $0.0, number: $0.1, orientation: .Right) }
        let topPins = topPinInfo.map { Pin(origin: CGPoint(x: 0, y: 0), component: self, name: $0.0, number: $0.1, orientation: .Top) }
        let bottomPins = bottomPinInfo.map { Pin(origin: CGPoint(x: 0, y: 0), component: self, name: $0.0, number: $0.1, orientation: .Bottom) }
        
        let leftWidth = ceil(leftPins.reduce(0.0, combine: { max($0, $1.pinNameText.size.width)}) / GridSize) * GridSize
        let rightWidth = ceil(rightPins.reduce(0.0, combine: { max($0, $1.pinNameText.size.width)}) / GridSize) * GridSize
        let topWidth = ceil(topPins.reduce(0.0, combine: { max($0, $1.pinNameText.size.width)}) / GridSize) * GridSize
        let bottomWidth = ceil(bottomPins.reduce(0.0, combine: { max($0, $1.pinNameText.size.width)}) / GridSize) * GridSize
        
        let vertCount = max(leftPinInfo.count, rightPinInfo.count)
        let horizCount = max(topPinInfo.count, bottomPinInfo.count)

        let rectWidth = leftWidth + rightWidth + CGFloat(horizCount) * rowHeight + GridSize
        let rectHeight = topWidth + bottomWidth + CGFloat(vertCount) * rowHeight + GridSize
        
        let leftStart = rectHeight - topWidth - GridSize - CGFloat((vertCount - leftPins.count) / 2) * rowHeight
        distributePins(leftPins, start: CGPoint(x: 0, y: leftStart), offset: CGPoint(x: 0, y: -rowHeight))
        
        let rightStart = rectHeight - topWidth - GridSize - CGFloat((vertCount - rightPins.count) / 2) * rowHeight
        distributePins(rightPins, start: CGPoint(x: rectWidth, y: rightStart), offset: CGPoint(x: 0, y: -rowHeight))
        
        let topStart = leftWidth + 10 + CGFloat((horizCount - topPins.count) / 2) * rowHeight
        distributePins(topPins, start: CGPoint(x: topStart, y: rectHeight), offset: CGPoint(x: rowHeight, y: 0))
        
        let bottomStart = leftWidth + 10 + CGFloat((horizCount - bottomPins.count) / 2) * rowHeight
        distributePins(bottomPins, start: CGPoint(x: bottomStart, y: 0), offset: CGPoint(x: rowHeight, y: 0))
        
        outline = RectGraphic(origin: CGPoint(x: 0, y: 0), size: CGSize(width: rectWidth, height: rectHeight))
        pins = Set(leftPins + rightPins + topPins + bottomPins)
        pins = Set(pins.filter { $0.pinName != "" })
        
        refDesText = AttributeText(origin: CGPoint(x: 0, y: -GridSize), format: "=RefDes", angle: 0, owner: self)
        cachedImage = nil
    }
}
