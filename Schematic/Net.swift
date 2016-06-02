//
//  SCHNet.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

enum NetOrientation: Int {
    case Horizontal, Vertical
}

class Node: PrimitiveGraphic
{
    var pin: Pin? {
        willSet { pin?.node = nil }
        didSet  { pin?.node = self }
    }
    
    var attachments: Set<Net> = [] { didSet { if attachments.count == 0 { pin = nil }}}
    
    override var origin: CGPoint {
        get {
            if let pin = pin {
                return pin.endPoint
            }
            return super.origin
        }
        set {
            super.origin = newValue
        }
    }
    
    var canMove: Bool           { return pin == nil }
    var singleEndpoint: Bool    { return pin == nil && attachments.count == 1 }
    
    override init(origin: CGPoint) {
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        pin = decoder.decodeObjectForKey("pin") as? Pin
        if let attachments = decoder.decodeObjectForKey("attachments") as? Set<Net> {
            self.attachments = attachments
        }
        super.init(coder: decoder)
        if let pin = pin {
            pin.node = self
        }
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(attachments, forKey: "attachments")
        if let pin = pin {
            coder.encodeObject(pin, forKey: "pin")
        }
        super.encodeWithCoder(coder)
    }

    func optimize(view: SchematicView) {
        if attachments.count == 2 && pin == nil {
            let lines = attachments.map { $0.line }             // can't quite figure out how to call this when nets are deleted
            if lines[0].isParallelWith(lines[1]) {
                let net1 = attachments.removeFirst()
                let net2 = attachments.removeFirst()
                let outerNodes = [net1.originNode, net1.endPointNode, net2.originNode, net2.endPointNode].filter { $0 != self }
                net1.originNode = outerNodes[0]
                net1.endPointNode = outerNodes[1]
                outerNodes[0].attachments.insert(net1)
                outerNodes[1].attachments.insert(net1)
                view.deleteGraphic(net2)
            }
        }
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        if pin == nil && attachments.count > 2 {
            NSColor.blackColor().set()
            CGContextBeginPath(context)
            CGContextAddArc(context, origin.x, origin.y, 2, 0, 2 * PI, 1)
            CGContextFillPath(context)
        } else if pin == nil && attachments.count == 1 {
            NSColor.redColor().set()
            CGContextBeginPath(context)
            CGContextAddArc(context, origin.x, origin.y, 2, 0, 2 * PI, 1)
            CGContextFillPath(context)
        }
    }
}

class Net: AttributedGraphic
{
    var originNode: Node {
        willSet { originNode.attachments.remove(self) }
        didSet  { originNode.attachments.insert(self) }
    }
    
    var endPointNode: Node {
        willSet { endPointNode.attachments.remove(self) }
        didSet  { endPointNode.attachments.insert(self) }
    }
    
    var orientation: NetOrientation {
        let delta = endPoint - origin
        return abs(delta.x) < abs(delta.y) ? .Vertical : .Horizontal
    }
    
    override var origin: CGPoint {
        get {
            return originNode.origin
        }
        set {
            originNode.origin = newValue
        }
    }
    
    var endPoint: CGPoint {
        get {
            return endPointNode.origin
        }
        set {
            endPointNode.origin = newValue
        }
    }
    
    override var description: String    { return "net \(name): \(origin) - \(endPoint)" }
    override var points: [CGPoint] { return [origin, endPoint] }
    
    override var graphicBounds: CGRect { return rectContainingPoints(points).insetBy(dx: -2, dy: -2) }
    override var bounds: CGRect { return super.bounds + graphicBounds }
    
    var line: Line { return Line(origin: origin, endPoint: endPoint) }
    
    override var inspectionName: String { return "Net - \(name ?? "-unnamed-")" }
    
    var netNameText: NetNameAttributeText? {
        let netNameTexts = attributeTexts.flatMap { $0 as? NetNameAttributeText }
        return netNameTexts.first
    }
    
    var explicitName: String? {
        return netNameText?.netName
    }
    
    var name: String? {
        return explicitName ?? propagatedName(exclude: [self])
    }
    
