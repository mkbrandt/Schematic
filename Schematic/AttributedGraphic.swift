//
//  AttributedGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class AttributedGraphic: Graphic
{
    var attributeTexts: Set<AttributeText> = []
    var boundAttributes: Set<AttributeText>         { return attributeTexts }
    
    var freeAttributes: [String: String] = [:]
    
    override var elements: Set<Graphic>     { return attributeTexts }
    
    override var bounds: CGRect {
        return boundAttributes.reduce(CGRect(), combine: { $0 + $1.bounds })
    }
    
    var graphicBounds: CGRect { return bounds }
    
    override init(origin: CGPoint) {
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        attributeTexts = decoder.decodeObjectForKey("attributes") as? Set<AttributeText> ?? []
        freeAttributes = decoder.decodeObjectForKey("freeAttributes") as? [String: String] ?? [:]
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(attributeTexts, forKey: "attributeTexts")
        coder.encodeObject(freeAttributes, forKey: "freeAttributes")
        super.encodeWithCoder(coder)
    }

    override var inspectionName: String         { return "AttributedGraphic" }
    override var inspectables: [Inspectable]    { return [] }

    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        return nil
    }
    
    func stripPrefix(name: String) -> String {
        return name.stringByReplacingCharactersInRange(name.startIndex...name.startIndex, withString: "")
    }
    
    var attributeNames: [String] {
        return Array(freeAttributes.keys)
    }
    
    func attributeValue(name: String) -> String {
        if name.hasPrefix("=") {
            if let value = freeAttributes[stripPrefix(name)] {
                return value
            } else {
                return name
            }
        }
        return name
    }
    
    func setAttribute(value: String, name: String) {
        freeAttributes[name] = value
    }
    
    override func moveBy(offset: CGPoint) {
        attributeTexts.forEach({ $0.moveBy(offset) })
        super.moveBy(offset)
    }
    
    override func rotateByAngle(angle: CGFloat, center: CGPoint) {
        attributeTexts.forEach({ $0.rotateByAngle(angle, center: center) })
    }
    
    
// MARK: Drawing
    
    override func draw() {
        for attr in attributeTexts {
            attr.draw();
        }
    }

}

