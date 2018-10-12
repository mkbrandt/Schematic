//
//  RectGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class RectState: GraphicState {
    var size: CGSize
    
    init(origin: CGPoint, size: CGSize) {
        self.size = size
        super.init(origin: origin)
    }
}

class RectGraphic: PrimitiveGraphic
{
    override class var supportsSecureCoding: Bool { return true }
    
   var size: CGSize {
        willSet {
            willChangeValue(forKey: "width")
            willChangeValue(forKey: "height")
        }
        didSet {
            didChangeValue(forKey: "width")
            didChangeValue(forKey: "height")
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
    
    override var state: GraphicState {
        get { return RectState(origin: origin, size: size) }
        set {
            if let newValue = newValue as? RectState {
                (origin, size) = (newValue.origin, newValue.size)
            }
        }
    }
    
    override var centerPoint: CGPoint { return rect.center }
    
    override var inspectables: [Inspectable] {
        return super.inspectables + [
            Inspectable(name: "width", type: .float),
            Inspectable(name: "height", type: .float)
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
        size = decoder.decodeSize(forKey: "size")
        super.init(coder: decoder)
    }
    
    override init(json: JSON) {
        size = CGSize(width: CGFloat(json["size", "width"].doubleValue), height: CGFloat(json["size", "height"].doubleValue))
        super.init(json: json)
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(size, forKey: "size")
        super.encode(with: coder)
    }
    
    override func setPoint(_ point: CGPoint, index: Int) {
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
    
    override func rotateByAngle(_ angle: CGFloat, center: CGPoint) {
        rect = rect.rotatedAroundPoint(center, angle: angle)
    }
    
    override func moveBy(_ offset: CGPoint) {
        origin = origin + offset
    }
    
    override func scaleFromRect(_ fromRect: CGRect, toRect: CGRect) {
        let origin = scalePoint(self.origin, fromRect: fromRect, toRect: toRect)
        let topRight = scalePoint(rect.topRight, fromRect: fromRect, toRect: toRect)
        rect = rectContainingPoints([origin, topRight])
    }
    
    override func intersectsRect(_ rect: CGRect) -> Bool {
        return self.rect.intersects(rect) && !self.rect.contains(rect)
    }
    
    override func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if let ht = super.hitTest(point, threshold: threshold) {
            return ht
        }
        if ((abs(point.x - rect.left) < threshold || abs(point.x - rect.right) < threshold)) && rect.bottom <= point.y && point.y <= rect.top
        || ((abs(point.y - rect.top) < threshold || abs(point.y - rect.bottom) < threshold)) && rect.left <= point.x && point.x <= rect.right {
            return .hitsOn(self)
        }
        return nil
    }
    
    override func draw() {
        let context = NSGraphicsContext.current?.cgContext
        
        context?.stroke(rect)
    }
}
