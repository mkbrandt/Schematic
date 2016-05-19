//
//  ArcGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class ArcGraphic: SCHGraphic
{
    var radius: CGFloat
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
    
    init(origin: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {
        self.radius = radius
        self.startAngle = startAngle
        self.endAngle = endAngle
        self.clockwise = clockwise
        super.init(origin: origin)
    }
    
    convenience init?(startPoint: CGPoint, endPoint: CGPoint, midPoint: CGPoint) {
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
            let clockwise = true
            self.init(origin: origin, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
            self.clockwise = pointOnArc(midPoint)
        } else {
            return nil
        }
    }

    required init?(coder decoder: NSCoder) {
        radius = decoder.decodeCGFloatForKey("radius")
        startAngle = decoder.decodeCGFloatForKey("startAngle")
        endAngle = decoder.decodeCGFloatForKey("endAngle")
        clockwise = decoder.decodeBoolForKey("clockwise")
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        return nil
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeCGFloat(radius, forKey: "radius")
        coder.encodeCGFloat(startAngle, forKey: "startAngle")
        coder.encodeCGFloat(endAngle, forKey: "endAngle")
        coder.encodeBool(clockwise, forKey: "clockwise")
        super.encodeWithCoder(coder)
    }
    
    override func setPoint(point: CGPoint, index: Int) {
        var ag: ArcGraphic?
        switch index {
        case 0:
            ag = ArcGraphic(startPoint: point, endPoint: endPoint, midPoint: midPoint)
        case 1:
            ag = ArcGraphic(startPoint: startPoint, endPoint: point, midPoint: midPoint)
        case 2:
            ag = ArcGraphic(startPoint: startPoint, endPoint: endPoint, midPoint: point)
        default:
            break
        }
        if let ag = ag {
            origin = ag.origin
            radius = ag.radius
            startAngle = ag.startAngle
            endAngle = ag.endAngle
            clockwise = ag.clockwise
        }
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

}