//
//  SCHNet.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

enum NetOrientation: Int {
    case horizontal, vertical
}

struct NetState {
    var originNode: Node
    var endPointNode: Node
}

class Net: AttributedGraphic
{
    var originNode: Node {
        willSet { originNode.attachments.remove(self) }
        didSet  { originNode.attachments.insert(self); endPointNode.attachments.insert(self) }
    }
    
    var endPointNode: Node {
        willSet { endPointNode.attachments.remove(self) }
        didSet  { endPointNode.attachments.insert(self); originNode.attachments.insert(self) }
    }
    
    var orientation: NetOrientation {
        let delta = endPoint - origin
        return abs(delta.x) < abs(delta.y) ? .vertical : .horizontal
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
    
    var state: NetState {
        get { return NetState(originNode: originNode, endPointNode: endPointNode) }
        set { originNode = newValue.originNode; endPointNode = newValue.endPointNode }
    }
    var lastUndoSave = -1
    
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
        if let originNode = decoder.decodeObject(forKey: "originNode") as? Node,
            let endPointNode = decoder.decodeObject(forKey: "endPointNode") as? Node {
            self.originNode = originNode
            self.endPointNode = endPointNode
            super.init(coder: decoder)
        } else {
            return nil
        }
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(originNode, forKey: "originNode")
        coder.encode(endPointNode, forKey: "endPointNode")
        super.encode(with: coder)
    }
    
    func physicallyConnectedNets(_ gathered: Set<Net>) -> Set<Net> {
        if gathered.contains(self) {
            return gathered
        }
        var gathered = gathered + [self]
        let newNets = Set((originNode.attachments + endPointNode.attachments).filter { !gathered.contains($0) })
        for net in newNets {
            gathered = gathered + net.physicallyConnectedNets(gathered)
        }
        return gathered
    }
    
    func logicallyConnectedNets(_ view: SchematicView) -> Set<Net> {
        if let name = name {
            let nets = view.displayList.flatMap { $0 as? Net }
            return Set(nets.filter { $0.name == name })
        } else {
            return physicallyConnectedNets([])
        }
    }
    
    override func closestPointToPoint(_ point: CGPoint) -> CGPoint {
        return line.closestPointToPoint(point)
    }
    
    override func intersectsRect(_ rect: CGRect) -> Bool {
        return line.intersectsRect(rect) || super.intersectsRect(rect)
    }
    
    override func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        if line.distanceToPoint(point) < threshold {
            return .hitsOn(self)
        }
        return nil
    }
    
    override func elementAtPoint(_ point: CGPoint) -> Graphic? {
        if point.distanceToPoint(origin) < 3 {
            return originNode
        } else if point.distanceToPoint(endPoint) < 3 {
            return endPointNode
        }
        return super.elementAtPoint(point)
    }
    
    func restoreUndoState(_ state: NetState, view: SchematicView) {
        view.setNeedsDisplay(bounds.insetBy(dx: -5, dy: -5))
        let oldState = self.state
        self.state = state
        view.undoManager?.registerUndoWithTarget(self, handler: { (_) in
            self.restoreUndoState(oldState, view: view)
        })
        view.setNeedsDisplay(bounds.insetBy(dx: -5, dy: -5))
    }
    
    func saveUndoState(_ view: SchematicView) {
        if undoSequence != lastUndoSave {
            lastUndoSave = undoSequence
            let state = self.state
            view.undoManager?.registerUndoWithTarget(self, handler: { (_) in
                self.restoreUndoState(state, view: view)
            })
        }
    }
    
    override func moveBy(_ offset: CGPoint, view: SchematicView) {
        saveUndoState(view)
        originNode.moveBy(offset, view: view)
        endPointNode.moveBy(offset, view: view)
        super.moveBy(offset, view: view)
    }
    
    func propagatedName(exclude: Set<Net>) -> String? {
        let connected = (originNode.attachments + endPointNode.attachments).filter { !exclude.contains($0) }
        let pinName = originNode.pin?.netName ?? endPointNode.pin?.netName
        if let name = explicitName ?? pinName {
            return name
        }
        var exclude = exclude
        for net in connected {
            exclude.insert(net)
            if let name = net.propagatedName(exclude: exclude) {
                return name
            }
        }
        return nil
    }
    
    func relink(_ view: SchematicView) {
        originNode.attachments.insert(self)
        endPointNode.attachments.insert(self)
        view.undoManager?.registerUndoWithTarget(self) { (_) in
            self.unlink(view)
        }
    }
    
    override func unlink(_ view: SchematicView) {
        originNode.attachments.remove(self)
        endPointNode.attachments.remove(self)
        view.undoManager?.registerUndoWithTarget(self, handler: { (_) in
            self.relink(view)
        })
        originNode.optimize(view)
        endPointNode.optimize(view)
    }
    
    override func showHandles() {
        let color = NSColor.brown()
        if originNode.singleEndpoint {
            drawPoint(originNode.origin, color: color)
        }
        if endPointNode.singleEndpoint {
            drawPoint(endPointNode.origin, color: color)
        }
    }

    override func drawInRect(_ rect: CGRect) {
        let context = NSGraphicsContext.current()?.cgContext
        NSColor.black().set()
        context?.setLineWidth(1.0)
        
        if selected {
            NSColor.green().set()
            context?.setLineWidth(3)
            context?.beginPath()
            context?.moveTo(x: origin.x, y: origin.y)
            context?.addLineTo(x: endPoint.x, y: endPoint.y)
            context?.strokePath()
            showHandles()
        }
        NSColor.black().set()
        context?.setLineWidth(1.0)

        context?.beginPath()
        context?.moveTo(x: origin.x, y: origin.y)
        context?.addLineTo(x: endPoint.x, y: endPoint.y)
        context?.strokePath()
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
    
    init(origin: CGPoint, netName: String, owner: AttributedGraphic) {
        self.netName = netName
        super.init(origin: origin, format: "*netName*", angle: 0, owner: owner)
    }
    
    required init?(coder decoder: NSCoder) {
        if let netName = decoder.decodeObject(forKey: "netName") as? String {
            self.netName = netName
        } else {
            return nil
        }
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(netName, forKey: "netName")
        super.encode(with: coder)
    }
}
