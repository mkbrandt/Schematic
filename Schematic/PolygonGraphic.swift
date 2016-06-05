//
//  PolygonGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/26/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class PolygonGraphic: PrimitiveGraphic
{
    var _vertices: [CGPoint] = []
    
    override var points: [CGPoint] {
        get { return [origin] + _vertices }
        set {
            var nv = newValue
            origin = nv.removeFirst()
            _vertices = nv
        }
    }
    var filled: Bool
    
    override var centerPoint: CGPoint { return bounds.center }
    
    var lines: [Line] {
        var sp = origin
        var lines: [Line] = []
        for ep in _vertices {
            lines.append(Line(origin: sp, endPoint: ep))
            sp = ep
        }
        lines.append(Line(origin: sp, endPoint: origin))
        return lines
    }
    
    override var json: JSON {
        var json = super.json
        json["__class__"] = "PolygonGraphic"
        json["filled"] = JSON(filled)
        json["vertices"] = JSON(_vertices.map { $0.json })
        return json
    }
    
    init(vertices: [CGPoint], filled: Bool) {
        self.filled = filled
        super.init(origin: vertices[0])
        self.points = vertices
    }
    
    required init?(coder decoder: NSCoder) {
        if let va = decoder.decodeObjectForKey("vertices") as? [NSValue] {
            _vertices = va.map { $0.pointValue }
        }
        filled = decoder.decodeBoolForKey("filled")
        super.init(coder: decoder)
    }
    
    override init(json: JSON) {
        _vertices = json["vertices"].arrayValue.map { CGPoint(json: $0) }
        filled = json["filled"].boolValue
        super.init(json: json)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        let va = _vertices.map { NSValue(point: $0) }
        coder.encodeObject(va, forKey: "vertices")
        coder.encodeBool(filled, forKey: "filled")
        super.encodeWithCoder(coder)
    }
    
    override func setPoint(point: CGPoint, index: Int) {
        if index == 0 {
            origin = point
        } else if index <= _vertices.count {
            _vertices[index - 1] = point
        }
    }
    
    override func moveBy(offset: CGPoint, view: SchematicView) {
        points = points.map { $0 + offset }
    }
    
    override func closestPointToPoint(point: CGPoint) -> CGPoint {
        let cps = lines.map({$0.closestPointToPoint(point)})
        return cps.reduce(origin, combine: { $0.distanceToPoint(point) < $1.distanceToPoint(point) ? $0 : $1})
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextBeginPath(context)
        CGContextMoveToPoint(context, origin.x, origin.y)
        for p in _vertices {
            CGContextAddLineToPoint(context, p.x, p.y)
        }
        //CGContextClosePath(context)
        if filled {
            CGContextFillPath(context)
        } else {
            CGContextStrokePath(context)
        }
    }
}
