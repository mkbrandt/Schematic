//
//  SelectTool.swift
//  Schematic
//
//  Created by Matt Brandt on 5/16/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

var undoSequence = 0

class Tool: NSObject
{
    var cursor: NSCursor { return NSCursor.crosshair() }
    
    func keyDown(_ theEvent: NSEvent, view: SchematicView) {
    }
    
    func selectedTool(_ view: SchematicView) {
    }
    
    func unselectedTool(_ view: SchematicView) {
    }
    
    func doubleClick(_ location: CGPoint, view: SchematicView) {
    }
    
    func mouseDown(_ location: CGPoint, view: SchematicView) {
    }
    
    func mouseMoved(_ location: CGPoint, view: SchematicView) {
    }
    
    func mouseDragged(_ location: CGPoint, view: SchematicView) {
    }
    
    func mouseUp(_ location: CGPoint, view: SchematicView) {
    }
}

enum SelectMode {
    case moveHandle(Graphic, Int), moveGraphic(Graphic), moveGroup(Set<Graphic>), selectRect, select
}

class SelectTool: Tool
{
    var startPoint = CGPoint()
    var mode = SelectMode.select
    
    override var cursor: NSCursor { return NSCursor.arrow() }
    
    func redrawSelection(_ view: SchematicView) {
        let rect = view.selection.reduce(CGRect()) { $0 + $1.bounds.insetBy(dx: -view.selectRadius, dy: -view.selectRadius) }
        view.setNeedsDisplay(rect)
    }
    
    func netsToNodes(_ group: Set<Graphic>) -> Set<Graphic> {
        var newGroup: Set<Graphic> = []
        for g in group {
            if let net = g as? Net {
                newGroup.insert(net.originNode)
                newGroup.insert(net.endPointNode)
                newGroup.formUnion(net.attributeTexts as Set<Graphic>)
            } else {
                newGroup.insert(g)
            }
        }
        return newGroup
    }
    
    override func doubleClick(_ location: CGPoint, view: SchematicView) {
        redrawSelection(view)
        if let el = view.findElementAtPoint(location) {
            if let net = el as? Net {
                view.selection = net.logicallyConnectedNets(view)
            } else {
                view.selection = [el]
            }
        } else {
            view.selection = []
        }
        redrawSelection(view)
    }
    
    override func mouseDown(_ location: CGPoint, view: SchematicView) {
        undoSequence += 1
        startPoint = location
        redrawSelection(view)
        view.undoManager?.beginUndoGrouping()
        if view.selection.count > 0 {
            for g in view.selection {
                if let ht = g.hitTest(location, threshold: view.selectRadius) {
                    switch ht {
                    case .hitsOn(_):
                        let selection = netsToNodes(view.selection)
                        mode = .moveGroup(selection)
                        selection.forEach {
                            let p = $0.origin
                            view.undoManager?.registerUndoWithTarget($0) { (g) in
                                g.moveTo(p, view: view)
                                view.needsDisplay = true
                            }
                        }
                    case .hitsPoint(let gr, let h):
                        let p = gr.points[h]
                        view.undoManager?.registerUndoWithTarget(gr, handler: { (gg) in
                            gg.setPoint(p, index: h, view: view)
                            view.needsDisplay = true
                        })
                        mode = .moveHandle(gr, h)
                    }
                    return
                }
            }
        }
        let rect = CGRect(x: location.x - view.selectRadius / 2, y: location.y - view.selectRadius / 2, width: view.selectRadius, height: view.selectRadius)
        view.selectInRect(rect)
        if view.selection.count > 0 {
            let selection = netsToNodes(view.selection)
            mode = .moveGroup(selection)
            selection.forEach {
                let p = $0.origin
                view.undoManager?.registerUndoWithTarget($0) { (g) in
                    g.moveTo(p, view: view)
                    view.needsDisplay = true
                }
            }
            redrawSelection(view)
            return
        }
        mode = .selectRect
    }
    
    override func mouseDragged(_ location: CGPoint, view: SchematicView) {
        redrawSelection(view)
        switch mode {
        case .selectRect:
            let rect = rectContainingPoints([location, startPoint])
            let rg = RectGraphic(origin: rect.origin, size: rect.size)
            rg.color = NSColor.red()
            rg.lineWeight = 0.5
            view.construction = rg
            view.selectInRect(rect)
            view.setNeedsDisplay(rect.insetBy(dx: -view.selectRadius, dy: -view.selectRadius))
        case .moveGraphic(let g):
            let offset = view.snapToGrid(location) - view.snapToGrid(startPoint)
            if offset.x == 0 && offset.y == 0 {
                return
            }
            startPoint = location
            g.moveBy(offset, view: view)
            g.designCheck(view)
        case .moveGroup(let gs):
            let offset = view.snapToGrid(location) - view.snapToGrid(startPoint)
            if offset.x == 0 && offset.y == 0 {
                return
            }
            startPoint = location
            gs.forEach { $0.moveBy(offset, view: view) }
            gs.forEach { $0.designCheck(view) }
            if view.justPasted {
                view.pasteOrigin = view.pasteOrigin + offset
                view.pasteOffset = view.pasteOffset + offset
            }
        case .moveHandle(let g, let h):
            g.setPoint(view.snapToGrid(location), index: h)
        default:
            break
        }
        redrawSelection(view)
    }
    
    override func mouseUp(_ location: CGPoint, view: SchematicView) {
        view.construction = nil
        if view.undoManager?.groupingLevel > 0 {
            view.undoManager?.endUndoGrouping()
        }
    }
}
