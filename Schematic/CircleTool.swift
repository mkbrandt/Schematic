//
//  CircleTool.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class CircleTool: Tool
{
    override func mouseDown(_ location: CGPoint, view: SchematicView) {
        let location = view.snapToGrid(location)
        view.construction = CircleGraphic(origin: location, radius: 1.0)
    }
    
    override func mouseDragged(_ location: CGPoint, view: SchematicView) {
        let location = view.snapToGrid(location)
        if let circle = view.construction as? CircleGraphic {
            circle.radius = location.distanceToPoint(circle.origin)
        }
    }
    
    override func mouseUp(_ location: CGPoint, view: SchematicView) {
        if let circle = view.construction as? CircleGraphic, circle.radius > 0 {
            view.addConstruction()
        }
    }
}
