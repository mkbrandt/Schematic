//
//  RectGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class RectGraphic: SCHGraphic
{
    var size: CGSize
    
    var rect: CGRect {
        get { return CGRect(origin: origin, size: size) }
        set { origin = newValue.origin; size = newValue.size }
    }
    
    var lines: [LineGraphic] {
        return [
            LineGraphic(origin: origin, endPoint: rect.topLeft),
            LineGraphic(origin: rect.topLeft, endPoint: rect.topRight),
            LineGraphic(origin: rect.topRight, endPoint: rect.bottomRight),
            LineGraphic(origin: origin, endPoint: rect.bottomRight)
        ]
    }
    
    override var bounds: CGRect  { return rect + super.bounds }
    override var points: [CGPoint] {
        get { return [rect.origin, rect.topLeft, rect.topRight, rect.bottomRight] }
    }
    
    override var inspectables: [Inspectable] {
        get {
            return super.inspectables + [
                Inspectable(name: "width", type: .Float),
                Inspectable(name: "height", type: .Float)
            ]
        }
        set {}
    }

    init(origin: CGPoint, size: CGSize) {
        self.size = size
        super.init(origin: origin)
    }
    
    convenience init(rect: CGRect) {
        self.init(origin: rect.origin, size: rect.size)
    }
    
    required init?(coder decoder: NSCoder) {
        size = decoder.decodeSizeForKey("size")
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeSize(size, forKey: "size")
        super.encodeWithCoder(coder)
    }
    
    override func setPoint(point: CGPoint, index: Int) {
        switch index {
        case 0:
            rect = rectContainingPoints([point, rect.topRight])
        case 1:
            rect = rectContainingPoints([point, rect.bottomRight])
        case 2:
            rect = rectContainingPoints([point, origin])
        case 3:
            rect = rectContainingPoints([point, rect.topLeft])
        default:
            break
        }
    }
    
    override func intersectsRect(rect: CGRect) -> Bool {
        return self.rect.intersects(rect) && !self.rect.contains(rect)
    }
    
    override func hitTest(point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if let ht = super.hitTest(point, threshold: threshold) {
            return ht
        }
        if ((abs(point.x - rect.left) < threshold || abs(point.x - rect.right) < threshold)) && rect.bottom <= point.y && point.y <= rect.top
        || ((abs(point.y - rect.top) < threshold || abs(point.y - rect.bottom) < threshold)) && rect.left <= point.x && point.x <= rect.right {
            return .HitsOn
        }
        return nil
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextStrokeRect(context, rect)
    }
}
