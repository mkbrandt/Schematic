//
//  NetTool.swift
//  Schematic
//
//  Created by Matt Brandt on 5/31/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class NetConstructor: Graphic
{
    var wayPoints: [CGPoint] = []
    
    override var points: [CGPoint] { return [origin] + wayPoints }

    var endPoint: CGPoint {
        get { return wayPoints.last ?? origin }
        set {
            wayPoints[wayPoints.count - 1] = newValue
        }
    }
    
    var preferHorizontal = false    { didSet { if preferHorizontal { preferVertical = false }}}
    var preferVertical = false      { didSet { if preferVertical { preferHorizontal = false }}}
    
    override init(origin: CGPoint) {
        super.init(origin: origin)
    }

    convenience init(origin: CGPoint, wayPoints: [CGPoint]) {
        self.init(origin: origin)
        self.wayPoints = wayPoints
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    let TiltThreshold = GridSize * 2
    
    func addPoint(_ point: CGPoint) {
        let previousPoint = points[points.count - 2]
        let delta = endPoint - previousPoint
        if preferHorizontal && abs(delta.x) > TiltThreshold || !preferVertical && abs(delta.x) > abs(delta.y) {
            endPoint = previousPoint + CGPoint(x: delta.x, y: 0)
            //print("Add horizontal corner: \(endPoint)")
            preferVertical = true
        } else {
            endPoint = previousPoint + CGPoint(x: 0, y: delta.y)
            //print("Add vertical corner: \(endPoint)")
            preferHorizontal = true
        }
        wayPoints.append(point)
    }
    
    override func draw() {
        let context = NSGraphicsContext.current?.cgContext
        var sp = origin
        NSColor.black.set()
        context?.setLineWidth(1)
        context?.beginPath()
        context?.__moveTo(x: sp.x, y: sp.y)
        for wp in wayPoints {
            let delta = wp - sp
            if delta.x == 0 || delta.y == 0 {
                context?.__addLineTo(x: wp.x, y: wp.y)
            } else {
                if abs(delta.x) < TiltThreshold {
                    if preferHorizontal && wayPoints.count > 1 {
                        wayPoints.removeLast()
                        //print("removed point")
                    }
                    preferHorizontal = false
                }
                if abs(delta.y) < TiltThreshold {
                    if preferVertical && wayPoints.count > 1 {
                        wayPoints.removeLast()
                        //print("removed point")
                    }
                    preferVertical = false
                }
                
                if preferHorizontal || !preferVertical && abs(delta.x) > abs(delta.y) {
                    context?.__addLineTo(x: wp.x, y: sp.y)
                    if !preferHorizontal {
                        //print("prefer horizontal")
                        preferHorizontal = true
                    }
                } else {
                    context?.__addLineTo(x: sp.x, y: wp.y)
                    if !preferVertical {
                        //print("prefer vertical")
                        preferVertical = true
                    }
                }
                
                if wp != sp {
                    context?.__addLineTo(x: wp.x, y: wp.y)
                }
            }
            sp = wp
        }
        context?.strokePath()
    }
    
    func makeNetInView(_ view: SchematicView) {
        var startNode = Node(origin: origin)
        let el = view.findElementAtPoint(origin)
        if let pin = el as? Pin {
            startNode.pin = pin
        } else if let node = el as? Node {
            startNode = node
        } else if let net = el as? Net {
            let net2 = Net(originNode: startNode, endPointNode: net.endPointNode)
            view.addGraphic(net2)
            net.endPointNode = startNode
        }
        
        for p in wayPoints {
            if p == startNode.origin {
                continue
            }
            var endNode = Node(origin: p)
            let el = view.findElementAtPoint(p)
            if let pin = el as? Pin {
                endNode.pin = pin
            } else if let node = el as? Node {
                endNode = node
            } else if let net = el as? Net {
                let net2 = Net(originNode: endNode, endPointNode: net.endPointNode)
                view.addGraphic(net2)
                net.endPointNode = endNode
            }
            
            if startNode.origin != endNode.origin {
                let newNet = Net(originNode: startNode, endPointNode: endNode)
                view.addGraphic(newNet)
            }
            endNode.optimize(view)
            startNode = endNode
        }
    }
}

class NetTool: Tool
{
    
    override func keyDown(_ theEvent: NSEvent, view: SchematicView) {
        if let netcon = view.construction as? NetConstructor, theEvent.characters == "a" {
            view.construction = nil // add new nets here
            netcon.makeNetInView(view)
            view.needsDisplay = true
        } else {
            view.construction = nil
            view.needsDisplay = true
        }
    }
    
    func makeNet(_ netcon: NetConstructor, view: SchematicView) {
        view.construction = nil
        netcon.makeNetInView(view)
        view.needsDisplay = true
    }
    
    override func doubleClick(_ location: CGPoint, view: SchematicView) {
        if let netcon = view.construction as? NetConstructor {
            makeNet(netcon, view: view)
        }
    }
    
    override func mouseDown(_ location: CGPoint, view: SchematicView) {
        let location = view.snapToGrid(location)
        if let netcon = view.construction as? NetConstructor {
            netcon.addPoint(location)
            if let el = view.findElementAtPoint(location) {
                if el is Pin || el is Net || el is Node {
                    makeNet(netcon, view: view)
                    return
                }
            }
        } else {
            let netcon = NetConstructor(origin: location, wayPoints: [location])
            view.construction = netcon
        }
    }
    
    override func mouseMoved(_ location: CGPoint, view: SchematicView) {
        if let netcon = view.construction as? NetConstructor {
            netcon.endPoint = view.snapToGrid(location)
        }
    }
    
    override func mouseDragged(_ location: CGPoint, view: SchematicView) {
        mouseMoved(location, view: view)
    }
    
    override func mouseUp(_ location: CGPoint, view: SchematicView) {
    }
}
