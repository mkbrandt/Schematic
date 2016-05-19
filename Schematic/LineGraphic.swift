//
//  LineGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class LineGraphic: SCHGraphic
{
    var endPoint: CGPoint
    var vector: CGPoint     { return endPoint - origin }
    var angle: CGFloat      { return vector.angle }
    var length: CGFloat     { return vector.length }
    
    override var bounds: CGRect  { return rectContainingPoints(points) }
    
    override var points: [CGPoint] {
        get { return [origin, endPoint] }
    }
    
    override var inspectables: [Inspectable] {
        get {
            return super.inspectables + [
                Inspectable(name: "angle", type: .Angle),
                Inspectable(name: "length", type: .Float)
            ]
        }
        set {}
    }
    
    init(origin: CGPoint, endPoint: CGPoint) {
        self.endPoint = endPoint
        super.init(origin: origin)
    }
    
    convenience init(origin: CGPoint, vector: CGPoint) {
        self.init(origin: origin, endPoint: origin + vector)
    }
    
    required init?(coder decoder: NSCoder) {
        endPoint = decoder.decodePointForKey("endPoint")
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodePoint(endPoint, forKey: "endPoint")
        super.encodeWithCoder(coder)
    }
    
    override func setPoint(point: CGPoint, index: Int) {
        switch index {
        case 0:
            origin = point
        case 1:
            endPoint = point
        default:
            break
        }
    }
    
    func isParallelWith(line: LineGraphic) -> Bool {
        return abs(line.angle - angle) < 0.00001
            || abs(line.angle + angle) < 0.00001
    }
    
    func intersectionWithLine(line: LineGraphic, extendSelf: Bool, extendOther: Bool) -> CGPoint? {
        if isParallelWith(line) {
            return nil
        }
        
        let p = origin
        let q = line.origin
        let r = vector
        let s = line.vector
        let rxs = crossProduct(r, s)
        if rxs == 0 {
            return nil
        }
        let t = crossProduct((q - p), s) / rxs
        let u = crossProduct((q - p), r) / rxs
        
        if !extendSelf && (t < 0 || t > 1.0) || !extendOther && (u < 0 || u > 1.0) {
            return nil
        }
        
        return p + t * r
    }
    
    func closestPointToPoint(point: CGPoint, extended: Bool = false) -> CGPoint {
        let v2 = point - origin;
        
        let len = dotProduct(vector, v2) / vector.length
        let plen = vector.length
        if( !extended && len > plen )
        {
            return origin + vector
        }
        else if( !extended && len < 0 )
        {
            return origin;
        }
        
        let angle = vector.angle;
        var v = CGPoint(length: len, angle: angle)
        
        if vector.x == 0 {              // force vertical
            v.x = 0
        } else if vector.y == 0 {       // force horizontal
            v.y = 0
        }
        return origin + v;
    }
    
    func distanceToPoint(p: CGPoint, extended: Bool = false) -> CGFloat {
        let v = closestPointToPoint(p, extended: extended)
        
        return (p - v).length
    }

    func intersectionWithLine(line: LineGraphic) -> CGPoint? {
        return intersectionWithLine(line, extendSelf: false, extendOther: false)
    }
    
    func intersectsLine(line: LineGraphic) -> Bool {
        return intersectionWithLine(line) != nil
    }
    
    override func intersectsRect(rect: CGRect) -> Bool {
        let r = RectGraphic(origin: rect.origin, size: rect.size)
        return rect.contains(origin) || rect.contains(endPoint) || r.lines.reduce(false, combine: { $0 || $1.intersectsLine(self) })
    }
    
    override func hitTest(point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if let ht = super.hitTest(point, threshold: threshold) {
            return ht
        }
        var v = endPoint - origin
        let v2 = point - origin
        v.length = v2.length
        if v.distanceToPoint(v2) < threshold {
            return .HitsOn
        }
        return nil
    }
    
    override func moveBy(offset: CGPoint) {
        origin = origin + offset
        endPoint = endPoint + offset
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextBeginPath(context)
        CGContextMoveToPoint(context, origin.x, origin.y)
        CGContextAddLineToPoint(context, endPoint.x, endPoint.y)
        CGContextStrokePath(context)
    }
}
