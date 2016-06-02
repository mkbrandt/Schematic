//
//  GroupGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class GroupGraphic: Graphic
{
    override var origin: CGPoint {
        get { return bounds.origin }
        set { moveTo(origin) }
    }
    var contents: Set<Graphic>
    
    var boundingRect: RectGraphic       { return RectGraphic(rect: bounds) }
    var allPoints: [CGPoint]            { return contents.reduce([], combine: { $0 + $1.points }) }

    override var bounds: CGRect         { return contents.reduce(CGRect(), combine: { $0 + $1.bounds }) }
    override var centerPoint: CGPoint   { return contents.reduce(CGPoint(), combine: { $0 + $1.centerPoint }) / CGFloat(contents.count) }
    override var points: [CGPoint]      { return boundingRect.points }

    override var inspectionName: String         { return "Group" }
    override var inspectables: [Inspectable]    { return [] }
    

    init(contents: Set<Graphic>) {
        self.contents = contents
        super.init(origin: CGPoint(x: 0, y: 0))
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    required init?(coder decoder: NSCoder) {
        contents = decoder.decodeObjectForKey("contents") as? Set<Graphic> ?? []
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(contents, forKey: "contents")
    }
    
    override func setPoint(point: CGPoint, index: Int) {
        let destRect = boundingRect
        destRect.setPoint(point, index: index)
        scaleFromRect(bounds, toRect: destRect.rect)
    }
    
    override func rotateByAngle(angle: CGFloat, center: CGPoint) {
        for g in contents {
            g.rotateByAngle(angle, center: center)
        }
    }
    
    override func intersectsRect(rect: CGRect) -> Bool {
        for g in contents {
            if g.intersectsRect(rect) {
                return true
            }
        }
        return false
    }
    
    override func hitTest(point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if let ht = super.hitTest(point, threshold: threshold) {
            return ht
        }
        for g in contents {
            if let ht = g.hitTest(point, threshold: threshold) {
                return ht
            }
        }
        return nil
    }
    
    override func moveBy(offset: CGPoint) -> CGRect {
        let b0 = bounds
        for g in contents {
            g.moveBy(offset)
        }
        return b0 + bounds
    }
    
    override func flipHorizontalAroundPoint(center: CGPoint) {
        for g in contents {
            g.flipHorizontalAroundPoint(center)
        }
    }
    
    override func flipVerticalAroundPoint(center: CGPoint) {
        for g in contents {
            g.flipVerticalAroundPoint(center)
        }
    }
    
    override func scaleFromRect(fromRect: CGRect, toRect: CGRect) {
        for g in contents {
            g.scaleFromRect(fromRect, toRect: toRect)
        }
    }
        
    override func drawInRect(rect: CGRect) {
        for g in contents {
            g.drawInRect(rect)
        }
        if selected {
            showHandles()
        }
    }
}
