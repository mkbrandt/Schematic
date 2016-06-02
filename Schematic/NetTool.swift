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
    
    override init(origin: CGPoint) {
        super.init(origin: origin)
    }

    convenience init(origin: CGPoint, wayPoints: [CGPoint]) {
        self.init(origin: origin)
        self.wayPoints = wayPoints
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    required init?(coder decoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw() {
        let context = NSGraphicsContext.currentContext()?.CGContext
        var sp = origin
        NSColor.blackColor().set()
        CGContextSetLineWidth(context, 1)
        CGContextBeginPath(context)
        CGContextMoveToPoint(context, sp.x, sp.y)
        for wp in wayPoints {
            let delta = wp - sp
            if abs(delta.x) > abs(delta.y) {
                CGContextAddLineToPoint(context, wp.x, sp.y)
            } else {
                CGContextAddLineToPoint(context, sp.x, wp.y)
            }
            
            if wp != sp {
                CGContextAddLineToPoint(context, wp.x, wp.y)
            }
            sp = wp
        }
        CGContextStrokePath(context)
    }
    
    var corners: [CGPoint] {
        var corners: [CGPoint] = []
        var sp = origin
        corners.append(sp)
        for wp in wayPoints {
            let delta = wp - sp
            var cp: CGPoint
            if abs(delta.x) > abs(delta.y) {
                cp = CGPoint(x: wp.x, y: sp.y)
                corners.append(cp)
            } else {
                cp = CGPoint(x: sp.x, y: wp.y)
                corners.append(cp)
            }
            
            if wp != cp {
                corners.append(CGPoint(x: wp.x, y: wp.y))
            }
            sp = wp
        }
        if let last = corners.last where last != endPoint {
            corners.append(endPoint)
        }
        
        var optCorners: [CGPoint] = [origin]
        for i in 2 ..< corners.count {
            let line = Line(origin: corners[i - 2], endPoint: corners[i])
            if line.distanceToPoint(corners[i - 1]) != 0 {
                optCorners.append(corners[i - 1])
            }
        }
        if let last = optCorners.last where last != endPoint {
            optCorners.append(endPoint)
        }
        return optCorners
    }
    
    func makeNetInView(view: SchematicView) {
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
        
        for p in corners.dropFirst() {
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
            let newNet = Net(originNode: startNode, endPointNode: endNode)
            view.addGraphic(newNet)
            startNode = endNode
        }
    }
}

class NetTool: Tool
{
    
    override func keyDown(theEvent: NSEvent, view: SchematicView) {
        if let netcon = view.construction as? NetConstructor where theEvent.characters == "a" {
            view.construction = nil // add new nets here
            netcon.makeNetInView(view)
            view.needsDisplay = true
        } else {
            view.construction = nil
            view.needsDisplay = true
        }
    }
    
    func makeNet(netcon: NetConstructor, view: SchematicView) {
        view.construction = nil
        netcon.makeNetInView(view)
        view.needsDisplay = true
    }
    
    override func doubleClick(location: CGPoint, view: SchematicView) {
        if let netcon = view.construction as? NetConstructor {
            makeNet(netcon, view: view)
        }
    }
    
    override func mouseDown(location: CGPoint, view: SchematicView) {
        let location = view.snapToGrid(location)
        if let netcon = view.construction as? NetConstructor {
            netcon.wayPoints.append(location)
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
    
    override func mouseMoved(location: CGPoint, view: SchematicView) {
        if let netcon = view.construction as? NetConstructor {
            netcon.endPoint = view.snapToGrid(location)
        }
    }
    
    override func mouseDragged(location: CGPoint, view: SchematicView) {
        mouseMoved(location, view: view)
    }
    
    override func mouseUp(location: CGPoint, view: SchematicView) {
    }
}
