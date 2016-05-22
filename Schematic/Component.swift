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
    var refDes: String?
    var refDesText: AttributeText?
    
    var pins: [Pin] = [] {
        willSet {
            pins.forEach {
                $0.moveBy(origin)
                $0.component = nil
            }
        }
        didSet {
            pins.forEach {
                $0.origin = $0.origin - origin
                $0.component = self
            }
        }
    }
    
    var package: Package?
    var outline: Graphic? {
        willSet {
            if let g = outline {
                g.moveBy(CGPoint(x: origin.x, y: origin.y))
            }
        }
        didSet {
            if let g = outline {
                g.moveBy(CGPoint(x: -origin.x, y: -origin.y))
            }
        }
    }
    
    override var bounds: CGRect {
        let pinBounds = pins.reduce(CGRect(), combine: {$0 + $1.bounds})
        var b = outline?.bounds ?? CGRect()
        b = pinBounds + b
        b.origin = b.origin + origin
        return b
    }
    
    override var elements: [Graphic]    { return pins + [refDesText, outline].flatMap({$0}) }

    override var inspectionName: String     { return "Component" }

    override init(origin: CGPoint) {
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        pins = decoder.decodeObjectForKey("pins") as? [Pin] ?? []
        package = decoder.decodeObjectForKey("package") as? Package
        outline = decoder.decodeObjectForKey("outline") as? Graphic
        refDes = decoder.decodeObjectForKey("refDes") as? String
        refDesText = decoder.decodeObjectForKey("refDesText") as? AttributeText
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(pins, forKey: "pins")
        coder.encodeObject(package, forKey: "package")
        coder.encodeObject(refDes, forKey: "refDes")
        coder.encodeObject(refDesText, forKey: "refDesText")
        coder.encodeObject(outline, forKey: "outline")
        super.encodeWithCoder(coder)
    }
    
    override func attributeValue(name: String) -> String {
        switch name.lowercaseString {
        case "=refdes": return refDes ?? "U?"
        default: return name
        }
    }
    
    override func showHandlesInView(view: SchematicView) {
        let r = CGRect(origin: bounds.origin - origin, size: bounds.size)
        
        drawPoint(r.origin, color: NSColor.blackColor(), view: view)
        drawPoint(r.topLeft, color: NSColor.blackColor(), view: view)
        drawPoint(r.topRight, color: NSColor.blackColor(), view: view)
        drawPoint(r.bottomRight, color: NSColor.blackColor(), view: view)
    }
    
    override func drawInRect(rect: CGRect, view: SchematicView) {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextSaveGState(context)
        
        let rect = rect.translateBy(-origin)
        
        CGContextTranslateCTM(context, origin.x, origin.y)
        outline?.drawInRect(rect, view: view)
        pins.forEach { $0.drawInRect(rect, view: view) }
        refDesText?.drawInRect(rect, view: view)
        super.drawInRect(rect, view: view)            // draws all of the attributes
        
        CGContextRestoreGState(context)
    }
}

class AutoComponent: Component
{
    var text: String {
        didSet { rejigger() }
    }
    
    init(origin: CGPoint, text: String) {
        self.text = text
        super.init(origin: origin)
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
        pins = leftPins + rightPins + topPins + bottomPins
        pins = pins.filter { $0.pinName != "" }
        
        refDesText = AttributeText(origin: CGPoint(x: 0, y: -GridSize), format: "=RefDes", angle: 0, owner: self)
    }
}
