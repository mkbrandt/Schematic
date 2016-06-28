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
            let removed = _attributeTexts.subtracting(newValue)
            let added = newValue.subtracting(_attributeTexts)
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
        _attributeTexts = decoder.decodeObject(forKey: "attributeTexts") as? Set<AttributeText> ?? []
        attributes = decoder.decodeObject(forKey: "attributes") as? [String : String] ?? [:]
        super.init(coder: decoder)
        _attributeTexts.forEach { $0._owner = self }
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(attributeTexts, forKey: "attributeTexts")
        coder.encode(attributes, forKey: "attributes")
        super.encode(with: coder)
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
    
    func stripPrefix(_ name: String) -> String {
        let range: Range = name.startIndex ..< name.index(after: name.startIndex)
        return name.replacingCharacters(in: range, with: "")
    }
    
    func attributeTextsForAttribute(_ name: String) -> [AttributeText] {
        return attributeTexts.filter { $0.format == "=\(name)" }
    }
    
    var attributeNames: [String] {
        return attributes.keys.sorted { $0 < $1 }
    }
    
    func attributeValue(_ name: String) -> String {
        return attributes[name] ?? "=\(name)"
    }
    
    func setAttribute(_ value: String, name: String) {
        attributes[name] = value
    }
    
    func formatAttribute(_ format: String) -> String {
        if format.hasPrefix("=") {
            return attributeValue(stripPrefix(format))
        } else {
            return format
        }
    }
    
    override func moveBy(_ offset: CGPoint) {
        attributeTexts.forEach({ $0.moveBy(offset) })
        cachedBounds = nil
    }
    
    override func rotateByAngle(_ angle: CGFloat, center: CGPoint) {
        attributeTexts.forEach({ $0.rotateByAngle(angle, center: center) })
        cachedBounds = nil
    }
    
    override func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if let ht = super.hitTest(point, threshold: threshold) {
            return ht
        }
        if closestPointToPoint(point).distanceToPoint(point) < threshold {
            return .hitsOn(self)
        }
        return nil
    }
        
// MARK: Drawing
    
    override func drawInRect(_ rect: CGRect) {
        if bounds.intersects(rect) {
            for attr in attributeTexts {
                attr.drawInRect(rect);
            }
        }
    }

}

