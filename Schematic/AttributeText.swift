//
//  AttributeText.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let AttributeFont =  NSFont(name: "Geneva", size: GridSize - 3) ?? NSFont.systemFontOfSize(GridSize - 3)

class AttributeText: PrimitiveGraphic, NSTextFieldDelegate
{
    var _owner: AttributedGraphic?
    var owner: AttributedGraphic? {
        get { return _owner }
        set {
            _owner?.attributeTexts.remove(self)
            _owner = newValue
            _owner?._attributeTexts.insert(self)
        }
    }
        
    var format: String              { didSet { invalidateDrawing() }}
    var angle: CGFloat              { didSet { invalidateDrawing() }}
    var overbar: Bool = false       { didSet { invalidateDrawing() }}
    
    var font: NSFont = AttributeFont    {
        didSet {
            invalidateDrawing()
            fontName = font.fontName
            fontSize = font.pointSize
        }
    }
    
    var fontName: String?
    var fontSize: CGFloat = GridSize - 3
        
    override var description: String { return "Attribute(\(format))" }
    
    override var json: JSON {
        var json = super.json
        json["__class__"] = "AttributeText"
        json["format"] = JSON(format)
        json["angle"] = JSON(angle)
        json["overbar"] = JSON(overbar)
        return json
    }
    
    var textAttributes: [String: AnyObject] {
        if NSGraphicsContext.currentContextDrawingToScreen() {
            return [NSForegroundColorAttributeName: color, NSFontAttributeName: font]
        } else {
            return [NSFontAttributeName: font]
        }
    }
    
    override var inspectables: [Inspectable] {
        get {
            return [
                Inspectable(name: "color", type: .Color),
                Inspectable(name: "format", type: .String),
                Inspectable(name: "string", type: .String, displayName: "value"),
                Inspectable(name: "angle", type: .Angle),
                Inspectable(name: "overbar", type: .Bool)
            ]
        }
        set {}
    }
    
    override var inspectionName: String     { return "AttributeText" }
    
    var string: NSString {
        get {
            if let owner = owner {
                return owner.formatAttribute(format)
            }
            return format
        }
        set {
            invalidateDrawing()
            if format.hasPrefix("=") {
                if let name = owner?.stripPrefix(format) {
                    owner?.setAttribute(newValue as String, name: name)
                    return
                }
            }
            format = newValue as String
        }
    }

    var cachedBounds: CGRect?
    var textSize: CGSize            { return string.sizeWithAttributes(textAttributes) }
    var textBounds: CGRect {
        if let bounds = cachedBounds {
            return bounds
        }
        let bounds = CGRect(origin: origin, size: textSize).rotatedAroundPoint(origin, angle: angle)
        cachedBounds = bounds
        return bounds
    }
    
    override var bounds: CGRect     {
        if let owner = owner where selected {
            return textBounds + owner.graphicBounds
        }
        return textBounds
    }
    var size: CGSize                { return textBounds.size }
    
    override var selectBounds: CGRect   { return textBounds }

    override var centerPoint: CGPoint { return textBounds.center }
    
    override var selected: Bool {
        didSet {
            NSFontPanel.sharedFontPanel().setPanelFont(font, isMultiple: false)
        }
    }
    
    init(origin: CGPoint, format: String, angle: CGFloat = 0, owner: AttributedGraphic?) {
        self.format = format
        self.angle = angle
        self._owner = owner
        super.init(origin: origin)
        owner?._attributeTexts.insert(self)
    }
    
    convenience init(format: String) {
        self.init(origin: CGPoint(x: 0, y: 0), format: format, owner: nil)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        return nil
    }
    
    required init?(coder decoder: NSCoder) {
        format = decoder.decodeObjectForKey("format") as? String ?? ""
        angle = decoder.decodeCGFloatForKey("angle")
        _owner = decoder.decodeObjectForKey("owner") as? AttributedGraphic
        overbar = decoder.decodeBoolForKey("overbar")
        if let fontName = decoder.decodeObjectForKey("fontName") as? String {
            self.fontSize = decoder.decodeCGFloatForKey("fontSize")
            self.fontName = fontName
        }
        super.init(coder: decoder)
        if let fontName = fontName {
            font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFontOfSize(fontSize)
        }
    }
    
    convenience init(copy attr: AttributeText) {
        self.init(origin: attr.origin, format: attr.format as String, angle: attr.angle, owner: nil)
        overbar = attr.overbar
        color = attr.color
    }
    
    override init(json: JSON) {
        angle = CGFloat(json["angle"].doubleValue)
        format = json["format"].stringValue
        overbar = json["overbar"].boolValue
        super.init(json: json)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(format, forKey: "format")
        coder.encodeCGFloat(angle, forKey: "angle")
        coder.encodeObject(owner, forKey: "owner")
        coder.encodeBool(overbar, forKey: "overbar")
        if let fontName = fontName {
            coder.encodeObject(fontName, forKey: "fontName")
            coder.encodeCGFloat(fontSize, forKey: "fontSize")
        }
        super.encodeWithCoder(coder)
    }
    
    override func closestPointToPoint(point: CGPoint) -> CGPoint {
        if bounds.contains(point) {
            return point
        }
        return origin
    }
    
    override func hitTest(point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if bounds.contains(point) {
            return .HitsOn(self)
        }
        return nil
    }
    
    var distanceFromOwner: CGFloat = 0

    func invalidateDrawing() {
        cachedBounds = nil
        if let comp = owner as? Component {
            let dist = comp.origin.distanceToPoint(origin)
            if dist != distanceFromOwner {
                comp.cachedBounds = nil
                distanceFromOwner = dist
            }
        }
    }
    
    override func moveBy(offset: CGPoint, view: SchematicView) {
        super.moveBy(offset, view: view)
        invalidateDrawing()
    }
    
    override func rotateByAngle(angle: CGFloat, center: CGPoint) {
        self.angle += angle
        if self.angle > PI { self.angle -= 2 * PI }
        if self.angle < -PI { self.angle += 2 * PI }
        origin = rotatePoint(origin, angle: angle, center: center)
    }
        
    override func showHandles() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        
        CGContextSaveGState(context)
        CGContextSetLineWidth(context, 0.1)
        setDrawingColor(NSColor.redColor())
        CGContextStrokeRect(context, textBounds)
        if let owner = owner {
            let cp = owner.graphicBounds.center
            CGContextBeginPath(context)
            CGContextMoveToPoint(context, centerPoint.x, centerPoint.y)
            CGContextAddLineToPoint(context, cp.x, cp.y)
            CGContextStrokePath(context)
        }
        CGContextRestoreGState(context)
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        let size = string.sizeWithAttributes(textAttributes)
        if angle == 0 {                                                     // this really didn't seem to do much...
            string.drawAtPoint(origin, withAttributes: textAttributes)
            if overbar {
                let l = bounds.topLeft
                let r = bounds.topRight
                CGContextBeginPath(context)
                CGContextMoveToPoint(context, l.x, l.y)
                CGContextAddLineToPoint(context, r.x, r.y)
                CGContextStrokePath(context)
            }
        } else {
            CGContextSaveGState(context)
            CGContextTranslateCTM(context, origin.x, origin.y)
            CGContextRotateCTM(context, angle)

            string.drawAtPoint(CGPoint(), withAttributes: textAttributes)
            
            if overbar {
                
                CGContextBeginPath(context)
                CGContextSetLineWidth(context, 1.0)
                CGContextMoveToPoint(context, 0, size.height)
                CGContextAddLineToPoint(context, size.width, size.height)
                CGContextStrokePath(context)
            }
            CGContextRestoreGState(context)
        }
    }
}

