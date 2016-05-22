//
//  LineGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class LineGraphic: Graphic
{
    var endPoint: CGPoint {
        willSet {
            willChangeValueForKey("angle")
            willChangeValueForKey("length")
        }
        didSet {
            didChangeValueForKey("angle")
            didChangeValueForKey("length")
        }
    }
    
    var vector: CGPoint     { return endPoint - origin }
    
    var angle: CGFloat      {
        get { return vector.angle }
        set { endPoint = origin + CGPoint(length: length, angle: newValue) }
    }
    
    var length: CGFloat     {
        get { return vector.length }
        set { endPoint = origin + CGPoint(length: newValue, angle: angle) }
    }
    
    override var bounds: CGRect  { return rectContainingPoints(points) }
    
    var line: Line { return Line(origin: origin, endPoint: endPoint) }
    
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
    
    override var inspectionName: String     { return "Line" }
    
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
        return self.line.isParallelWith(line.line)
    }
    
    func intersectionWithLine(line: LineGraphic, extendSelf: Bool, extendOther: Bool) -> CGPoint? {
        return self.line.intersectionWithLine(line.line, extendSelf: extendSelf, extendOther: extendOther)
    }
    
    func closestPointToPoint(point: CGPoint, extended: Bool = false) -> CGPoint {
        return line.closestPointToPoint(point, extended: extended)
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
        return rect.contains(origin) || rect.contains(endPoint) || rect.lines.reduce(false, combine: { $0 || $1.intersectsLine(line) })
    }
    
    override func hitTest(point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if let ht = super.hitTest(point, threshold: threshold) {
            return ht
        }
        var v = endPoint - origin
        let v2 = point - origin
        v.length = v2.length
        if v.distanceToPoint(v2) < threshold {
            return .HitsOn(self)
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