    init(originNode: Node, endPointNode: Node) {
        self.originNode = originNode
        self.endPointNode = endPointNode
        super.init(origin: originNode.origin)
        originNode.attachments.insert(self)
        endPointNode.attachments.insert(self)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    required init?(coder decoder: NSCoder) {
        if let originNode = decoder.decodeObjectForKey("originNode") as? Node,
            let endPointNode = decoder.decodeObjectForKey("endPointNode") as? Node {
            self.originNode = originNode
            self.endPointNode = endPointNode
            super.init(coder: decoder)
        } else {
            return nil
        }
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(originNode, forKey: "originNode")
        coder.encodeObject(endPointNode, forKey: "endPointNode")
        super.encodeWithCoder(coder)
    }
    
    override func closestPointToPoint(point: CGPoint) -> CGPoint {
        return line.closestPointToPoint(point)
    }
    
    override func intersectsRect(rect: CGRect) -> Bool {
        return line.intersectsRect(rect) || super.intersectsRect(rect)
    }
    
    override func elementAtPoint(point: CGPoint) -> Graphic? {
        if point.distanceToPoint(origin) < 3 {
            return originNode
        } else if point.distanceToPoint(endPoint) < 3 {
            return endPointNode
        }
        return super.elementAtPoint(point)
    }
    
    override func moveBy(offset: CGPoint) -> CGRect {
        let b0 = bounds
        if originNode.canMove && endPointNode.canMove {
            let offset = orientation == .Horizontal ? CGPoint(x: 0, y: offset.y) : CGPoint(x: offset.x, y: 0)
            
            originNode.moveBy(offset)
            endPointNode.moveBy(offset)
        }
        return b0 + bounds + super.moveBy(offset)
    }
    
    func propagatedName(exclude exclude: [Net]) -> String? {
        let connected = (originNode.attachments + endPointNode.attachments).filter { !exclude.contains($0) }
        return explicitName ?? connected.reduce(nil, combine: {$0 ?? $1.propagatedName(exclude: [self] + exclude)})
    }
    
    func relink(view: SchematicView) {
        originNode.attachments.insert(self)
        endPointNode.attachments.insert(self)
        view.undoManager?.registerUndoWithTarget(self) { (_) in
            self.unlink(view)
        }
    }
    
    override func unlink(view: SchematicView) {
        originNode.attachments.remove(self)
        endPointNode.attachments.remove(self)
        view.undoManager?.registerUndoWithTarget(self, handler: { (_) in
            self.relink(view)
        })
        originNode.optimize(view)
        endPointNode.optimize(view)
    }
    
    override func showHandles() {
        let color = NSColor.brownColor()
        if originNode.singleEndpoint {
            drawPoint(originNode.origin, color: color)
        }
        if endPointNode.singleEndpoint {
            drawPoint(endPointNode.origin, color: color)
        }
    }

    override func drawInRect(rect: CGRect) {
        let context = NSGraphicsContext.currentContext()?.CGContext
        NSColor.blackColor().set()
        CGContextSetLineWidth(context, 1.0)
        
        if selected {
            NSColor.greenColor().set()
            CGContextSetLineWidth(context, 3)
            CGContextBeginPath(context)
            CGContextMoveToPoint(context, origin.x, origin.y)
            CGContextAddLineToPoint(context, endPoint.x, endPoint.y)
            CGContextStrokePath(context)
            showHandles()
        }
        NSColor.blackColor().set()
        CGContextSetLineWidth(context, 1.0)

        CGContextBeginPath(context)
        CGContextMoveToPoint(context, origin.x, origin.y)
        CGContextAddLineToPoint(context, endPoint.x, endPoint.y)
        CGContextStrokePath(context)
        originNode.drawInRect(rect)
        endPointNode.drawInRect(rect)
        super.drawInRect(rect)
    }
}

class NetNameAttributeText: AttributeText
{
    var netName: String = "unnamed"
    
    override var string: NSString  {
        get { return netName }
        set { netName = newValue as String }
    }
    
    override var inspectionName: String { return "NetNameAttribute" }
    
    init(origin: CGPoint, netName: String, owner: Net) {
        self.netName = netName
        super.init(origin: origin, format: "*netName*", angle: 0, owner: owner)
    }
    
    required init?(coder decoder: NSCoder) {
        if let netName = decoder.decodeObjectForKey("netName") as? String {
            self.netName = netName
        } else {
            return nil
        }
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(netName, forKey: "netName")
        super.encodeWithCoder(coder)
    }
}
