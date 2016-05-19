//
//  SCHComponent.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class SCHComponent: SCHElement
{
    var refDes: SCHAttribute {
        get { return attributes["refDes"] ?? SCHAttribute(string: "RefDes") }
        set { attributes["refDes"] = newValue }
    }
    
    var pins: [SCHPin] = []
    var package: SCHPackage?
    var outline: SCHGraphic?
    
    override var bounds: CGRect {
        var pinBounds = pins.reduce(CGRect(), combine: {$0 + $1.bounds})
        pinBounds.origin = origin + pinBounds.origin
        let ob = outline?.bounds ?? CGRect()
        return pinBounds + ob
    }
    
    override init(origin: CGPoint) {
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        pins = decoder.decodeObjectForKey("pins") as? [SCHPin] ?? []
        package = decoder.decodeObjectForKey("package") as? SCHPackage
        outline = decoder.decodeObjectForKey("outline") as? SCHGraphic
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(pins, forKey: "pins")
        coder.encodeObject(package, forKey: "package")
        super.encodeWithCoder(coder)
    }
    
    override func elementAtPoint(point: CGPoint) -> SCHGraphic? {
        let relativePoint = point - origin
        for pin in pins {
            if let el = pin.elementAtPoint(relativePoint) {
                return el
            }
        }
        return super.elementAtPoint(point)
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextSaveGState(context)
        
        CGContextTranslateCTM(context, origin.x, origin.y)
        outline?.draw()
        pins.forEach { $0.draw() }
        super.draw()            // draws all of the attributes
        
        CGContextRestoreGState(context)
    }
}

class AutoComponent: SCHComponent
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
    
    func distributePins(pins: [SCHPin], start: CGPoint, offset: CGPoint) {
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
        
        let leftPins = leftPinInfo.map { SCHPin(origin: CGPoint(x: 0, y: 0), component: self, name: $0.0, number: $0.1, orientation: .Left) }
        let rightPins = rightPinInfo.map { SCHPin(origin: CGPoint(x: 0, y: 0), component: self, name: $0.0, number: $0.1, orientation: .Right) }
        let topPins = topPinInfo.map { SCHPin(origin: CGPoint(x: 0, y: 0), component: self, name: $0.0, number: $0.1, orientation: .Top) }
        let bottomPins = bottomPinInfo.map { SCHPin(origin: CGPoint(x: 0, y: 0), component: self, name: $0.0, number: $0.1, orientation: .Bottom) }
        
        let leftWidth = ceil(leftPins.reduce(0.0, combine: { max($0, $1.pinNameAttribute.size.width)}) / GridSize) * GridSize
        let rightWidth = ceil(rightPins.reduce(0.0, combine: { max($0, $1.pinNameAttribute.size.width)}) / GridSize) * GridSize
        let topWidth = ceil(topPins.reduce(0.0, combine: { max($0, $1.pinNameAttribute.size.width)}) / GridSize) * GridSize
        let bottomWidth = ceil(bottomPins.reduce(0.0, combine: { max($0, $1.pinNameAttribute.size.width)}) / GridSize) * GridSize
        
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
        pins = pins.filter { $0.pinNameAttribute.string != "" }
        
        refDes = SCHAttribute(origin: CGPoint(x: 0, y: -GridSize), string: "U?")
    }
}
