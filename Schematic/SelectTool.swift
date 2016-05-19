//
//  SelectTool.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let SelectRadius: CGFloat = 6.0

class Tool
{
    var cursor: NSCursor { return NSCursor.crosshairCursor() }
    
    func keyDown(theEvent: NSEvent, view: SchematicView) {
    }
    
    func selectedTool(view: SchematicView) {
    }
    
    func unselectedTool(view: SchematicView) {
    }
    
    func mouseDown(location: CGPoint, view: SchematicView) {
    }
    
    func mouseMoved(location: CGPoint, view: SchematicView) {
    }
    
    func mouseDragged(location: CGPoint, view: SchematicView) {
    }
    
    func mouseUp(location: CGPoint, view: SchematicView) {
    }
}

enum SelectMode {
    case MoveHandle(SCHGraphic, Int), MoveGraphic(SCHGraphic), MoveGroup([SCHGraphic]), SelectRect, Select
}

class SelectTool: Tool
{
    var startPoint = CGPoint()
    var mode = SelectMode.Select
    
    override var cursor: NSCursor { return NSCursor.arrowCursor() }
    
    override func mouseDown(location: CGPoint, view: SchematicView) {
        startPoint = location
        view.needsDisplay = true
        if view.selection.count > 0 {
            for g in view.selection {
                if let ht = g.hitTest(location, threshold: SelectRadius) {
                    switch ht {
                    case .HitsOn:
                        mode = .MoveGroup(view.selection)
                        view.selection.forEach {
                            let p = $0.origin
                            view.undoManager?.registerUndoWithTarget($0) { (g) in
                                g.moveTo(p, view: view)
                                view.needsDisplay = true
                            }
                        }
                    case .HitsPoint(let h):
                        let p = g.points[h]
                        view.undoManager?.registerUndoWithTarget(g, handler: { (gg) in
                            gg.setPoint(p, index: h, view: view)
                            view.needsDisplay = true
                        })
                        mode = .MoveHandle(g, h)
                    }
                    return
                }
            }
        }
        let rect = CGRect(x: location.x - SelectRadius / 2, y: location.y - SelectRadius / 2, width: SelectRadius, height: SelectRadius)
        view.selectInRect(rect)
        if view.selection.count == 1 {
            let g = view.selection[0]
            mode = .MoveGraphic(g)
            let p = g.origin
            view.undoManager?.registerUndoWithTarget(g, handler: { (g) in
                g.moveTo(p, view: view)
                view.needsDisplay = true
            })
            return
        }
        mode = .SelectRect
    }
    
    override func mouseDragged(location: CGPoint, view: SchematicView) {
        switch mode {
        case .SelectRect:
            let rect = rectContainingPoints([location, startPoint])
            let rg = RectGraphic(origin: rect.origin, size: rect.size)
            rg.color = NSColor.redColor()
            rg.lineWeight = 0.5
            view.construction = rg
            view.selectInRect(rect)
        case .MoveGraphic(let g):
            let offset = view.snapToGrid(location) - view.snapToGrid(startPoint)
            startPoint = location
            g.moveBy(offset)
        case .MoveGroup(let gs):
            let offset = view.snapToGrid(location) - view.snapToGrid(startPoint)
            startPoint = location
            gs.forEach { $0.moveBy(offset) }
        case .MoveHandle(let g, let h):
            g.setPoint(view.snapToGrid(location), index: h)
        default:
            break
        }
        view.needsDisplay = true
    }
    
    override func mouseUp(location: CGPoint, view: SchematicView) {
        view.construction = nil
    }
}