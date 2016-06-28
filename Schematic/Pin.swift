//
//  Pin.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

enum PinOrientation: Int {
    case top, left, bottom, right
}

class Pin: AttributedGraphic
{
    weak var component: Component? {
        didSet {
            if let component = component {
                if !component.pins.contains(self) {
                    component.pins.insert(self)
                }
            }
        }
    }
    
    var node: Node?
    var hasConnection: Bool {
        if let node = node where node.attachments.count > 0 {
            return true
        }
        return false
    }
    
    var orientation: PinOrientation             { didSet { placeAttributes() }}
    var hasBubble: Bool = false
    var hasClockFlag: Bool = false
    
    override var json: JSON {
        var json = super.json
        json["__class__"] = "Pin"
        json["orientation"] = JSON(orientation.rawValue)
        json["hasBubble"] = JSON(hasBubble)
        json["hasClockFlag"] = JSON(hasClockFlag)
        return json
    }
    
    var pinName: String {
        get { return attributes["pinName"] ?? "" }
        set { attributes["pinName"] = newValue }
    }
        
    var pinNumber: String {
        get {return attributes["pinNumber"] ?? "" }
        set { attributes["pinNumber"] = newValue }
    }
    
    var netName: String? {
        let netNameAttributes = attributeTexts.flatMap({$0 as? NetNameAttributeText })
        return netNameAttributes.first?.netName
    }
    
    weak var pinNameText: AttributeText?        { return attributeTextsForAttribute("pinName").first }
    weak var pinNumberText: AttributeText?      { return attributeTextsForAttribute("pinNumber").first }
    
    override var origin: CGPoint                { didSet { placeAttributes() }}
    override var description: String            { return "Pin(\(pinName):\(pinNumber))" }
    
    var pinLength = GridSize * 1
    
    override var bounds: CGRect {
        return graphicBounds + super.bounds
    }
    
    var endPoint: CGPoint {
        switch orientation {
        case .left:
            return origin - CGPoint(x: pinLength, y: 0)
        case .right:
            return origin + CGPoint(x: pinLength, y: 0)
        case .bottom:
            return origin - CGPoint(x: 0, y: pinLength)
        case .top:
            return origin + CGPoint(x: 0, y: pinLength)
        }
    }
    
    override var graphicBounds: CGRect { return rectContainingPoints([origin, endPoint]).insetBy(dx: -2, dy: -2) }
    override var centerPoint: CGPoint { return origin }
    
    override var inspectionName: String     { return "Pin" }

    init(origin: CGPoint, component: Component?, name: String, number: String, orientation: PinOrientation) {
        self.component = component
        self.orientation = orientation
        super.init(origin: origin)
        
        let pinNameText = AttributeText(origin: CGPoint(), format: "=pinName", angle: 0, owner: nil)
        let pinNumberText = AttributeText(origin: CGPoint(), format: "=pinNumber", angle: 0, owner: nil)
        pinNameText.color = NSColor.blue()
        pinNumberText.color = NSColor.red()
        attributeTexts.insert(pinNameText)
        attributeTexts.insert(pinNumberText)
        
        attributes = [
            "pinName": name,
            "pinNumber": number
        ]
        
        placeAttributes()
        node = Node(origin: endPoint)
    }
    
    required init?(coder decoder: NSCoder) {
        self.component = decoder.decodeObject(forKey: "component") as? Component
        orientation = PinOrientation(rawValue: decoder.decodeInteger(forKey: "orientation")) ?? .right
        hasBubble = decoder.decodeBool(forKey: "bubble")
        hasClockFlag = decoder.decodeBool(forKey: "clock")
        super.init(coder: decoder)
    }
    
