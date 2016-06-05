//
//  AutoComponent.swift
//  Schematic
//
//  Created by Matt Brandt on 5/27/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let testComponent = "left{ CLOCK:5, -, DATA0: 4, DATA1: 3, DATA2: 2, DATA3: 1}" +
    "right{ DIR: 12, -, OUT0: 11, OUT1: 10, OUT2: 9, OUT3: 8}" +
    "top{ VCC: 14}" + "bottom{GND: 7, VSS: 6, GND: 13}"

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
        
        let leftWidth = ceil(leftPins.reduce(0.0, combine: { max($0, $1.pinNameText?.size.width ?? 0)}) / GridSize) * GridSize
        let rightWidth = ceil(rightPins.reduce(0.0, combine: { max($0, $1.pinNameText?.size.width ?? 0)}) / GridSize) * GridSize
        let topWidth = ceil(topPins.reduce(0.0, combine: { max($0, $1.pinNameText?.size.width ?? 0)}) / GridSize) * GridSize
        let bottomWidth = ceil(bottomPins.reduce(0.0, combine: { max($0, $1.pinNameText?.size.width ?? 0)}) / GridSize) * GridSize
        
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
        
        let refDesText = AttributeText(origin: CGPoint(x: 0, y: -GridSize), format: "=RefDes", angle: 0, owner: self)
        attributeTexts.insert(refDesText)
        cachedImage = nil
    }
}

