//
//  RectGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class RectGraphic: PrimitiveGraphic
{
    var size: CGSize {
        willSet {
            willChangeValueForKey("width")
            willChangeValueForKey("height")
        }
        didSet {
            didChangeValueForKey("width")
            didChangeValueForKey("height")
        }
    }
    
    var rect: CGRect {
        get { return CGRect(origin: origin, size: size) }
        set { origin = newValue.origin; size = newValue.size }
    }
    
    var width: CGFloat {
        get { return size.width }
        set { size.width = newValue }
    }
    
    var height: CGFloat {
        get { return size.height }
        set { size.height = newValue }
    }
    
    override var bounds: CGRect  { return rect + super.bounds }
    override var points: [CGPoint] {
        get { return [rect.origin, rect.topLeft, rect.topRight, rect.bottomRight] }
    }
    
    override var centerPoint: CGPoint { return rect.center }
    
    override var inspectables: [Inspectable] {
        return super.inspectables + [
            Inspectable(name: "width", type: .Float),
            Inspectable(name: "height", type: .Float)
        ]
    }
    
    override var json: JSON {
        var json = super.json
        json["__class__"] = "RectGraphic"
        json["size"] = JSON(["width": JSON(width), "height": JSON(height)])
        return json
    }
    
    override var inspectionName: String     { return "Rectangle" }

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
    
    override init(json: JSON) {
        size = CGSize(width: CGFloat(json["size", "width"].doubleValue), height: CGFloat(json["size", "height"].doubleValue))
        super.init(json: json)
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
    
    override func rotateByAngle(angle: CGFloat, center: CGPoint) {
        rect = rect.rotatedAroundPoint(center, angle: angle)
    }
    
    override func moveBy(offset: CGPoint, view: SchematicView) {
        origin = origin + offset
    }
    
    override func scaleFromRect(fromRect: CGRect, toRect: CGRect) {
        let origin = scalePoint(self.origin, fromRect: fromRect, toRect: toRect)
        let topRight = scalePoint(rect.topRight, fromRect: fromRect, toRect: toRect)
        rect = rectContainingPoints([origin, topRight])
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
            return .HitsOn(self)
        }
        return nil
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextStrokeRect(context, rect)
    }
}