    override init(json: JSON) {
        orientation = PinOrientation(rawValue: json["orientation"].intValue) ?? .right
        hasBubble = json["hasBubble"].boolValue
        hasClockFlag = json["hasClockFlag"].boolValue
        super.init(json: json)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    convenience init(copy pin: Pin) {
        self.init(origin: pin.origin, component: nil, name: pin.pinName, number: pin.pinNumber, orientation: pin.orientation)
        hasBubble = pin.hasBubble
        hasClockFlag = pin.hasClockFlag
        attributeTexts = Set(pin.attributeTexts.map { AttributeText(copy: $0) })
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(component, forKey: "component")
        coder.encode(orientation.rawValue, forKey: "orientation")
        coder.encode(hasBubble, forKey: "bubble")
        coder.encode(hasClockFlag, forKey: "clock")
        super.encode(with: coder)
    }
    
    func placeAttributes() {
        let nameSize = pinNameText?.size ?? CGSize()
        let numberSize = pinNumberText?.size ?? CGSize()
        
        switch orientation {
        case .right:
            pinNameText?.angle = 0
            pinNumberText?.angle = 0
            pinNameText?.origin = CGPoint(x: origin.x - nameSize.width - 2, y: origin.y - nameSize.height / 2)
            pinNumberText?.origin = CGPoint(x: origin.x + 4, y: origin.y + 0.5)
        case .top:
            pinNameText?.angle = PI / 2
            pinNumberText?.angle = PI / 2
            pinNameText?.origin = CGPoint(x: origin.x + nameSize.width / 2, y: origin.y - nameSize.height - 2)
            pinNumberText?.origin = CGPoint(x: origin.x - 0.5, y: origin.y + 4)
        case .bottom:
            pinNameText?.angle = PI / 2
            pinNumberText?.angle = PI / 2
            pinNameText?.origin = CGPoint(x: origin.x + nameSize.width / 2, y: origin.y + 2)
            pinNumberText?.origin = CGPoint(x: origin.x - 0.5, y: origin.y - numberSize.height - 2)
        case .left:
            pinNameText?.angle = 0
            pinNumberText?.angle = 0
            pinNameText?.origin = CGPoint(x: origin.x + 2, y: origin.y - nameSize.height / 2)
            pinNumberText?.origin = CGPoint(x: origin.x - numberSize.width - 4, y: origin.y + 0.5)
        }
    }
    
    override func moveBy(_ offset: CGPoint) {
        node?.moveBy(offset)
        super.moveBy(offset)
        origin = origin + offset
    }
    
    override func rotateByAngle(_ angle: CGFloat, center: CGPoint) {
        origin = rotatePoint(origin, angle: angle, center: center)
        let angle = normalizeAngle((endPoint - origin).angle + angle)
        var orient = Int(round(angle / (PI / 2)))
        while orient < 0 { orient += 4 }
        while orient >= 4 { orient -= 4 }
        switch orient {
        case 0: orientation = .right
        case 1: orientation = .top
        case 2: orientation = .left
        case 3: orientation = .bottom
        default: break
        }
        placeAttributes()
        cachedBounds = nil
    }
    
    override func flipHorizontalAroundPoint(_ center: CGPoint) {
        origin.x = center.x - (origin.x - center.x)
        switch orientation {
        case .left: orientation = .right
        case .right: orientation = .left
        default: break
        }
    }
    
    override func flipVerticalAroundPoint(_ center: CGPoint) {
        origin.y = center.y - (origin.y - center.y)
        switch orientation {
        case .top: orientation = .bottom
        case .bottom: orientation = .top
        default: break
        }
    }
    
    override func elementAtPoint(_ point: CGPoint) -> Graphic? {
        if point.distanceToPoint(endPoint) < 3 {
            return self
        }
        return super.elementAtPoint(point)
    }
    
    override func designCheck(_ view: SchematicView) {
        let graphics = view.findElementsAtPoint(endPoint)
        for g in graphics {
            if let node = g as? Node {
                self.node = node
                node.pin = self
            }
        }
        node?.designCheck(view)
    }
    
    override func drawInRect(_ rect: CGRect) {
        let context = NSGraphicsContext.current()?.cgContext

        NSColor.black().set()
        context?.setLineWidth(1)
        context?.beginPath()
        context?.moveTo(x: origin.x, y: origin.y)
        if hasBubble {
            let bsize = GridSize / 2
            var bubbleRect: CGRect
            switch orientation {
            case .right:    bubbleRect = CGRect(x: origin.x, y: origin.y - bsize / 2, width: bsize, height: bsize)
            case .left:     bubbleRect = CGRect(x: origin.x - bsize, y: origin.y - bsize / 2, width: bsize, height: bsize)
            case .top:      bubbleRect = CGRect(x: origin.x - bsize / 2, y: origin.y, width: bsize, height: bsize)
            case .bottom:   bubbleRect = CGRect(x: origin.x - bsize / 2, y: origin.y - bsize, width: bsize, height: bsize)
            }
            context?.strokeEllipse(in: bubbleRect)
            context?.moveTo(x: (origin.x + endPoint.x) / 2, y: (origin.y + endPoint.y) / 2)
        }
        context?.addLineTo(x: endPoint.x, y: endPoint.y)
        context?.strokePath()
        if !hasConnection {
            context?.beginPath()
            context?.addArc(centerX: endPoint.x, y: endPoint.y, radius: 2, startAngle: 0, endAngle: 2 * PI, clockwise: 1)
            context?.setLineWidth(0.2)
            setDrawingColor(NSColor.red())
            context?.strokePath()
        }
        super.drawInRect(rect)
    }
}
