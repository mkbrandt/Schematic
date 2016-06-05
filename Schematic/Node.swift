//
//  Node.swift
//  Schematic
//
//  Created by Matt Brandt on 6/3/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

enum TypedNet {
    case Origin(Net), EndPoint(Net)
}

struct NodeState {
    var attachments: Set<Net>
    var pin: Pin?
    var origin: CGPoint
}

class Node: AttributedGraphic
{
    var pin: Pin? {
        willSet { pin?.node = nil }
        didSet  { pin?.node = self }
    }
    
    var attachments: Set<Net> = []
    
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
    
    var state: NodeState {
        get { return NodeState(attachments: self.attachments, pin: self.pin, origin: self.origin) }
        set {
            self.attachments = newValue.attachments
            self.pin = newValue.pin
            self.origin = newValue.origin
        }
    }
    var lastUndoSave = -1
    
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
    
    var connections: [(Net, Node)] {
        return attachments.map { ($0, otherNode($0)) }
    }
    
    func restoreState(state: NodeState, view: SchematicView) {
        let oldState = self.state
        self.state = state
        view.undoManager?.registerUndoWithTarget(self, handler: { (_) in
            self.restoreState(oldState, view: view)
        })
    }
    
    func saveUndoState(view: SchematicView) {
        if lastUndoSave != undoSequence {
            lastUndoSave = undoSequence
            let state = self.state
            view.undoManager?.registerUndoWithTarget(self, handler: { (_) in
                self.restoreState(state, view: view)
            })
        }
    }
    
    override func moveBy(offset: CGPoint, view: SchematicView) {
        var offset = offset
        if constrainedX([]) { offset.x = 0 }
        if constrainedY([]) { offset.y = 0 }
        if moveBy(offset, overlapsPinInView: view) {
            print("overlap detected")
            return
        }
        saveUndoState(view)
        attachments.forEach { view.setNeedsDisplayInRect($0.bounds) }
        origin = origin + offset
        attachments.forEach { view.setNeedsDisplayInRect($0.bounds) }
    }
    
    func otherNode(net: Net) -> Node {
        if net.originNode == self {
            return net.endPointNode
        } else {
            return net.originNode
        }
    }
    
    func moveBy(offset: CGPoint, overlapsPinInView view: SchematicView, exclude: Set<Net> = []) -> Bool {
        if pin != nil || attachments.count == 1 {
            return false
        }
        
        if view.findElementAtPoint(origin + offset) is Pin {
            return true
        }
        
        let nets = attachments.filter { !exclude.contains($0) }
        var exclude = exclude
        for net in nets {
            exclude.insert(net)
            if otherNode(net).moveBy(offset, overlapsPinInView: view, exclude: exclude) {
                return true
            }
        }
        return false
    }
    
    func constrainedX(exclude: Set<Net>) -> Bool {
        if let comp = pin?.component where !comp.selected {
            return true
        }
        let verticalNets = attachments.filter { $0.orientation == .Vertical && !exclude.contains($0) }
        let verticalNodes = verticalNets.map { otherNode($0) }
        return verticalNodes.reduce(false) { $0 || $1.constrainedX(exclude + Set(verticalNets)) }
    }
    
    func constrainedY(exclude: Set<Net>) -> Bool {
        if let comp = pin?.component where !comp.selected {
            return true
        }
        let horizontalNets = attachments.filter { $0.orientation == .Horizontal && !exclude.contains($0) }
        let horizontalNodes = horizontalNets.map { otherNode($0) }
        return horizontalNodes.reduce(false) { $0 || $1.constrainedY(exclude + Set(horizontalNets)) }
    }
    
    override func designCheck(view: SchematicView) {
        designCheck(view, checked: [])
    }
    
    func connectOverlappingNodes(view: SchematicView) {
        if pin == nil && attachments.count == 1 {
            for g in view.findElementsAtPoint(origin) {
                if let pin = g as? Pin {
                    self.pin = pin
                }
            }
        }
    }
    
