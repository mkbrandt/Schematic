//
//  SchematicView.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let testComponent = "left{ CLOCK:5, -, DATA0: 4, DATA1: 3, DATA2: 2, DATA3: 1}" +
                    "right{ DIR: 12, -, OUT0: 11, OUT1: 10, OUT2: 9, OUT3: 8}" +
                    "top{ VCC: 14}" + "bottom{GND: 7, VSS: 6, GND: 13}"

class SchematicView: ZoomView
{
    @IBOutlet var document: SchematicDocument!
    
    var displayList: [SCHGraphic] {
        get { return document.page.displayList }
        set { document.page.displayList = newValue }
    }
    
    var construction: SCHGraphic?
    
    var selection: [SCHGraphic] = [] {
        willSet {
            willChangeValueForKey("selection")
            for g in selection {
                g.selected = false
            }
        }
        didSet {
            didChangeValueForKey("selection")
            for g in selection {
                g.selected = true
            }
        }
    }
    
    var tool: Tool = SelectTool() {
        willSet {
            tool.unselectedTool(self)
            tool.cursor.pop()
        }
        didSet {
            selection = []
            construction = nil
            tool.selectedTool(self)
            tool.cursor.push()
        }
    }
    
    var controlKeyDown = false
    var gridSnapPref = true
    var shouldSnapToGrid: Bool { return gridSnapPref != controlKeyDown }
    
    override var pageRect: CGRect! {
        return document?.pageRect ?? CGRect(x: 0, y: 0, width: 17 * 100, height: 11 * 100)
    }
    
