//
//  Graphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let SchematicElementUTI = "net.walkingdog.schematic"

enum HitTestResult {
    case HitsPoint(Graphic, Int)
    case HitsOn(Graphic)
}

enum InspectionType {
    case String, Int, Float, Bool, Angle, Color
}

class Inspectable: NSObject {
    var name: String
    var displayName: String
    var type: InspectionType
    
    init(name: String, type: InspectionType, displayName: String? = nil) {
        self.name = name
        self.displayName = displayName ?? name
        self.type = type
        super.init()
    }
}

var _NextGraphicID = 0
var nextGraphicID: Int { _NextGraphicID += 1; return _NextGraphicID }

class Graphic: NSObject, NSCoding, NSPasteboardReading, NSPasteboardWriting
{
    var graphicID: Int
    
    var origin: CGPoint
    var selected = false
    
    var points: [CGPoint] {
        get { return [origin] }
    }
    
    var centerPoint: CGPoint   { return origin }
    
    var bounds: CGRect {
        return rectContainingPoints(points)
    }
    
    var selectBounds: CGRect    { return bounds }
    
    var inspectables: [Inspectable] { return [] }
    
    var elements: Set<Graphic> { return [] }
    
    var inspectionName: String      { return "Graphic" }
    
    var json: JSON  { return JSON(["origin": origin.json]) }
    
    init(origin: CGPoint) {
        self.origin = origin
        graphicID = nextGraphicID
        super.init()
    }
    
    init(json: JSON) {
        origin = CGPoint(json: json["origin"])
        graphicID = nextGraphicID
        super.init()
    }
    
    required init?(coder decoder: NSCoder) {
        origin = decoder.decodePointForKey("origin")
        graphicID = nextGraphicID
        super.init()
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodePoint(origin, forKey: "origin")
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("fuck me")
    }
    
    static func readableTypesForPasteboard(pasteboard: NSPasteboard) -> [String] {
        return [SchematicElementUTI]
    }
    
    func writableTypesForPasteboard(pasteboard: NSPasteboard) -> [String] {
        return [SchematicElementUTI]
    }
    
    func pasteboardPropertyListForType(type: String) -> AnyObject? {
        return NSKeyedArchiver.archivedDataWithRootObject(self)
    }
    
    static func readingOptionsForType(type: String, pasteboard: NSPasteboard) -> NSPasteboardReadingOptions {
        return NSPasteboardReadingOptions.AsKeyedArchive
    }
    
    override func valueForUndefinedKey(key: String) -> AnyObject? {
        switch key {
        case "inspectables": return inspectables
        default: return nil
        }
    }
    
    func isSettable(key: String) -> Bool {
        return true
    }
    
    // MARK: Setting Points
    
    func setPoint(point: CGPoint, index: Int) {
        if index == 0 {
            origin = point
        }
    }
    
    func setPoint(point: CGPoint, index: Int, view: SchematicView) {
        let p = points[index]
        setPoint(point, index: index)
        view.undoManager?.registerUndoWithTarget(self) { (g) in
            g.setPoint(p, index: index, view: view)
            view.needsDisplay = true
        }
    }
    
    func scalePoint(point: CGPoint, fromRect: CGRect, toRect: CGRect) -> CGPoint {
        let hscale = toRect.size.width / fromRect.size.width
        let vscale = toRect.size.height / fromRect.size.height
        let offset = point - fromRect.origin
        let scaledOffset = CGPoint(x: offset.x * hscale, y: offset.y * vscale)
        
        return toRect.origin + scaledOffset
    }
    
    func scaleFromRect(fromRect: CGRect, toRect: CGRect) {
        for i in 0 ..< points.count {
            let p = scalePoint(points[i], fromRect: fromRect, toRect: toRect)
            
            setPoint(p, index: i)
        }
    }
    
    func rotatePoint(point: CGPoint, angle: CGFloat, center: CGPoint) -> CGPoint {
        let v = point - center
        return center + CGPoint(length: v.length, angle: v.angle + angle)
    }
    
    func rotateByAngle(angle: CGFloat, center: CGPoint) {
        let pts = points.map { rotatePoint($0, angle: angle, center: center) }
        for i in 0 ..< points.count {
            setPoint(pts[i], index: i)
        }
    }
    
    func flipHorizontalAroundPoint(center: CGPoint) {
        let pv = points.map { $0 - center }
        let fv = pv.map { return CGPoint(x: -$0.x, y: $0.y) }
        for i in 0 ..< points.count {
            setPoint(fv[i] + center, index: i)
        }
    }
    
    func flipVerticalAroundPoint(center: CGPoint) {
        let pv = points.map { $0 - center }
        let fv = pv.map { return CGPoint(x: $0.x, y: -$0.y) }
        for i in 0 ..< points.count {
            setPoint(fv[i] + center, index: i)
        }
    }
    
    func designCheck(view: SchematicView) {
    }
    
    // MARK: Selection
    
    func intersectsRect(rect: CGRect) -> Bool {
        for el in elements {
            if el.intersectsRect(rect) {
                return true
            }
        }
        return bounds.intersects(rect)
    }
    
    func moveBy(offset: CGPoint, view: SchematicView) {
        view.setNeedsDisplayInRect(bounds)
        origin = origin + offset
       view.setNeedsDisplayInRect(bounds)
    }
        
    func moveTo(location: CGPoint, view: SchematicView) {
        let p = origin
        let offset = location - origin
        moveBy(offset, view: view)
        view.undoManager?.registerUndoWithTarget(self) { (g) in
            g.moveTo(p, view: view)
            view.needsDisplay = true
        }
    }
    
    func elementAtPoint(point: CGPoint) -> Graphic? {
        for el in elements {
            if el.selectBounds.contains(point) {
                return el.elementAtPoint(point)
            }
        }
        if selectBounds.contains(point) {
            return self
        }
        return nil
    }
    
    func closestPointToPoint(point: CGPoint) -> CGPoint {
        return origin
    }
    
    func hitTest(point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        for index in 0 ..< points.count {
            let p = points[index]
            if p.distanceToPoint(point) < threshold {
                return .HitsPoint(self, index)
            }
        }
        return nil
    }
    
    func unlink(view: SchematicView) {
        // do anything necessary to delete the graphic from the drawing
    }
    
    // MARK: Drawing
    
    func drawInRect(rect: CGRect) {
        draw()
        if selected {
            showHandles()
        }
    }
    
    func draw() {
    }
    
    func drawPoint(point: CGPoint, color: NSColor) {
        let context = NSGraphicsContext.currentContext()?.CGContext
        let unit = CGContextConvertSizeToDeviceSpace(context, CGSize(width: 1, height: 1))
        let hsize = 8.0 / unit.width
        let isize = 6.0 / unit.width
        let rect = CGRect(x: point.x - hsize / 2, y: point.y - hsize / 2, width: hsize, height: hsize)
        let irect = CGRect(x: point.x - isize / 2, y: point.y - isize / 2, width: isize, height: isize)
        
        CGContextSaveGState(context)
        if unit.width > 1 {
            NSColor.whiteColor().set()
            CGContextFillRect(context, rect)
            color.set()
            CGContextFillRect(context, irect)
        } else {
            color.set()
            CGContextFillRect(context, irect)
        }
        CGContextRestoreGState(context)
    }
    
    func showHandles() {
        points.forEach {
            drawPoint($0, color: NSColor.blackColor())
        }
    }
}