    func designCheck(view: SchematicView, checked: Set<Node>) {
        saveUndoState(view)
        var checked = checked
        attachments.forEach { $0.saveUndoState(view); view.setNeedsDisplayInRect($0.bounds) }
        connectOverlappingNodes(view)
        optimize(view)
        var propagates: [Node] = []
        for (net, node) in connections {
            if !checked.contains(node) {
                switch net.orientation {
                case .Horizontal:
                    if node.origin.y != origin.y {
                        node.moveBy(CGPoint(x: 0, y: origin.y - node.origin.y), view: view)
                        propagates.append(node)
                    }
                case .Vertical:
                    if node.origin.x != origin.x {
                        node.moveBy(CGPoint(x: origin.x - node.origin.x, y: 0), view: view)
                        propagates.append(node)
                    }
                }
            }
        }
        
        checked.insert(self)
        for node in propagates {
            node.designCheck(view, checked: checked)
        }
        optimize(view)
        attachments.forEach { view.setNeedsDisplayInRect($0.bounds) }
    }
    
    func typedNet(net: Net) -> TypedNet {
        if net.originNode == self {
            return .Origin(net)
        } else {
            return .EndPoint(net)
        }
    }
    
    func moveNodeConnectionsFromNode(other: Node, attachments: [TypedNet], pin: Pin?, view: SchematicView) {
        saveUndoState(view)
        other.saveUndoState(view)
        for tnet in attachments {
            switch tnet {
            case .Origin(let net):
                net.saveUndoState(view)
                print("moving origin of NET \(net.graphicID) from NODE \(net.originNode.graphicID) to NODE \(self.graphicID)")
                net.originNode = self
                showNet(net)
            case .EndPoint(let net):
                net.saveUndoState(view)
                print("moving endPoint of NET \(net.graphicID) from NODE \(net.endPointNode.graphicID) to NODE \(self.graphicID)")
                net.endPointNode = self
                showNet(net)
            }
        }
        if let pin = pin {
            print("movin pin from \(pin.node) to \(self)")
            self.pin = pin
        }
    }
    
    /// optimize the current node in relation to the nodes and nets around it
    func optimize(view: SchematicView) {
        saveUndoState(view)
        for net in attachments {
            if net.line.length == 0 {
                net.saveUndoState(view)
                print("removing zero length NET \(net.graphicID)")
                if net.originNode == net.endPointNode {
                    print("Warning: Net \(net.graphicID) has two connections to NODE \(graphicID)")
                    view.deleteGraphic(net)
                } else if pin == nil {                      // we should merge with another node
                    let other = otherNode(net)
                    moveNodeConnectionsFromNode(other, attachments: other.attachments.map({ other.typedNet($0) }), pin: other.pin, view: view)
                    view.deleteGraphic(net)
                }
            }
        }
        
        for net in attachments {
            // look for overlapping nets and make them not overlap
            let otherNets = attachments.filter { $0 != net }
            for net2 in otherNets {
                let other = otherNode(net2)
                if net.line.distanceToPoint(other.origin) == 0 {
                    net.saveUndoState(view)
                    print("merging overlapping NET \(net.graphicID) and NODE \(other.graphicID)")
                    other.moveNodeConnectionsFromNode(self, attachments: [self.typedNet(net)], pin: nil, view: view)
                }
            }
        }
        
        // look for nets that are inline and end to end with no third connection and delete the joining node
        if attachments.count == 2 && pin == nil {
            let lines = attachments.map { $0.line }
            if lines[0].isParallelWith(lines[1]) {
                let net1 = attachments.removeFirst()
                let net2 = attachments.removeFirst()
                net1.saveUndoState(view)
                net2.saveUndoState(view)
                print("merging NET \(net1.graphicID) and NET \(net2.graphicID)")
                otherNode(net2).moveNodeConnectionsFromNode(self, attachments: [self.typedNet(net1)], pin: nil, view: view)
                view.deleteGraphic(net2)
            }
        }
    }
    
    func showNet(net: Net) {
        print("Net \(net.graphicID) :: origin is NODE \(net.originNode.graphicID) endPoint is NODE \(net.endPointNode.graphicID)")
        print("   originNode connections: \(net.originNode.attachments.map { $0.graphicID })")
        print("   endPointNode connections: \(net.endPointNode.attachments.map { $0.graphicID })")
    }
    
    override func drawInRect(rect: CGRect) {
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
        } else if attachments.count == 0 {
            NSColor.redColor().set()
            CGContextBeginPath(context)
            CGContextAddArc(context, origin.x, origin.y, 2, 0, 2 * PI, 1)
            CGContextStrokePath(context)
        }
    }
}


