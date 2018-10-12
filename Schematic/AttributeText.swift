//
//  AttributeText.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let AttributeFont =  NSFont(name: "Geneva", size: GridSize - 3) ?? NSFont.systemFont(ofSize: GridSize - 3)

class AttributeText: PrimitiveGraphic, NSTextFieldDelegate
{
    override class var supportsSecureCoding: Bool { return true }
    
    var _owner: AttributedGraphic?
    var owner: AttributedGraphic? {
        get { return _owner }
        set {
            _ = _owner?.attributeTexts.remove(self)
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
    
    var textAttributes: [NSAttributedStringKey : Any]? {
        if printInColor || NSGraphicsContext.currentContextDrawingToScreen() {
            return [NSAttributedStringKey(rawValue: NSAttributedStringKey.foregroundColor.rawValue): color, NSAttributedStringKey(rawValue: NSAttributedStringKey.font.rawValue): font]
        } else {
            return [NSAttributedStringKey(rawValue: NSAttributedStringKey.font.rawValue): font]
        }
    }
    
    override var inspectables: [Inspectable] {
        get {
            return [
                Inspectable(name: "color", type: .color),
                Inspectable(name: "format", type: .string),
                Inspectable(name: "string", type: .string, displayName: "value"),
                Inspectable(name: "angle", type: .angle),
                Inspectable(name: "overbar", type: .bool)
            ]
        }
        set {}
    }
    
    override var inspectionName: String     { return "AttributeText" }
    
    var string: NSString {
        get {
            if let owner = owner {
                return owner.formatAttribute(format) as NSString
            }
            return format as NSString
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
    var textSize: CGSize            { return string.size(withAttributes: textAttributes) }
    var textBounds: CGRect {
        if let bounds = cachedBounds {
            return bounds
        }
        let bounds = CGRect(origin: origin, size: textSize).rotatedAroundPoint(origin, angle: angle)
        cachedBounds = bounds
        return bounds
    }
    
    override var bounds: CGRect     {
        if let owner = owner, selected {
            return textBounds + owner.graphicBounds
        }
        return textBounds
    }
    var size: CGSize                { return textBounds.size }
    
    override var selectBounds: CGRect   { return textBounds }

    override var centerPoint: CGPoint { return textBounds.center }
    
    override var selected: Bool {
        didSet {
            NSFontPanel.shared.setPanelFont(font, isMultiple: false)
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
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        return nil
    }
    
    required init?(coder decoder: NSCoder) {
        format = decoder.decodeObject(of: NSString.self, forKey: "format") as String? ?? ""
        angle = decoder.decodeCGFloatForKey("angle")
        _owner = decoder.decodeObject(of: AttributedGraphic.self, forKey: "owner")
        overbar = decoder.decodeBool(forKey: "overbar")
        if let fontName = decoder.decodeObject(of: NSString.self, forKey: "fontName") as String? {
            self.fontSize = decoder.decodeCGFloatForKey("fontSize")
            self.fontName = fontName
        }
        super.init(coder: decoder)
        if let fontName = fontName {
            font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
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
    
    override func encode(with coder: NSCoder) {
        coder.encode(format, forKey: "format")
        coder.encodeCGFloat(angle, forKey: "angle")
        coder.encode(owner, forKey: "owner")
        coder.encode(overbar, forKey: "overbar")
        if let fontName = fontName {
            coder.encode(fontName, forKey: "fontName")
            coder.encodeCGFloat(fontSize, forKey: "fontSize")
        }
        super.encode(with: coder)
    }
    
    override func closestPointToPoint(_ point: CGPoint) -> CGPoint {
        if bounds.contains(point) {
            return point
        }
        return origin
    }
    
    override func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if bounds.contains(point) {
            return .hitsOn(self)
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
    
    override func moveBy(_ offset: CGPoint) {
        super.moveBy(offset)
        invalidateDrawing()
    }
    
    override func rotateByAngle(_ angle: CGFloat, center: CGPoint) {
        self.angle += angle
        if self.angle > PI { self.angle -= 2 * PI }
        if self.angle < -PI { self.angle += 2 * PI }
        origin = rotatePoint(origin, angle: angle, center: center)
    }
        
    override func showHandles() {
        let context = NSGraphicsContext.current?.cgContext
        
        context?.saveGState()
        context?.setLineWidth(0.1)
        setDrawingColor(NSColor.red)
        context?.stroke(textBounds)
        if let owner = owner {
            let cp = owner.graphicBounds.center
            context?.beginPath()
            context?.__moveTo(x: centerPoint.x, y: centerPoint.y)
            context?.__addLineTo(x: cp.x, y: cp.y)
            context?.strokePath()
        }
        context?.restoreGState()
    }
    
    override func draw() {
        let context = NSGraphicsContext.current?.cgContext
        let size = string.size(withAttributes: textAttributes)
        if angle == 0 {                                                     // this really didn't seem to do much...
            string.draw(at: origin, withAttributes: textAttributes)
            if overbar {
                let l = bounds.topLeft
                let r = bounds.topRight
                context?.beginPath()
                context?.__moveTo(x: l.x, y: l.y)
                context?.__addLineTo(x: r.x, y: r.y)
                context?.strokePath()
            }
        } else {
            context?.saveGState()
            context?.translateBy(x: origin.x, y: origin.y)
            context?.rotate(by: angle)

            string.draw(at: CGPoint(), withAttributes: textAttributes)
            
            if overbar {
                
                context?.beginPath()
                context?.setLineWidth(1.0)
                context?.__moveTo(x: 0, y: size.height)
                context?.__addLineTo(x: size.width, y: size.height)
                context?.strokePath()
            }
            context?.restoreGState()
        }
    }
}

