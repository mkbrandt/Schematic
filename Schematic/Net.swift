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

class NetState: GraphicState {
    var originNode: Node
    var endPointNode: Node
    
    init(originNode: Node, endPointNode: Node) {
        self.originNode = originNode
        self.endPointNode = endPointNode
        super.init(origin: CGPoint())
    }
}

class PhysicalNetState: GraphicState {
    var netStates: [(Net, GraphicState)]
    var nodeStates: [(Node, GraphicState)]
    
    init(nets: Set<Net>, nodes: Set<Node>) {
        netStates = nets.map { ($0, $0.state) }
        nodeStates = nodes.map { ($0, $0.state) }
        super.init(origin: CGPoint())
    }
    
    var bounds: CGRect { return netStates.reduce(CGRect()) { $0 + $1.0.bounds } }
}

class Net: AttributedGraphic
{
    override class var supportsSecureCoding: Bool { return true }
    
    var originNode: Node {
        willSet { originNode.attachments.remove(self) }
        didSet  { originNode.attachments.insert(self); endPointNode.attachments.insert(self) }
    }
    
    var endPointNode: Node {
        willSet { endPointNode.attachments.remove(self) }
        didSet  { endPointNode.attachments.insert(self); originNode.attachments.insert(self) }
    }
    
    var previousOrientation: NetOrientation?
    var orientation: NetOrientation {
        let delta = endPoint - origin
        if let previousOrientation = previousOrientation, abs(delta.x) == abs(delta.y) {
            return previousOrientation
        }
        let currentOrientation: NetOrientation = abs(delta.x) < abs(delta.y) ? .vertical : .horizontal
        previousOrientation = currentOrientation
        return currentOrientation
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
    
    override var state: GraphicState {
        get { return NetState(originNode: originNode, endPointNode: endPointNode) }
        set {
            if let newValue = newValue as? NetState {
                originNode = newValue.originNode
                endPointNode = newValue.endPointNode
            } else if let newValue = newValue as? PhysicalNetState {
                self.physicalNetState = newValue
            }
        }
    }
    
    var physicalNetState: GraphicState {
        get {
            let nets = physicallyConnectedNets([])
            let nodes = nets.reduce([]) { return $0 + [$1.originNode, $1.endPointNode] }
            return PhysicalNetState(nets: Set(nets), nodes: Set(nodes))
        }
        set {
            if let newValue = newValue as? PhysicalNetState {
                for (net, st) in newValue.netStates {
                    net.state = st
                }
                for (node, st) in newValue.nodeStates {
                    node.state = st
                }
            }
        }
    }
    
    override var description: String    { return "net \(String(describing: name)): \(origin) - \(endPoint)" }
    override var points: [CGPoint]      { return [origin, endPoint] }
    
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
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    required init?(coder decoder: NSCoder) {
        if let originNode = decoder.decodeObject(of: Node.self, forKey: "originNode"),
            let endPointNode = decoder.decodeObject(of: Node.self, forKey: "endPointNode") {
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
    
    override func restoreUndo(state: GraphicState, view: SchematicView) {
        if let state = state as? PhysicalNetState {
            view.setNeedsDisplay(state.bounds.insetBy(dx: -5, dy: -5))
            let oldState = self.state
            self.state = state
            view.undoManager?.registerUndo(withTarget: self, handler: { (_) in
                self.restoreUndo(state: oldState, view: view)
            })
            view.setNeedsDisplay(state.bounds.insetBy(dx: -5, dy: -5))
        } else {
            super.restoreUndo(state: state, view: view)
        }
    }

    override func saveUndoState(view: SchematicView) {
        let state = self.physicalNetState
        view.undoManager?.registerUndo(withTarget: self, handler: { (_) in
            self.restoreUndo(state: state, view: view)
        })
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
            
    override func moveBy(_ offset: CGPoint) {
        originNode.moveBy(offset)
        endPointNode.moveBy(offset)
        super.moveBy(offset)
    }
    
    func propagatedName(exclude: Set<Net>) -> String? {
        let connected = (originNode.attachments + endPointNode.attachments).filter { !exclude.contains($0) }
        let pinName = originNode.pin?.implicitNetName ?? endPointNode.pin?.implicitNetName
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
    
    override func designCheck(_ view: SchematicView) {
        if originNode.pin != nil {
            originNode.designCheck(view)
        }
        endPointNode.designCheck(view)
        if originNode.pin == nil {
            originNode.designCheck(view)
        }
    }
    
    func relink(_ view: SchematicView) {
        originNode.attachments.insert(self)
        endPointNode.attachments.insert(self)
        view.undoManager?.registerUndo(withTarget: self) { (_) in
            self.unlink(view)
        }
    }
    
    override func unlink(_ view: SchematicView) {
        originNode.attachments.remove(self)
        endPointNode.attachments.remove(self)
        view.undoManager?.registerUndo(withTarget: self, handler: { (_) in
            self.relink(view)
        })
        originNode.optimize(view)
        endPointNode.optimize(view)
    }
    
    override func showHandles() {
        let color = NSColor.brown
        if originNode.singleEndpoint {
            drawPoint(originNode.origin, color: color)
        }
        if endPointNode.singleEndpoint {
            drawPoint(endPointNode.origin, color: color)
        }
    }

    override func drawInRect(_ rect: CGRect) {
        let context = NSGraphicsContext.current?.cgContext
        NSColor.black.set()
        context?.setLineWidth(1.0)
        
        if selected {
            NSColor.green.set()
            context?.setLineWidth(3)
            context?.beginPath()
            context?.__moveTo(x: origin.x, y: origin.y)
            context?.__addLineTo(x: endPoint.x, y: endPoint.y)
            context?.strokePath()
            showHandles()
        }
        NSColor.black.set()
        context?.setLineWidth(1.0)

        context?.beginPath()
        context?.__moveTo(x: origin.x, y: origin.y)
        context?.__addLineTo(x: endPoint.x, y: endPoint.y)
        context?.strokePath()
        originNode.drawInRect(rect)
        endPointNode.drawInRect(rect)
        super.drawInRect(rect)
    }
}

class NetNameAttributeText: AttributeText
{
    override class var supportsSecureCoding: Bool { return true }
    
    var netName: String = "unnamed"
    
    override var string: NSString  {
        get { return netName as NSString }
        set { netName = newValue as String }
    }
    
    override var inspectionName: String { return "NetNameAttribute" }
    
    init(origin: CGPoint, netName: String, owner: AttributedGraphic) {
        self.netName = netName
        super.init(origin: origin, format: "*netName*", angle: 0, owner: owner)
    }
    
    required init?(coder decoder: NSCoder) {
        if let netName = decoder.decodeObject(of: NSString.self, forKey: "netName") as String? {
            self.netName = netName
        } else {
            return nil
        }
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(netName, forKey: "netName")
        super.encode(with: coder)
    }
}
