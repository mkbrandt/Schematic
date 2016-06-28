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
    case hitsPoint(Graphic, Int)
    case hitsOn(Graphic)
}

enum InspectionType {
    case string, int, float, bool, angle, color
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

class GraphicState {
    var origin: CGPoint
    
    init(origin: CGPoint) {
        self.origin = origin
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
    
    var state: GraphicState {
        get { return GraphicState(origin: origin) }
        set { origin = newValue.origin }
    }
    
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
        origin = decoder.decodePoint(forKey: "origin")
        graphicID = nextGraphicID
        super.init()
    }
    
    func encode(with coder: NSCoder) {
        coder.encode(origin, forKey: "origin")
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("fuck me")
    }
    
    static func readableTypes(for pasteboard: NSPasteboard) -> [String] {
        return [SchematicElementUTI]
    }
    
    func writableTypes(for pasteboard: NSPasteboard) -> [String] {
        return [SchematicElementUTI]
    }
    
    func pasteboardPropertyList(forType type: String) -> AnyObject? {
        return NSKeyedArchiver.archivedData(withRootObject: self)
    }
    
    static func readingOptions(forType type: String, pasteboard: NSPasteboard) -> NSPasteboardReadingOptions {
        return NSPasteboardReadingOptions.asKeyedArchive
    }
    
    override func value(forUndefinedKey key: String) -> AnyObject? {
        switch key {
        case "inspectables": return inspectables
        default: return nil
        }
    }
    
    func isSettable(_ key: String) -> Bool {
        return true
    }
    
    // MARK: Setting Points
    
    func setPoint(_ point: CGPoint, index: Int) {
        if index == 0 {
            origin = point
        }
    }
    
    func setPoint(_ point: CGPoint, index: Int, view: SchematicView) {
        let p = points[index]
        setPoint(point, index: index)
        view.undoManager?.registerUndoWithTarget(self) { (g) in
            g.setPoint(p, index: index, view: view)
            view.needsDisplay = true
        }
    }
    
    func scalePoint(_ point: CGPoint, fromRect: CGRect, toRect: CGRect) -> CGPoint {
        let hscale = toRect.size.width / fromRect.size.width
        let vscale = toRect.size.height / fromRect.size.height
        let offset = point - fromRect.origin
        let scaledOffset = CGPoint(x: offset.x * hscale, y: offset.y * vscale)
        
        return toRect.origin + scaledOffset
    }
    
    func scaleFromRect(_ fromRect: CGRect, toRect: CGRect) {
        for i in 0 ..< points.count {
            let p = scalePoint(points[i], fromRect: fromRect, toRect: toRect)
            
            setPoint(p, index: i)
        }
    }
    
    func rotatePoint(_ point: CGPoint, angle: CGFloat, center: CGPoint) -> CGPoint {
        let v = point - center
        return center + CGPoint(length: v.length, angle: v.angle + angle)
    }
    
    func rotateByAngle(_ angle: CGFloat, center: CGPoint) {
        let pts = points.map { rotatePoint($0, angle: angle, center: center) }
        for i in 0 ..< points.count {
            setPoint(pts[i], index: i)
        }
    }
    
    func flipHorizontalAroundPoint(_ center: CGPoint) {
        let pv = points.map { $0 - center }
        let fv = pv.map { return CGPoint(x: -$0.x, y: $0.y) }
        for i in 0 ..< points.count {
            setPoint(fv[i] + center, index: i)
        }
    }
    
    func flipVerticalAroundPoint(_ center: CGPoint) {
        let pv = points.map { $0 - center }
        let fv = pv.map { return CGPoint(x: $0.x, y: -$0.y) }
        for i in 0 ..< points.count {
            setPoint(fv[i] + center, index: i)
        }
    }
    
    func designCheck(_ view: SchematicView) {
    }
    
    // MARK: Selection
    
    func intersectsRect(_ rect: CGRect) -> Bool {
        for el in elements {
            if el.intersectsRect(rect) {
                return true
            }
        }
        return bounds.intersects(rect)
    }
    
    func restoreUndo(state: GraphicState, view: SchematicView) {
        view.setNeedsDisplay(bounds.insetBy(dx: -5, dy: -5))
        let oldState = self.state
        self.state = state
        view.undoManager?.registerUndoWithTarget(self, handler: { (_) in
            self.restoreUndo(state: oldState, view: view)
        })
        view.setNeedsDisplay(bounds.insetBy(dx: -5, dy: -5))
    }

    func saveUndoState(view: SchematicView) {
        let state = self.state
        view.undoManager?.registerUndoWithTarget(self, handler: { (_) in
            self.restoreUndo(state: state, view: view)
        })
    }
    
    func moveBy(_ offset: CGPoint) {
        origin = origin + offset
    }
        
    func moveTo(_ location: CGPoint) {
        moveBy(location - origin)
    }
    
    func elementAtPoint(_ point: CGPoint) -> Graphic? {
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
    
    func closestPointToPoint(_ point: CGPoint) -> CGPoint {
        return origin
    }
    
    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        for index in 0 ..< points.count {
            let p = points[index]
            if p.distanceToPoint(point) < threshold {
                return .hitsPoint(self, index)
            }
        }
        return nil
    }
    
    func unlink(_ view: SchematicView) {
        // do anything necessary to delete the graphic from the drawing
    }
    
    // MARK: Drawing
    
    func drawInRect(_ rect: CGRect) {
        draw()
        if selected {
            showHandles()
        }
    }
    
    func setDrawingColor(_ color: NSColor) {
        if printInColor || NSGraphicsContext.currentContextDrawingToScreen() {
            color.set()
        } else {
            print("drawing color not set")
        }
    }
    
    func draw() {
    }
    
    func drawPoint(_ point: CGPoint, color: NSColor) {
        let context = NSGraphicsContext.current()?.cgContext
        let unit = context?.convertToDeviceSpace(CGSize(width: 1, height: 1))
        let hsize = 8.0 / (unit?.width)!
        let isize = 6.0 / (unit?.width)!
        let rect = CGRect(x: point.x - hsize / 2, y: point.y - hsize / 2, width: hsize, height: hsize)
        let irect = CGRect(x: point.x - isize / 2, y: point.y - isize / 2, width: isize, height: isize)
        
        context?.saveGState()
        if unit?.width > 1 {
            NSColor.white().set()
            context?.fill(rect)
            setDrawingColor(color)
            context?.fill(irect)
        } else {
            setDrawingColor(color)
            context?.fill(irect)
        }
        context?.restoreGState()
    }
    
    func showHandles() {
        points.forEach {
            drawPoint($0, color: NSColor.black())
        }
    }
}
