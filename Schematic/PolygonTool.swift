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
    override func keyDown(theEvent: NSEvent, view: SchematicView) {
        if theEvent.keyCode == 36 {     // return key
            if let poly = view.construction as? PolygonGraphic {
                poly.filled = true
                view.addConstruction()
            } else {
                view.construction = nil
            }
        }
    }
    
    override func unselectedTool(view: SchematicView) {
        view.construction = nil
    }
    
    override func mouseDown(location: CGPoint, view: SchematicView) {
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
    
    override func mouseDragged(location: CGPoint, view: SchematicView) {
        if let line = view.construction as? LineGraphic {
            let location = view.snapToGrid(location)
            
            line.endPoint = location
        } else if let poly = view.construction as? PolygonGraphic {
            poly._vertices[poly._vertices.count - 1] = location
        }
    }
    
    override func mouseUp(location: CGPoint, view: SchematicView) {
    }
}