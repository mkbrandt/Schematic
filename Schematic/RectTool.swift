//
//  RectTool.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class RectTool: Tool
{
    var startPoint = CGPoint()
    
    override func mouseDown(_ location: CGPoint, view: SchematicView) {
        let location = view.snapToGrid(location)
        startPoint = view.snapToGrid(location)
    }
    
    override func mouseDragged(_ location: CGPoint, view: SchematicView) {
        let location = view.snapToGrid(location)
        let rect = rectContainingPoints([startPoint, location])
        view.construction = RectGraphic(origin: rect.origin, size: rect.size)
    }
    
    override func mouseUp(_ location: CGPoint, view: SchematicView) {
        if let rect = view.construction as? RectGraphic, rect.size.width > 0 && rect.size.height > 0 {
            view.addConstruction()
        } else {
            view.construction = nil
        }
    }
}
