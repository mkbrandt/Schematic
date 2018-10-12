//
//  CircleGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class CircleState: GraphicState {
    var radius: CGFloat
    
    init(origin: CGPoint, radius: CGFloat) {
        self.radius = radius
        super.init(origin: origin)
    }
}

class CircleGraphic: PrimitiveGraphic
{
    override class var supportsSecureCoding: Bool { return true }
    
    var radius: CGFloat {
        willSet { willChangeValue(forKey: "radius") }
        didSet { didChangeValue(forKey: "radius") }
    }
    
    override var bounds: CGRect     { return CGRect(x: origin.x - radius, y: origin.y - radius, width: 2 * radius, height: 2 * radius) }
    override var points: [CGPoint]  { return [origin, origin + CGPoint(x: radius, y: 0)] }
    
    override var inspectables: [Inspectable] {
        return super.inspectables + [
            Inspectable(name: "radius", type: .float)
        ]
    }
    
    override var state: GraphicState {
        get { return CircleState(origin: origin, radius: radius) }
        set {
            if let newValue = newValue as? CircleState {
                (origin, radius) = (newValue.origin, newValue.radius)
            }
        }
    }

    override var inspectionName: String     { return "Circle" }
    
    override var json: JSON {
        var json = super.json
        json["__class__"] = "CircleGraphic"
        json["radius"] = JSON(radius)
        return json
    }

    init(origin: CGPoint, radius: CGFloat) {
        self.radius = radius
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        radius = decoder.decodeCGFloatForKey("radius")
        super.init(coder: decoder)
    }
    
    override init(json: JSON) {
        radius = CGFloat(json["radius"].doubleValue)
        super.init(json: json)
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with coder: NSCoder) {
        coder.encodeCGFloat(radius, forKey: "radius")
        super.encode(with: coder)
    }
    
    override func setPoint(_ point: CGPoint, index: Int) {
        switch index {
        case 0:
            origin = point
        case 1:
            radius = origin.distanceToPoint(point)
        default:
            break
        }
    }
    
    override func closestPointToPoint(_ point: CGPoint) -> CGPoint {
        let v = point - origin
        let cp = CGPoint(length: radius, angle: v.angle)
        if origin.distanceToPoint(point) < cp.distanceToPoint(point) {
            return origin
        } else {
            return cp
        }
    }
    
    override func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if let ht = super.hitTest(point, threshold: threshold) {
            return ht
        }
        if abs(radius - point.distanceToPoint(origin)) < threshold {
            return .hitsOn(self)
        }
        return nil
    }
    
    override func rotateByAngle(_ angle: CGFloat, center: CGPoint) {
        origin = rotatePoint(origin, angle: angle, center: center)
    }
    
    func intersectionsWithLine(_ line: Line) -> [CGPoint] {
        let cp = line.closestPointToPoint(origin, extended: true)
        let vp = cp - origin
        if vp.length < radius {
            let rr = radius * radius
            let dd = vp.length * vp.length
            let ch = sqrt(rr - dd)
            let vch = CGPoint(length: ch, angle: vp.angle + PI / 2)
            let possible = [cp + vch, cp - vch]
            return possible.filter { line.containsPoint($0) }
        } else if vp.length == radius {
            return [cp]
        } else {
            return []
        }
    }
    

    func intersectsLine(_ line: Line) -> Bool {
        return intersectionsWithLine(line).count > 0
    }
    
    override func intersectsRect(_ rect: CGRect) -> Bool {
        return rect.contains(bounds) || rect.lines.reduce(false, { $0 || intersectsLine($1) })
    }
    
    override func draw() {
        let context = NSGraphicsContext.current?.cgContext
        
        context?.strokeEllipse(in: bounds)
    }
}