    override var canBecomeKeyView: Bool         { return true }
    override var acceptsFirstResponder: Bool    { return true }
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([SchematicElementUTI])
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([SchematicElementUTI])
    }
    
    func scaleFloat(f: CGFloat) -> CGFloat {
        return f / scale
    }
    
    func snapToGrid(point: CGPoint) -> CGPoint {
        if shouldSnapToGrid {
            let x = round(point.x / GridSize) * GridSize
            let y = round(point.y / GridSize) * GridSize
            return CGPoint(x: x, y: y)
        } else {
            return point
        }
    }

    func drawBorder(dirtyRect: CGRect) {
        let borderWidth: CGFloat = 10
        let outsideBorderRect = pageRect.insetBy(dx: 10, dy: 10)
        let insideBorderRect = outsideBorderRect.insetBy(dx: borderWidth, dy: borderWidth)
        NSBezierPath.setDefaultLineWidth(2.0)
        NSBezierPath.strokeRect(insideBorderRect)
        NSBezierPath.setDefaultLineWidth(0.5)
        NSBezierPath.strokeRect(outsideBorderRect)
        NSBezierPath.strokeLineFromPoint(insideBorderRect.topLeft, toPoint: outsideBorderRect.topLeft)
        NSBezierPath.strokeLineFromPoint(insideBorderRect.bottomLeft, toPoint: outsideBorderRect.bottomLeft)
        NSBezierPath.strokeLineFromPoint(insideBorderRect.topRight, toPoint: outsideBorderRect.topRight)
        NSBezierPath.strokeLineFromPoint(insideBorderRect.bottomRight, toPoint: outsideBorderRect.bottomRight)
        let horizontalDivisions = Int(insideBorderRect.size.width / 200 )
        let verticalDivisions = Int(insideBorderRect.size.height / 200)
        let horizontalGridSize = insideBorderRect.size.width / CGFloat(horizontalDivisions)
        let verticalGridSize = insideBorderRect.size.height / CGFloat(verticalDivisions)
        
        for i in 1 ..< horizontalDivisions {
            let x = CGFloat(i) * horizontalGridSize + insideBorderRect.left
            NSBezierPath.strokeLineFromPoint(CGPoint(x: x, y: insideBorderRect.top), toPoint: CGPoint(x: x, y: outsideBorderRect.top))
            NSBezierPath.strokeLineFromPoint(CGPoint(x: x, y: insideBorderRect.bottom), toPoint: CGPoint(x: x, y: outsideBorderRect.bottom))
        }
        
        let font = NSFont.systemFontOfSize(borderWidth * 0.8)
        let attributes = [NSFontAttributeName: font]
        
        for i in 0 ..< horizontalDivisions {
            let label = "\(i)" as NSString
            let labelWidth = label.sizeWithAttributes(attributes).width
            let x = CGFloat(i) * horizontalGridSize + insideBorderRect.left + horizontalGridSize / 2 - labelWidth / 2
            label.drawAtPoint(CGPoint(x: x, y: insideBorderRect.top + borderWidth * 0.1), withAttributes: attributes)
            label.drawAtPoint(CGPoint(x: x, y: outsideBorderRect.bottom + borderWidth * 0.1), withAttributes: attributes)
        }
        
        for i in 1 ..< verticalDivisions {
            let y = CGFloat(i) * verticalGridSize + insideBorderRect.bottom
            NSBezierPath.strokeLineFromPoint(CGPoint(x: outsideBorderRect.left, y: y), toPoint: CGPoint(x: insideBorderRect.left, y: y))
            NSBezierPath.strokeLineFromPoint(CGPoint(x: outsideBorderRect.right, y: y), toPoint: CGPoint(x: insideBorderRect.right, y: y))
        }
        
        let charLabels: [NSString] = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
        for i in 0 ..< verticalDivisions {
            let labelIndex = verticalDivisions - i - 1
            if labelIndex < charLabels.count {
                let label = charLabels[labelIndex]
                let labelSize = label.sizeWithAttributes(attributes)
                let y = CGFloat(i) * verticalGridSize + insideBorderRect.bottom + verticalGridSize / 2 - labelSize.height / 2
                label.drawAtPoint(CGPoint(x: outsideBorderRect.left + borderWidth / 2 - labelSize.width / 2, y: y), withAttributes: attributes)
                label.drawAtPoint(CGPoint(x: insideBorderRect.right + borderWidth / 2 - labelSize.width / 2, y: y), withAttributes: attributes)
            }
        }
    }
    
    func drawGridInRect(dirtyRect: CGRect)
    {
        if NSGraphicsContext.currentContextDrawingToScreen() {
            let divsPerMajor: CGFloat = 10
            let drawMinor = GridSize * scale > 4
            let drawMajor = MajorGridSize * scale > 4
            let xs = floor((dirtyRect.origin.x - GridSize) / GridSize) * GridSize
            let ys = floor((dirtyRect.origin.y - GridSize) / GridSize) * GridSize
            let top = dirtyRect.origin.y + dirtyRect.size.height + GridSize
            let bottom = dirtyRect.origin.y - GridSize
            let left = dirtyRect.origin.x - GridSize
            let right = dirtyRect.origin.x + dirtyRect.size.width + GridSize
            
            NSColor.blueColor().colorWithAlphaComponent(0.5).set()
            var x = xs
            while x <= right {
                let isMajor = fmod((x / GridSize), divsPerMajor) == 0
                let linewidth = CGFloat(isMajor ? 0.25 : 0.1)
                if drawMajor && isMajor || drawMinor {
                    NSBezierPath.setDefaultLineWidth(scaleFloat(linewidth))
                    NSBezierPath.strokeLineFromPoint(CGPoint(x: x, y: top), toPoint: CGPoint(x: x, y: bottom))
                }
                x += GridSize
            }
            
            var y = ys
            while y <= top {
                let isMajor = fmod((y / GridSize), divsPerMajor) == 0
                let linewidth = CGFloat(isMajor ? 0.25 : 0.1)
                if drawMajor && isMajor || drawMinor {
                    NSBezierPath.setDefaultLineWidth(scaleFloat(linewidth))
                    NSBezierPath.strokeLineFromPoint(CGPoint(x: left, y: y), toPoint: CGPoint(x: right, y: y))
                }
                y += GridSize
            }
        }
    }

    override func drawRect(dirtyRect: NSRect) {
        NSEraseRect(dirtyRect)
        drawBorder(dirtyRect)
        drawGridInRect(dirtyRect)
        
        for g in displayList {
            g.drawInRect(dirtyRect, view: self)
        }
        
        if let g = construction {
            g.drawInRect(dirtyRect, view: self)
        }
    }
    
    func addConstruction() {
        if let construction = construction {
            addGraphic(construction)
        }
        construction = nil
    }
    
    func redrawConstruction() {
        if let construction = construction {
            setNeedsDisplayInRect(construction.bounds.insetBy(dx: -5, dy: -5))
        }
    }

