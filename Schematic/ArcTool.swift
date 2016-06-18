//
//  ArcTool.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class ArcTool: Tool
{
    var state = 0
    var startPoint = CGPoint()
    var endPoint = CGPoint()
    
    func arcFromStartPoint(_ startPoint: CGPoint, endPoint: CGPoint, midPoint: CGPoint) -> Graphic {
        let mp1 = (startPoint + midPoint) / 2
        let mp2 = (endPoint + midPoint) / 2
        let ang1 = (midPoint - startPoint).angle + PI / 2
        let ang2 = (midPoint - endPoint).angle + PI / 2
        let bisector1 = LineGraphic(origin: mp1, vector: CGPoint(length: 100, angle: ang1))
        let bisector2 = LineGraphic(origin: mp2, vector: CGPoint(length: 100, angle: ang2))
        if let origin = bisector1.intersectionWithLine(bisector2, extendSelf: true, extendOther: true) {
            let radius = (startPoint - origin).length
            let startAngle = (startPoint - origin).angle
            let endAngle = (endPoint - origin).angle
            let clockwise = true
            let g = ArcGraphic(origin: origin, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: clockwise)
            g.clockwise = g.pointOnArc(midPoint)
            return g
        }
        return LineGraphic(origin: startPoint, endPoint: endPoint)
    }
    
    override func selectedTool(_ view: SchematicView) {
        state = 0
    }
    
    override func mouseDown(_ location: CGPoint, view: SchematicView) {
        let location = view.snapToGrid(location)
        switch state {
        case 0:
            startPoint = location
        case 1:
            endPoint = location
            view.construction = LineGraphic(origin: startPoint, endPoint: endPoint)
        default:
            view.construction = arcFromStartPoint(startPoint, endPoint: endPoint, midPoint: location)
        }
    }
    
    override func mouseMoved(_ location: CGPoint, view: SchematicView) {
        let location = view.snapToGrid(location)
        switch state {
        case 0:
            break
        case 1:
            endPoint = location
            view.construction = LineGraphic(origin: startPoint, endPoint: endPoint)
        default:
            view.construction = arcFromStartPoint(startPoint, endPoint: endPoint, midPoint: location)
        }
    }
    
    override func mouseDragged(_ location: CGPoint, view: SchematicView) {
        let location = view.snapToGrid(location)
        
        switch state {
        case 0:
            state = 1
            fallthrough
        default:
            mouseMoved(location, view: view)
        }
        
    }
    
    override func mouseUp(_ location: CGPoint, view: SchematicView) {
        switch state {
        case 0:
            state = 1
            //view.setDrawingHint("3 Point Arc: Select end point")
        case 1:
            state = 2
            //view.setDrawingHint("3 Point Arc: Select mid point")
        default:
            state = 0
            //view.setDrawingHint("3 Point Arc: Select start point")
            view.addConstruction()
        }
    }
}
