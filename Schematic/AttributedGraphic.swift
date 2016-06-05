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
    var _attributeTexts: Set<AttributeText> = []
    var attributeTexts: Set<AttributeText> {
        get { return _attributeTexts }
        set {
            let removed = _attributeTexts.subtract(newValue)
            let added = newValue.subtract(_attributeTexts)
            _attributeTexts = newValue
            removed.forEach { $0._owner = nil }
            added.forEach { $0._owner = self }
        }
    }
    
    var attributes: [String: String] = [:]
    
    override var elements: Set<Graphic>     { return attributeTexts }
    
    override var json: JSON {
        var json = super.json
        json["__class__"] = "AttributedGraphic"
        json["attributeTexts"] = JSON(attributeTexts.map { $0.json })
        json["attributes"] = JSON(attributes)
        return json
    }
    
    var cachedBounds: CGRect?
    override var bounds: CGRect {
        if let bounds = cachedBounds {
            return bounds
        } else {
            let bounds = attributeTexts.reduce(CGRect(), combine: { $0 + $1.bounds })
            //cachedBounds = bounds
            return bounds
        }
    }
    
    var graphicBounds: CGRect { return CGRect() }
    
    override init(origin: CGPoint) {
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        _attributeTexts = decoder.decodeObjectForKey("attributeTexts") as? Set<AttributeText> ?? []
        attributes = decoder.decodeObjectForKey("attributes") as? [String : String] ?? [:]
        super.init(coder: decoder)
        _attributeTexts.forEach { $0._owner = self }
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(attributeTexts, forKey: "attributeTexts")
        coder.encodeObject(attributes, forKey: "attributes")
        super.encodeWithCoder(coder)
    }

    override var inspectionName: String         { return "AttributedGraphic" }
    override var inspectables: [Inspectable]    { return [] }

    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        return nil
    }
    
    override init(json: JSON) {
        attributes = json["attributes"].dictionaryObject as? [String: String] ?? [:]
        super.init(json: json)
        attributeTexts = Set(json["attributeTexts"].arrayValue.flatMap { jsonToGraphic($0) as? AttributeText })
    }
    
    func stripPrefix(name: String) -> String {
        return name.stringByReplacingCharactersInRange(name.startIndex...name.startIndex, withString: "")
    }
    
    func attributeTextsForAttribute(name: String) -> [AttributeText] {
        return attributeTexts.filter { $0.format == "=\(name)" }
    }
    
    var attributeNames: [String] {
        return attributes.keys.sort { $0 < $1 }
    }
    
    func attributeValue(name: String) -> String {
        return attributes[name] ?? "=\(name)"
    }
    
    func setAttribute(value: String, name: String) {
        attributes[name] = value
    }
    
    func formatAttribute(format: String) -> String {
        if format.hasPrefix("=") {
            return attributeValue(stripPrefix(format))
        } else {
            return format
        }
    }
    
    override func moveBy(offset: CGPoint, view: SchematicView) {
        attributeTexts.forEach({ $0.moveBy(offset, view: view) })
        cachedBounds = nil
    }
    
    override func rotateByAngle(angle: CGFloat, center: CGPoint) {
        attributeTexts.forEach({ $0.rotateByAngle(angle, center: center) })
        cachedBounds = nil
    }
    
    override func hitTest(point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if let ht = super.hitTest(point, threshold: threshold) {
            return ht
        }
        if closestPointToPoint(point).distanceToPoint(point) < threshold {
            return .HitsOn(self)
        }
        return nil
    }
        
// MARK: Drawing
    
    override func drawInRect(rect: CGRect) {
        if bounds.intersects(rect) {
            for attr in attributeTexts {
                attr.drawInRect(rect);
            }
        }
    }

}