// MARK: Adding and Deleting elements
    
    func addGraphics(graphics: [SCHGraphic]) {
        displayList.appendContentsOf(graphics)
        undoManager?.prepareWithInvocationTarget(self).deleteGraphics(graphics)
        needsDisplay = true
    }
    
    func addGraphic(graphic: SCHGraphic) {
        addGraphics([graphic])
    }
    
    func deleteGraphics(graphics: [SCHGraphic]) {
        displayList = displayList.filter { !graphics.contains($0) }
        undoManager?.prepareWithInvocationTarget(self).addGraphics(graphics)
        needsDisplay = true
    }
    
    func deleteGraphic(graphic: SCHGraphic) {
        deleteGraphics([graphic])
    }
    
    func deleteSelection() {
        if selection.count > 0 {
            deleteGraphics(selection)
            selection = []
            needsDisplay = true
        }
    }

// MARK: Selection
    
    func selectionRectAtPoint(point: CGPoint) -> CGRect {
        return CGRect(x: point.x - SelectRadius, y: point.y - SelectRadius, width: SelectRadius * 2, height: SelectRadius * 2)
    }
    
    func findGraphicAtPoint(location: CGPoint) -> SCHGraphic? {
        let srect = selectionRectAtPoint(location)
        for g in selection {
            if g.intersectsRect(srect) {
                return g
            }
        }
        
        for g in displayList {
            if g.intersectsRect(srect) {
                return g
            }
        }
        return nil
    }
    
    func findElementAtPoint(location: CGPoint) -> SCHGraphic? {
        if let g = findGraphicAtPoint(location) {
            return g.elementAtPoint(location)
        }
        return nil
    }
    
    func selectInRect(rect: CGRect) {
        selection = displayList.filter { $0.intersectsRect(rect) }
    }
    
// MARK: Mouse Handling
    
    override func mouseDown(theEvent: NSEvent) {
        let location = self.convertPoint(theEvent.locationInWindow, fromView: nil)
        
        if theEvent.clickCount > 1 {
            let el = findElementAtPoint(location)
            
            Swift.print("element is \(el?.description)")
        }
        tool.mouseDown(location, view: self)
        redrawConstruction()
    }
    
    override func mouseDragged(theEvent: NSEvent) {
        let location = self.convertPoint(theEvent.locationInWindow, fromView: nil)
        
        redrawConstruction()
        tool.mouseDragged(location, view: self)
        redrawConstruction()
    }
    
    override func mouseMoved(theEvent: NSEvent) {
        let location = self.convertPoint(theEvent.locationInWindow, fromView: nil)
        
        redrawConstruction()
        tool.mouseMoved(location, view: self)
        redrawConstruction()
    }
    
    override func mouseUp(theEvent: NSEvent) {
        let location = self.convertPoint(theEvent.locationInWindow, fromView: nil)
        
        redrawConstruction()
        tool.mouseUp(location, view: self)
        redrawConstruction()
    }
    
    override func flagsChanged(theEvent: NSEvent) {
        controlKeyDown = theEvent.modifierFlags.contains(.ControlKeyMask)
    }
    
    override func keyDown(theEvent: NSEvent) {
        if tool is SelectTool {
            switch theEvent.keyCode {
            case 51, 117:
                deleteSelection()
            default:
                nextResponder?.keyDown(theEvent)
            }
        } else {
            tool.keyDown(theEvent, view: self)
        }
    }

