//
//  ArcGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class ArcGraphic: CircleGraphic
{
    var startAngle: CGFloat
    var endAngle: CGFloat
    var clockwise: Bool
    
    var startPoint: CGPoint {
        get { return origin + CGPoint(length: radius, angle: startAngle) }
        set { startAngle = (newValue - origin).angle }
    }
    
    var endPoint: CGPoint {
        get { return origin + CGPoint(length: radius, angle: endAngle) }
        set { endAngle = (newValue - origin).angle }
    }
    
    var midPoint: CGPoint {
        get {
            let p1 = origin + CGPoint(length: radius, angle: (startAngle + endAngle) / 2)
            if pointOnArc(p1) {
                return p1
            }
            return origin - (p1 - origin)
        }
        set { radius = (newValue - origin).length }
    }

    override var points: [CGPoint] {
        return [startPoint, endPoint, midPoint]
    }
    
    override var bounds: CGRect {
        return rectContainingPoints(points)
    }
    
    var sweep: CGFloat {
        var sa = startAngle
        var ea = endAngle
        if clockwise {
            sa = endAngle
            ea = startAngle
        }
        if ea < sa {
            ea += 2 * PI
        }
        return ea - sa
    }
    
    override var inspectionName: String     { return "Arc" }
    
    override var json: JSON {
        var json = super.json
        json["__class__"] = "ArcGraphic"
        json["startAngle"] = JSON(startAngle)
        json["endAngle"] = JSON(endAngle)
        json["clockwise"] = JSON(clockwise)
        return json
    }
    
    init(origin: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.clockwise = clockwise
        super.init(origin: origin, radius: radius)
    }
    
    convenience init(startPoint: CGPoint, endPoint: CGPoint, midPoint: CGPoint) {
        self.init(origin: startPoint, radius: 1, startAngle: 0, endAngle: 0, clockwise: false)
        setParametersFromStartPoint(startPoint, endPoint: endPoint, midPoint: midPoint)
    }

    required init?(coder decoder: NSCoder) {
        startAngle = decoder.decodeCGFloatForKey("startAngle")
        endAngle = decoder.decodeCGFloatForKey("endAngle")
        clockwise = decoder.decodeBoolForKey("clockwise")
        super.init(coder: decoder)
    }
    
    override init(json: JSON) {
        startAngle = CGFloat(json["startAngle"].doubleValue)
        endAngle = CGFloat(json["endAngle"].doubleValue)
        clockwise = json["clockwise"].boolValue
        super.init(json: json)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        return nil
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeCGFloat(startAngle, forKey: "startAngle")
        coder.encodeCGFloat(endAngle, forKey: "endAngle")
        coder.encodeBool(clockwise, forKey: "clockwise")
        super.encodeWithCoder(coder)
    }
    
    func setParametersFromStartPoint(startPoint: CGPoint, endPoint: CGPoint, midPoint: CGPoint) {
        let mp1 = (startPoint + midPoint) / 2
        let mp2 = (endPoint + midPoint) / 2
        let ang1 = (midPoint - startPoint).angle + PI / 2
        let ang2 = (midPoint - endPoint).angle + PI / 2
        let bisector1 = LineGraphic(origin: mp1, vector: CGPoint(length: 100, angle: ang1))
        let bisector2 = LineGraphic(origin: mp2, vector: CGPoint(length: 100, angle: ang2))
        if let origin = bisector1.intersectionWithLine(bisector2, extendSelf: true, extendOther: true) {
            let radius = (startPoint - origin).length
            let startAngle = (startPoint - origin).angle
            let endAngle = (endPoint - origin).angle
            self.origin = origin
            self.radius = radius
            self.startAngle = startAngle
            self.endAngle = endAngle
            self.clockwise = true
            self.clockwise = pointOnArc(midPoint)
        }
    }
    
    override func setPoint(point: CGPoint, index: Int) {
        var startPoint = self.startPoint
        var endPoint = self.endPoint
        var midPoint = self.midPoint
        switch index {
        case 0: startPoint = point
        case 1: endPoint = point
        case 2: midPoint = point
        default: break
        }
        setParametersFromStartPoint(startPoint, endPoint: endPoint, midPoint: midPoint)
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextBeginPath(context)
        CGContextAddArc(context, origin.x, origin.y, radius, startAngle, endAngle, clockwise ? 1 : 0)
        CGContextStrokePath(context)
    }
    
    func pointOnArc(point: CGPoint) -> Bool {
        if point.distanceToPoint(origin) > radius + 0.001 {
            //print("point \(point) too far: distance = \(point.distanceToPoint(center)), radius = \(radius)")
            return false
        }
        let angle = (point - origin).angle
        if startAngle < endAngle {
            if angle >= startAngle && angle <= endAngle {
                return !clockwise
            } else {
                return clockwise
            }
        } else {
            if angle <= startAngle && angle >= endAngle {
                return clockwise
            } else {
                return !clockwise
            }
        }
    }
    
    override func moveBy(offset: CGPoint, view: SchematicView) {
        origin = origin + offset
    }
    
    override func rotateByAngle(angle: CGFloat, center: CGPoint) {
        origin = rotatePoint(origin, angle: angle, center: center)
        startAngle = normalizeAngle(startAngle + angle)
        endAngle = normalizeAngle(endAngle + angle)
    }

    override func closestPointToPoint(point: CGPoint) -> CGPoint {
        let scp = super.closestPointToPoint(point)
        let v = point - origin
        let cp = CGPoint(length: radius, angle: v.angle)
        if pointOnArc(cp) && cp.distanceToPoint(point) < scp.distanceToPoint(point) {
            return cp
        } else {
            return scp
        }
    }
    
    override func intersectionsWithLine(line: Line) -> [CGPoint] {
        return super.intersectionsWithLine(line).filter { pointOnArc($0) }
    }
}