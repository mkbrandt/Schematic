//
//  CircleGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class CircleGraphic: SCHGraphic
{
    var radius: CGFloat
    
    override var bounds: CGRect     { return CGRect(x: origin.x - radius, y: origin.y - radius, width: 2 * radius, height: 2 * radius) }
    override var points: [CGPoint]  { return [origin, origin + CGPoint(x: radius, y: 0)] }
    
    override var inspectables: [Inspectable] {
        get {
            return super.inspectables + [
                Inspectable(name: "radius", type: .Float)
            ]
        }
        set {}
    }
    
    init(origin: CGPoint, radius: CGFloat) {
        self.radius = radius
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        radius = decoder.decodeCGFloatForKey("radius")
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeCGFloat(radius, forKey: "radius")
        super.encodeWithCoder(coder)
    }
    
    override func setPoint(point: CGPoint, index: Int) {
        switch index {
        case 0:
            origin = point
        case 1:
            radius = origin.distanceToPoint(point)
        default:
            break
        }
    }
    
    override func hitTest(point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if let ht = super.hitTest(point, threshold: threshold) {
            return ht
        }
        if abs(radius - point.distanceToPoint(origin)) < threshold {
            return .HitsOn
        }
        return nil
    }
    
    func intersectsLine(line: LineGraphic) -> Bool {
        return line.distanceToPoint(origin) <= radius && (line.origin.distanceToPoint(origin) >= radius || line.endPoint.distanceToPoint(origin) > radius)
    }
    
    override func intersectsRect(rect: CGRect) -> Bool {
        return rect.contains(bounds) || RectGraphic(rect: rect).lines.reduce(false, combine: { $0 || intersectsLine($1) })
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextStrokeEllipseInRect(context, bounds)
    }
}
