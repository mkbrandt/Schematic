//
//  PolygonGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/26/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class PolygonState: GraphicState {
    var vertices: [CGPoint]
    
    init(origin: CGPoint, vertices: [CGPoint]) {
        self.vertices = vertices
        super.init(origin: origin)
    }
}

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
    
    override var state: GraphicState {
        get { return PolygonState(origin: origin, vertices: _vertices) }
        set {
            super.state = newValue
            if let newValue = newValue as? PolygonState {
                _vertices = newValue.vertices
            }
        }
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
        if let va = decoder.decodeObject(forKey: "vertices") as? [NSValue] {
            _vertices = va.map { $0.pointValue }
        }
        filled = decoder.decodeBool(forKey: "filled")
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
    
    override func encode(with coder: NSCoder) {
        let va = _vertices.map { NSValue(point: $0) }
        coder.encode(va, forKey: "vertices")
        coder.encode(filled, forKey: "filled")
        super.encode(with: coder)
    }
    
    override func setPoint(_ point: CGPoint, index: Int) {
        if index == 0 {
            origin = point
        } else if index <= _vertices.count {
            _vertices[index - 1] = point
        }
    }
    
    override func moveBy(_ offset: CGPoint) {
        points = points.map { $0 + offset }
    }
    
    override func closestPointToPoint(_ point: CGPoint) -> CGPoint {
        let cps = lines.map({$0.closestPointToPoint(point)})
        return cps.reduce(origin, combine: { $0.distanceToPoint(point) < $1.distanceToPoint(point) ? $0 : $1})
    }
    
    override func draw() {
        let context = NSGraphicsContext.current()?.cgContext
        
        context?.beginPath()
        context?.moveTo(x: origin.x, y: origin.y)
        for p in _vertices {
            context?.addLineTo(x: p.x, y: p.y)
        }
        //CGContextClosePath(context)
        if filled {
            context?.fillPath()
        } else {
            context?.strokePath()
        }
    }
}
