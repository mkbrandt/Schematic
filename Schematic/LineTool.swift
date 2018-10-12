//
//  LineTool.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class LineTool: Tool
{
    override func mouseDown(_ location: CGPoint, view: SchematicView) {
        let location = view.snapToGrid(location)
        
        view.construction = LineGraphic(origin: location, endPoint: location)
    }
    
    override func mouseDragged(_ location: CGPoint, view: SchematicView) {
        if let line = view.construction as? LineGraphic {
            let location = view.snapToGrid(location)
            
            line.endPoint = location
        }
    }
    
    override func mouseUp(_ location: CGPoint, view: SchematicView) {
        if let line = view.construction as? LineGraphic, line.origin != line.endPoint {
            view.addConstruction()
        } else {
            view.construction = nil
        }
    }
}