// MARK: Drag and Drop
    
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        // this is a kludge because enumerateDraggingItems doesn't seem to find anything
        if let source = sender.draggingSource() as? PinInspectorPreview {
            let pin = source.pinCopy
            let location = snapToGrid(convertPoint(sender.draggingLocation(), fromView: nil))
            source.updatePinAttributes(self)
            pin.moveTo(location)
            construction = pin
            needsDisplay = true
        }
        // Why doesn't this work?
        sender.enumerateDraggingItemsWithOptions(.ClearNonenumeratedImages, forView: self, classes: [SCHGraphic.self], searchOptions: [:]) { (item, n, stop) in
            if let g = item.item as? SCHGraphic {
                let fr = item.draggingFrame
                let image = NSImage(size: CGSize(width: 1, height: 1))
                item.setDraggingFrame(fr, contents: image)
                self.construction = g
                let location = self.snapToGrid(self.convertPoint(sender.draggingLocation(), fromView: nil))
                self.construction?.moveTo(location)
                self.needsDisplay = true
            }
        }
        return .None
    }
    
    override func draggingUpdated(sender: NSDraggingInfo) -> NSDragOperation {
        let location = snapToGrid(convertPoint(sender.draggingLocation(), fromView: nil))
        construction?.moveTo(location)
        needsDisplay = true
        return .Copy
    }
    
    override func draggingExited(sender: NSDraggingInfo?) {
        construction = nil
        needsDisplay = true
    }
    
    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        addConstruction()
        needsDisplay = true
        return true
    }

// MARK: Actions
    
    @IBAction func selectLineTool(sender: AnyObject) {
        tool = LineTool()
    }
    
    @IBAction func selectRectTool(sender: AnyObject) {
        tool = RectTool()
    }
    
    @IBAction func selectArrowTool(sender: AnyObject) {
        tool = SelectTool()
    }
    
    @IBAction func selectArcTool(sender: AnyObject) {
        tool = ArcTool()
    }
    
    @IBAction func selectCircleTool(sender: AnyObject) {
        tool = CircleTool()
    }
    
    @IBAction func cut(sender: AnyObject) {
        copy(sender)
        delete(sender)
    }
    
    @IBAction func copy(sender: AnyObject) {
        let pasteBoard = NSPasteboard.generalPasteboard()
        
        pasteBoard.clearContents()
        pasteBoard.writeObjects(selection)
    }
    
    @IBAction func paste(sender: AnyObject) {
        let pasteBoard = NSPasteboard.generalPasteboard()
        let classes = [SCHGraphic.self]
        if pasteBoard.canReadObjectForClasses(classes, options: [:]) {
            if let graphics = pasteBoard.readObjectsForClasses([SCHGraphic.self], options:[:]) as? [SCHGraphic] {
                addGraphics(graphics)
                selection = graphics
            }
        }
    }
    
    @IBAction func delete(sender: AnyObject) {
        deleteSelection()
    }
    
    @IBAction func group(sender: AnyObject) {
        guard selection.count > 1 else { return }
        let g = GroupGraphic(contents: selection)
        deleteSelection()
        addGraphic(g)
        selection = [g]
        needsDisplay = true
    }
    
    @IBAction func ungroup(sender: AnyObject) {
        var newSelection: [SCHGraphic] = []
        for g in selection {
            if let g = g as? GroupGraphic {
                newSelection.appendContentsOf(g.contents)
                deleteGraphic(g)
                addGraphics(g.contents)
            } else {
                newSelection.append(g)
            }
        }
        selection = newSelection
        needsDisplay = true
    }
    
    @IBAction func flipHorizontal(sender: AnyObject) {
        guard selection.count > 0 else { return }
        let g = GroupGraphic(contents: selection)
        g.flipHorizontalAroundPoint(g.centerPoint)
        needsDisplay = true
    }

    @IBAction func flipVertical(sender: AnyObject) {
        guard selection.count > 0 else { return }
        let g = GroupGraphic(contents: selection)
        g.flipVerticalAroundPoint(g.centerPoint)
        needsDisplay = true
    }
}