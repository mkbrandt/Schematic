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
    case moveHandle(Graphic, Int), moveGroup(Set<Graphic>), selectRect, select
}

class SelectTool: Tool
{
    var startPoint = CGPoint()
    var mode = SelectMode.select
    var shouldSaveUndo = false
    
    override var cursor: NSCursor { return NSCursor.arrow() }
    
    func redrawSelection(_ view: SchematicView) {
        let rect = view.selection.reduce(CGRect()) { $0 + $1.bounds.insetBy(dx: -view.selectRadius, dy: -view.selectRadius) }
        view.setNeedsDisplay(rect)
    }
    
    func uniqueNets(_ group: Set<Graphic>) -> Set<Graphic> {
        var group = group
        var newGroup: Set<Graphic> = []
        var netsGathered: Set<Net> = []
        
        for g in group {
            if let comp = g as? Component {
                group.formUnion(comp.connectedNets as Set<Graphic>)
            }
        }
        
        for g in group {
            if let net = g as? Net where !netsGathered.contains(net) {
                newGroup.insert(net)
                let physicalNet = net.physicallyConnectedNets([])
                netsGathered.formUnion(physicalNet)
                let looseAttributes = Set(physicalNet.flatMap { $0.attributeTexts })
                newGroup.formUnion(looseAttributes as Set<Graphic>)
            } else {
                newGroup.insert(g)
            }
        }
        return newGroup
    }
    
    func refreshMovableGroup(_ group: Set<Graphic>, view: SchematicView) {
        if var rect = group.first?.bounds {
            var nets: Set<Net> = []
            for g in group {
                if let comp = g as? Component {
                    rect.formUnion(comp.bounds)
                    nets.formUnion(comp.connectedNets)
                } else if let net = g as? Net {
                    nets.insert(net)
                } else {
                    rect.formUnion(g.bounds)
                }
            }
            var phyNets: Set<Net> = []
            nets.forEach { phyNets.formUnion($0.physicallyConnectedNets([])) }
            phyNets.forEach { rect.formUnion($0.bounds) }
            view.setNeedsDisplay(rect.insetBy(dx: -5, dy: -5))
        }
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
        shouldSaveUndo = true
        startPoint = location
        redrawSelection(view)
        if view.selection.count > 0 {
            for g in view.selection {
                if let ht = g.hitTest(location, threshold: view.selectRadius) {
                    switch ht {
                    case .hitsOn(_):
                        let selection = uniqueNets(view.selection)
                        mode = .moveGroup(selection)
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
            let selection = uniqueNets(view.selection)
            mode = .moveGroup(selection)
            redrawSelection(view)
            return
        }
        mode = .selectRect
    }
    
    override func mouseDragged(_ location: CGPoint, view: SchematicView) {
        switch mode {
        case .selectRect:
            redrawSelection(view)
            let rect = rectContainingPoints([location, startPoint])
            let rg = RectGraphic(origin: rect.origin, size: rect.size)
            rg.color = NSColor.red()
            rg.lineWeight = 0.5
            view.construction = rg
            view.selectInRect(rect)
            view.setNeedsDisplay(rect.insetBy(dx: -view.selectRadius, dy: -view.selectRadius))
            redrawSelection(view)
        case .moveGroup(let gs):
            refreshMovableGroup(gs, view: view)
            if shouldSaveUndo {
                view.undoManager?.beginUndoGrouping()
                gs.forEach { $0.saveUndoState(view: view) }
                shouldSaveUndo = false
            }
            let offset = view.snapToGrid(location) - view.snapToGrid(startPoint)
            if offset.x == 0 && offset.y == 0 {
                return
            }
            startPoint = location
            gs.forEach { $0.moveBy(offset) }
            gs.forEach { $0.designCheck(view) }
            if view.justPasted {
                view.pasteOrigin = view.pasteOrigin + offset
                view.pasteOffset = view.pasteOffset + offset
            }
            refreshMovableGroup(gs, view: view)
        case .moveHandle(let g, let h):
            redrawSelection(view)
            g.setPoint(view.snapToGrid(location), index: h)
            redrawSelection(view)
        default:
            break
        }
    }
    
    override func mouseUp(_ location: CGPoint, view: SchematicView) {
        if view.undoManager?.groupingLevel > 0 {
            view.undoManager?.endUndoGrouping()
        }
        view.construction = nil
    }
}
