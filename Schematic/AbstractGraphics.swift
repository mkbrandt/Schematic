//
//  AbstractGraphics.swift
//  Schematic
//
//  Created by Matt Brandt on 5/20/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class Line
{
    var origin: CGPoint
    var endPoint: CGPoint

    var vector: CGPoint     { return endPoint - origin }
    
    var angle: CGFloat      {
        get { return vector.angle }
        set { endPoint = origin + CGPoint(length: length, angle: newValue) }
    }
    
    var length: CGFloat     {
        get { return vector.length }
        set { endPoint = origin + CGPoint(length: newValue, angle: angle) }
    }
    
    init(origin: CGPoint, endPoint: CGPoint) {
        self.origin = origin
        self.endPoint = endPoint
    }
    
    init(origin: CGPoint, vector: CGPoint) {
        self.origin = origin
        self.endPoint = origin + vector
    }
    
    func isParallelWith(line: Line) -> Bool {
        return abs(line.angle - angle) < 0.00001
            || abs(line.angle + angle) < 0.00001
    }
    
    func intersectionWithLine(line: Line, extendSelf: Bool, extendOther: Bool) -> CGPoint? {
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
    
    func containsPoint(point: CGPoint) -> Bool {
        return distanceToPoint(point) < 0.0001
    }
    
    func intersectionWithLine(line: Line) -> CGPoint? {
        return intersectionWithLine(line, extendSelf: false, extendOther: false)
    }
    
    func intersectsLine(line: Line) -> Bool {
        return intersectionWithLine(line) != nil
    }
    
    func intersectsRect(rect: CGRect) -> Bool {
        let r = CGRect(origin: rect.origin, size: rect.size)
        return rect.contains(origin) || rect.contains(endPoint) || r.lines.reduce(false, combine: { $0 || $1.intersectsLine(self) })
    }

}

extension CGRect
{
    var lines: [Line] {
        return [
            Line(origin: origin, endPoint: topLeft),
            Line(origin: topLeft, endPoint: topRight),
            Line(origin: topRight, endPoint: bottomRight),
            Line(origin: origin, endPoint: bottomRight)
        ]
    }
    
    func intersectionsWithLine(line: Line) -> [CGPoint] {
        return lines.flatMap { $0.intersectionWithLine(line) }
    }
}

