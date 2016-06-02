//
//  SelectTool.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class Tool: NSObject
{
    var cursor: NSCursor { return NSCursor.crosshairCursor() }
    
    func keyDown(theEvent: NSEvent, view: SchematicView) {
    }
    
    func selectedTool(view: SchematicView) {
    }
    
    func unselectedTool(view: SchematicView) {
    }
    
    func doubleClick(location: CGPoint, view: SchematicView) {
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
    case MoveHandle(Graphic, Int), MoveGraphic(Graphic), MoveGroup(Set<Graphic>), SelectRect, Select
}

class SelectTool: Tool
{
    var startPoint = CGPoint()
    var mode = SelectMode.Select
    
    override var cursor: NSCursor { return NSCursor.arrowCursor() }
    
    func redrawSelection(view: SchematicView) {
        let rect = view.selection.reduce(CGRect()) { $0 + $1.bounds.insetBy(dx: -view.selectRadius, dy: -view.selectRadius) }
        view.setNeedsDisplayInRect(rect)
    }
    
    override func doubleClick(location: CGPoint, view: SchematicView) {
        redrawSelection(view)
        if let el = view.findElementAtPoint(location) {
            view.selection = [el]
        } else {
            view.selection = []
        }
        redrawSelection(view)
    }
    
    override func mouseDown(location: CGPoint, view: SchematicView) {
        startPoint = location
        redrawSelection(view)
        if view.selection.count > 0 {
            for g in view.selection {
                if let ht = g.hitTest(location, threshold: view.selectRadius) {
                    switch ht {
                    case .HitsOn(_):
                        mode = .MoveGroup(view.selection)
                        view.selection.forEach {
                            let p = $0.origin
                            view.undoManager?.registerUndoWithTarget($0) { (g) in
                                g.moveTo(p, view: view)
                                view.needsDisplay = true
                            }
                        }
                    case .HitsPoint(let gr, let h):
                        let p = gr.points[h]
                        view.undoManager?.registerUndoWithTarget(gr, handler: { (gg) in
                            gg.setPoint(p, index: h, view: view)
                            view.needsDisplay = true
                        })
                        mode = .MoveHandle(gr, h)
                    }
                    return
                }
            }
        }
        let rect = CGRect(x: location.x - view.selectRadius / 2, y: location.y - view.selectRadius / 2, width: view.selectRadius, height: view.selectRadius)
        view.selectInRect(rect)
        if let g = view.selection.first {
            mode = .MoveGraphic(g)
            let p = g.origin
            view.undoManager?.registerUndoWithTarget(g, handler: { (g) in
                g.moveTo(p, view: view)
                view.needsDisplay = true
            })
            redrawSelection(view)
            return
        }
        mode = .SelectRect
    }
    
    override func mouseDragged(location: CGPoint, view: SchematicView) {
        redrawSelection(view)
        switch mode {
        case .SelectRect:
            let rect = rectContainingPoints([location, startPoint])
            let rg = RectGraphic(origin: rect.origin, size: rect.size)
            rg.color = NSColor.redColor()
            rg.lineWeight = 0.5
            view.construction = rg
            view.selectInRect(rect)
            view.setNeedsDisplayInRect(rect.insetBy(dx: -view.selectRadius, dy: -view.selectRadius))
        case .MoveGraphic(let g):
            let offset = view.snapToGrid(location) - view.snapToGrid(startPoint)
            startPoint = location
            let changed = g.moveBy(offset)
            view.setNeedsDisplayInRect(changed)
        case .MoveGroup(let gs):
            let offset = view.snapToGrid(location) - view.snapToGrid(startPoint)
            startPoint = location
            gs.forEach { $0.moveBy(offset) }
        case .MoveHandle(let g, let h):
            g.setPoint(view.snapToGrid(location), index: h)
        default:
            break
        }
        //view.needsDisplay = true
        redrawSelection(view)
    }
    
    override func mouseUp(location: CGPoint, view: SchematicView) {
        view.construction = nil
    }
}