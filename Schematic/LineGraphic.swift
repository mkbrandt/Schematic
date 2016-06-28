//
//  LineGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class LineState: GraphicState {
    var endPoint: CGPoint
    
    init(origin: CGPoint, endPoint: CGPoint) {
        self.endPoint = endPoint
        super.init(origin: origin)
    }
}

class LineGraphic: PrimitiveGraphic
{
    var endPoint: CGPoint {
        willSet {
            willChangeValue(forKey: "angle")
            willChangeValue(forKey: "length")
        }
        didSet {
            didChangeValue(forKey: "angle")
            didChangeValue(forKey: "length")
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
        return super.inspectables + [
            Inspectable(name: "angle", type: .angle),
            Inspectable(name: "length", type: .float)
        ]
    }
    
    override var state: GraphicState {
        get { return LineState(origin: origin, endPoint: endPoint) }
        set {
            if let newValue = newValue as? LineState {
                (origin, endPoint) = (newValue.origin, newValue.endPoint)
            }
        }
    }
    
    override var inspectionName: String     { return "Line" }
    
    override var json: JSON {
        var json = super.json
        json["__class__"] = "LineGraphic"
        json["endPoint"] = endPoint.json
        return json
    }
    
    init(origin: CGPoint, endPoint: CGPoint) {
        self.endPoint = endPoint
        super.init(origin: origin)
    }
    
    override init(json: JSON) {
        endPoint = CGPoint(json: json["endPoint"])
        super.init(json: json)
    }
    
    convenience init(origin: CGPoint, vector: CGPoint) {
        self.init(origin: origin, endPoint: origin + vector)
    }
    
    required init?(coder decoder: NSCoder) {
        endPoint = decoder.decodePoint(forKey: "endPoint")
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(endPoint, forKey: "endPoint")
        super.encode(with: coder)
    }
    
    override func setPoint(_ point: CGPoint, index: Int) {
        switch index {
        case 0:
            origin = point
        case 1:
            endPoint = point
        default:
            break
        }
    }
    
    func isParallelWith(_ line: LineGraphic) -> Bool {
        return self.line.isParallelWith(line.line)
    }
    
    func intersectionWithLine(_ line: LineGraphic, extendSelf: Bool, extendOther: Bool) -> CGPoint? {
        return self.line.intersectionWithLine(line.line, extendSelf: extendSelf, extendOther: extendOther)
    }
    
    func closestPointToPoint(_ point: CGPoint, extended: Bool = false) -> CGPoint {
        return line.closestPointToPoint(point, extended: extended)
    }
    
    func distanceToPoint(_ p: CGPoint, extended: Bool = false) -> CGFloat {
        let v = closestPointToPoint(p, extended: extended)
        
        return (p - v).length
    }

    func intersectionWithLine(_ line: LineGraphic) -> CGPoint? {
        return intersectionWithLine(line, extendSelf: false, extendOther: false)
    }
    
    func intersectsLine(_ line: LineGraphic) -> Bool {
        return intersectionWithLine(line) != nil
    }
    
    override func intersectsRect(_ rect: CGRect) -> Bool {
        return rect.contains(origin) || rect.contains(endPoint) || rect.lines.reduce(false, combine: { $0 || $1.intersectsLine(line) })
    }
    
    override func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if let ht = super.hitTest(point, threshold: threshold) {
            return ht
        }
        var v = endPoint - origin
        let v2 = point - origin
        v.length = v2.length
        if v.distanceToPoint(v2) < threshold {
            return .hitsOn(self)
        }
        return nil
    }
    
    override func moveBy(_ offset: CGPoint) {
        origin = origin + offset
        endPoint = endPoint + offset
    }
    
    override func draw() {
        let context = NSGraphicsContext.current()?.cgContext
        
        context?.beginPath()
        context?.moveTo(x: origin.x, y: origin.y)
        context?.addLineTo(x: endPoint.x, y: endPoint.y)
        context?.strokePath()
    }
}
