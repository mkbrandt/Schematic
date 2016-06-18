//
//  PolygonTool.swift
//  Schematic
//
//  Created by Matt Brandt on 5/28/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class PolygonTool: Tool
{
    override func keyDown(_ theEvent: NSEvent, view: SchematicView) {
        if theEvent.keyCode == 36 {     // return key
            if let poly = view.construction as? PolygonGraphic {
                poly.filled = true
                view.addConstruction()
            } else {
                view.construction = nil
            }
        }
    }
    
    override func unselectedTool(_ view: SchematicView) {
        view.construction = nil
    }
    
    override func mouseDown(_ location: CGPoint, view: SchematicView) {
        let location = view.snapToGrid(location)
        
        if let poly = view.construction as? PolygonGraphic {
            if location == poly.origin {
                poly.filled = true
                view.addConstruction()
            } else {
                poly._vertices.append(location)
            }
        } else if let line = view.construction as? LineGraphic {
            view.construction = PolygonGraphic(vertices: [line.origin, line.endPoint, location], filled: false)
        } else {
            view.construction = LineGraphic(origin: location, endPoint: location)
        }
    }
    
    override func mouseDragged(_ location: CGPoint, view: SchematicView) {
        if let line = view.construction as? LineGraphic {
            let location = view.snapToGrid(location)
            
            line.endPoint = location
        } else if let poly = view.construction as? PolygonGraphic {
            poly._vertices[poly._vertices.count - 1] = location
        }
    }
    
    override func mouseUp(_ location: CGPoint, view: SchematicView) {
    }
}
