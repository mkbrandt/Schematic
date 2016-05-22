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
    case String, Int, Float, Bool, Angle, Color, Attribute
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

class Graphic: NSObject, NSCoding, NSPasteboardReading, NSPasteboardWriting
{
    var origin: CGPoint
    var color: NSColor = NSColor.blackColor()
    var lineWeight: CGFloat = 1.0
    var selected = false
    
    var points: [CGPoint] {
        get { return [origin] }
    }
    
    var centerPoint: CGPoint   { return origin }
    
    var bounds: CGRect {
        return CGRect(origin: origin, size: CGSize(width: 1, height: 1))
    }
    
    var inspectables: [Inspectable] {
        get {
            return [
                Inspectable(name: "color", type: .Color),
                Inspectable(name: "lineWeight", type: .Float)
            ]
        }
        set { }
    }
    
    var elements: [Graphic] { return [] }
    
    var inspectionName: String      { return "Graphic" }
    
    init(origin: CGPoint) {
        self.origin = origin
        super.init()
    }
    
    required init?(coder decoder: NSCoder) {
        origin = decoder.decodePointForKey("origin")
        color = decoder.decodeObjectForKey("color") as? NSColor ?? NSColor.blackColor()
        lineWeight = decoder.decodeCGFloatForKey("lineWeight")
        super.init()
    }
    
    func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(color, forKey: "color")
        coder.encodePoint(origin, forKey: "origin")
        coder.encodeCGFloat(lineWeight, forKey: "lineWeight")
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
    
    // MARK: Selection
    
    func intersectsRect(rect: CGRect) -> Bool {
        return bounds.intersects(rect)
    }
    
    func moveBy(offset: CGPoint) {
        origin = origin + offset
    }
    
    func moveTo(location: CGPoint) {
        let offset = location - origin
        moveBy(offset)
    }
    
    func moveTo(location: CGPoint, view: SchematicView) {
        let p = origin
        moveTo(location)
        view.undoManager?.registerUndoWithTarget(self) { (g) in
            g.moveTo(p, view: view)
            view.needsDisplay = true
        }
    }
    
    func elementAtPoint(point: CGPoint) -> Graphic? {
        for el in elements {
            if el.bounds.contains(point - origin) {
                return el.elementAtPoint(point - origin)
            }
        }
        if bounds.contains(point) {
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
    
    // MARK: Drawing
    
    func drawInRect(rect: CGRect, view: SchematicView) {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextSaveGState(context)
        CGContextSetLineWidth(context, lineWeight)
        if intersectsRect(rect) {
            color.set()
            draw()
        }
        if selected {
            showHandlesInView(view)
        }
        CGContextRestoreGState(context)
    }
    
    func draw() {
    }
    
    func drawPoint(point: CGPoint, color: NSColor, view: SchematicView) {
        let hsize = max(view.scaleFloat(6.0), 6.0)
        let rect = CGRect(x: point.x - hsize / 2, y: point.y - hsize / 2, width: hsize, height: hsize)
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextSaveGState(context)
        color.set()
        CGContextFillRect(context, rect)
        CGContextRestoreGState(context)
    }
    
    func showHandlesInView(view: SchematicView) {
        points.forEach {
            drawPoint($0, color: NSColor.blackColor(), view: view)
        }
    }
}
