//
//  SchematicView.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let DefaultPasteOffset = CGPoint(x: GridSize, y: -GridSize)

class SchematicView: ZoomView
{
    @IBOutlet var document: SchematicDocument!
    
    @IBOutlet var componentSheet: ComponentSheet!
    @IBOutlet var packagingSheet: PackagingSheet!
    
    var displayList: Set<Graphic> {
        get { return document.page.displayList }
        set { document.page.displayList = newValue }
    }
    
    var construction: Graphic?
    
    var selection: Set<Graphic> = [] {
        willSet {
            willChangeValue(forKey: "selection")
            for g in selection {
                g.selected = false
            }
        }
        didSet {
            didChangeValue(forKey: "selection")
            for g in selection {
                g.selected = true
            }
            justPasted = false
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
            resetCursorRects()
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

    var _trackingArea: NSTrackingArea?
    
    var pasteOrigin = CGPoint()
    var pasteOffset = DefaultPasteOffset
    var justPasted = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        viewSetup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        viewSetup()
    }
    
    func viewSetup() {
        register(forDraggedTypes: [SchematicElementUTI])
    }
    
    func scaleFloat(_ f: CGFloat) -> CGFloat {
        return f / scale
    }
    
    func snapToGrid(_ point: CGPoint) -> CGPoint {
        if shouldSnapToGrid {
            let x = round(point.x / GridSize) * GridSize
            let y = round(point.y / GridSize) * GridSize
            return CGPoint(x: x, y: y)
        } else {
            return point
        }
    }
    
    var selectRadius: CGFloat {
        return scaleFloat(5)
    }

    override func awakeFromNib()
    {
        window?.acceptsMouseMovedEvents = true
        tool.selectedTool(self)
        updateTrackingAreas()
        register(forDraggedTypes: [SchematicElementUTI])
    }
    
    override func updateTrackingAreas()
    {
        let options: NSTrackingAreaOptions = [.mouseMoved, .mouseEnteredAndExited, .activeAlways]
        
        if _trackingArea != nil {
            removeTrackingArea(_trackingArea!)
        }
        _trackingArea = NSTrackingArea(rect: visibleRect, options: options, owner: self, userInfo: nil)
        addTrackingArea(_trackingArea!)
    }

    override func resetCursorRects()
    {
        discardCursorRects()
        addCursorRect(visibleRect, cursor: tool.cursor)
    }

    func drawBorder(_ dirtyRect: CGRect) {
        let borderWidth: CGFloat = 10
        let outsideBorderRect = pageRect.insetBy(dx: 10, dy: 10)
        let insideBorderRect = outsideBorderRect.insetBy(dx: borderWidth, dy: borderWidth)
        NSBezierPath.setDefaultLineWidth(2.0)
        NSBezierPath.stroke(insideBorderRect)
        NSBezierPath.setDefaultLineWidth(0.5)
        NSBezierPath.stroke(outsideBorderRect)
        NSBezierPath.strokeLine(from: insideBorderRect.topLeft, to: outsideBorderRect.topLeft)
        NSBezierPath.strokeLine(from: insideBorderRect.bottomLeft, to: outsideBorderRect.bottomLeft)
        NSBezierPath.strokeLine(from: insideBorderRect.topRight, to: outsideBorderRect.topRight)
        NSBezierPath.strokeLine(from: insideBorderRect.bottomRight, to: outsideBorderRect.bottomRight)
        let horizontalDivisions = Int(insideBorderRect.size.width / 200 )
        let verticalDivisions = Int(insideBorderRect.size.height / 200)
        let horizontalGridSize = insideBorderRect.size.width / CGFloat(horizontalDivisions)
        let verticalGridSize = insideBorderRect.size.height / CGFloat(verticalDivisions)
        
        for i in 1 ..< horizontalDivisions {
            let x = CGFloat(i) * horizontalGridSize + insideBorderRect.left
            NSBezierPath.strokeLine(from: CGPoint(x: x, y: insideBorderRect.top), to: CGPoint(x: x, y: outsideBorderRect.top))
            NSBezierPath.strokeLine(from: CGPoint(x: x, y: insideBorderRect.bottom), to: CGPoint(x: x, y: outsideBorderRect.bottom))
        }
        
        let font = NSFont.systemFont(ofSize: borderWidth * 0.8)
        let attributes = [NSFontAttributeName: font]
        
        for i in 0 ..< horizontalDivisions {
            let label = "\(i)" as NSString
            let labelWidth = label.size(withAttributes: attributes).width
            let x = CGFloat(i) * horizontalGridSize + insideBorderRect.left + horizontalGridSize / 2 - labelWidth / 2
            label.draw(at: CGPoint(x: x, y: insideBorderRect.top + borderWidth * 0.1), withAttributes: attributes)
            label.draw(at: CGPoint(x: x, y: outsideBorderRect.bottom + borderWidth * 0.1), withAttributes: attributes)
        }
        
        for i in 1 ..< verticalDivisions {
            let y = CGFloat(i) * verticalGridSize + insideBorderRect.bottom
            NSBezierPath.strokeLine(from: CGPoint(x: outsideBorderRect.left, y: y), to: CGPoint(x: insideBorderRect.left, y: y))
            NSBezierPath.strokeLine(from: CGPoint(x: outsideBorderRect.right, y: y), to: CGPoint(x: insideBorderRect.right, y: y))
        }
        
        let charLabels: [NSString] = ["A", "B", "C", "D", "E", "F", "G", "H", "J", "K", "L", "M", "N", "P", "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z"]
        for i in 0 ..< verticalDivisions {
            let labelIndex = verticalDivisions - i - 1
            if labelIndex < charLabels.count {
                let label = charLabels[labelIndex]
                let labelSize = label.size(withAttributes: attributes)
                let y = CGFloat(i) * verticalGridSize + insideBorderRect.bottom + verticalGridSize / 2 - labelSize.height / 2
                label.draw(at: CGPoint(x: outsideBorderRect.left + borderWidth / 2 - labelSize.width / 2, y: y), withAttributes: attributes)
                label.draw(at: CGPoint(x: insideBorderRect.right + borderWidth / 2 - labelSize.width / 2, y: y), withAttributes: attributes)
            }
        }
    }
    
    func drawGridInRect(_ dirtyRect: CGRect)
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
            
            NSColor.blue().withAlphaComponent(0.5).set()
            var x = xs
            while x <= right {
                let isMajor = fmod((x / GridSize), divsPerMajor) == 0
                let linewidth = CGFloat(isMajor ? 0.25 : 0.1)
                if drawMajor && isMajor || drawMinor {
                    NSBezierPath.setDefaultLineWidth(scaleFloat(linewidth))
                    NSBezierPath.strokeLine(from: CGPoint(x: x, y: top), to: CGPoint(x: x, y: bottom))
                }
                x += GridSize
            }
            
            var y = ys
            while y <= top {
                let isMajor = fmod((y / GridSize), divsPerMajor) == 0
                let linewidth = CGFloat(isMajor ? 0.25 : 0.1)
                if drawMajor && isMajor || drawMinor {
                    NSBezierPath.setDefaultLineWidth(scaleFloat(linewidth))
                    NSBezierPath.strokeLine(from: CGPoint(x: left, y: y), to: CGPoint(x: right, y: y))
                }
                y += GridSize
            }
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let context = NSGraphicsContext.current()?.cgContext
        
        context?.setLineJoin(.round)
        context?.setLineCap(.round)
        NSEraseRect(dirtyRect)
        drawBorder(dirtyRect)
        drawGridInRect(dirtyRect)
        
        for g in displayList {
            g.drawInRect(dirtyRect)
        }
        
        if let g = construction {
            g.drawInRect(dirtyRect)
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
            setNeedsDisplay(construction.bounds.insetBy(dx: -5, dy: -5))
        }
    }

// MARK: Adding and Deleting elements
    
    func addGraphics(_ graphics: Set<Graphic>) {
        document.willChangeValue(forKey: "unplacedComponents")
        displayList.formUnion(graphics)
        document.didChangeValue(forKey: "unplacedComponents")
        undoManager?.prepare(withInvocationTarget: self).deleteGraphics(graphics)
        needsDisplay = true
    }
    
    func addGraphic(_ graphic: Graphic) {
        addGraphics([graphic])
    }
    
    func deleteGraphics(_ graphics: Set<Graphic>) {
        let attrs = selection.flatMap { $0 as? AttributeText }
        removeAttributes(attrs)
        document.willChangeValue(forKey: "unplacedComponents")
        graphics.forEach { $0.unlink(self) }
        displayList.subtract(graphics)
        undoManager?.prepare(withInvocationTarget: self).addGraphics(graphics)
        document.didChangeValue(forKey: "unplacedComponents")
        needsDisplay = true
    }
    
    func deleteGraphic(_ graphic: Graphic) {
        //if graphic is Net { Swift.print("deleting NET \(graphic.graphicID)") }
        deleteGraphics([graphic])
    }
    
    func deleteSelection() {
        if selection.count > 0 {
            deleteGraphics(selection)
            selection = []
            needsDisplay = true
        }
    }
    
    func addAttributes(_ attrs: [AttributeText], owners: [AttributedGraphic?]) {
        undoManager?.registerUndoWithTarget(self, handler: { (_) in
            self.removeAttributes(attrs)
        })
        for i in 0 ..< attrs.count {
            if let owner = owners[i] {
                attrs[i].owner = owner
            }
        }
    }
    
    func removeAttributes(_ attrs: [AttributeText]) {
        let owners = attrs.map { $0.owner }
        undoManager?.registerUndoWithTarget(self, handler: { (_) in
            self.addAttributes(attrs, owners: owners)
        })
        for attr in attrs {
            attr.owner = nil
        }
    }

// MARK: Selection
    
    func selectionRectAtPoint(_ point: CGPoint) -> CGRect {
        return CGRect(x: point.x - selectRadius, y: point.y - selectRadius, width: selectRadius * 2, height: selectRadius * 2)
    }
    
    func findGraphicAtPoint(_ location: CGPoint, selectionFirst: Bool = true) -> Graphic? {
        let srect = selectionRectAtPoint(location)
        if selectionFirst {
            for g in selection {
                if g.intersectsRect(srect) {
                    return g
                }
            }
        }
        
        for g in displayList {
            if g.intersectsRect(srect) {
                return g
            }
        }
        return nil
    }
    
    func findElementAtPoint(_ location: CGPoint) -> Graphic? {
        if let g = findGraphicAtPoint(location, selectionFirst: false) {
            return g.elementAtPoint(location)
        }
        return nil
    }
    
    func findElementsAtPoint(_ location: CGPoint) -> [Graphic] {
        let graphics = Set(displayList.filter {$0.intersectsRect(selectionRectAtPoint(location)) })
        return graphics.flatMap { $0.elementAtPoint(location) }
    }
    
    func selectInRect(_ rect: CGRect) {
        selection = Set(displayList.filter { $0.intersectsRect(rect) })
    }
    
    override func changeFont(_ sender: AnyObject?) {
        for g in selection {
            if let text = g as? AttributeText {
                text.font = NSFontPanel.shared().convert(text.font)
            }
        }
        needsDisplay = true
    }

// MARK: Mouse Handling
    
    var dragOrigin = CGPoint()
    
    override func mouseDown(_ theEvent: NSEvent) {
        let location = self.convert(theEvent.locationInWindow, from: nil)
        if selection.count == 0 {
            pasteOrigin = snapToGrid(location)
        }
        
        if theEvent.clickCount > 1 {
            tool.doubleClick(location, view: self)
        } else {
            tool.mouseDown(location, view: self)
        }
        redrawConstruction()
    }
    
    override func mouseDragged(_ theEvent: NSEvent) {
        let location = self.convert(theEvent.locationInWindow, from: nil)
        
        redrawConstruction()
        tool.mouseDragged(location, view: self)
        redrawConstruction()
    }
    
    override func mouseMoved(_ theEvent: NSEvent) {
        let location = self.convert(theEvent.locationInWindow, from: nil)
        
        redrawConstruction()
        tool.mouseMoved(location, view: self)
        redrawConstruction()
    }
    
    override func mouseUp(_ theEvent: NSEvent) {
        let location = self.convert(theEvent.locationInWindow, from: nil)
        
        redrawConstruction()
        tool.mouseUp(location, view: self)
        redrawConstruction()
    }
    
    override func flagsChanged(_ theEvent: NSEvent) {
        controlKeyDown = theEvent.modifierFlags.contains(.control)
    }
    
    override func keyDown(_ theEvent: NSEvent) {
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
    
    func adjustPosition(_ g: Graphic) {
        if let group = g as? GroupGraphic {
            for g in group.contents {
                adjustPosition(g)
            }
        } else if let comp = g as? Component {
            if let p1 = comp.pins.first?.origin {
                let p2 = self.snapToGrid(p1)
                g.moveBy(p2 - p1)
            }
        }
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        // this is a kludge because enumerateDraggingItems doesn't seem to find anything
        if let source = sender.draggingSource() as? PinInspectorPreview {
            let pin = source.pinCopy
            let location = snapToGrid(convert(sender.draggingLocation(), from: nil))
            source.updatePinAttributes(self)
            pin.moveTo(location)
            construction = pin
            needsDisplay = true
            return .copy
        } else if let table = sender.draggingSource() as? NSTableView, let source = table.dataSource as? UnplacedcomponentsTableViewDataSource {
            if let g = source.draggedComponent {
                //Swift.print("Got graphic: \(g)")
                construction = g
                let location = snapToGrid(convert(sender.draggingLocation(), from: nil))
                construction?.moveTo(location)
                needsDisplay = true
                sender.enumerateDraggingItems(.clearNonenumeratedImages, for: self, classes: [], searchOptions: [:]) { _ in }
                return .move
            }
        }
        sender.enumerateDraggingItems(.clearNonenumeratedImages, for: self, classes: [Graphic.self], searchOptions: [:]) { (item, n, stop) in
            if let g = item.item as? Graphic {
                let fr = item.draggingFrame
                let image = NSImage(size: CGSize(width: 1, height: 1))
                item.setDraggingFrame(fr, contents: image)
                self.construction = g
                let location = self.snapToGrid(self.convert(sender.draggingLocation(), from: nil))
                g.moveTo(location)
                self.adjustPosition(g)
                self.needsDisplay = true
                return
            }
        }
        return NSDragOperation()
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let location = snapToGrid(convert(sender.draggingLocation(), from: nil))
        if let g = construction {
            g.moveTo(location)
            adjustPosition(g)
        }
        needsDisplay = true
        return .copy
    }
    
    override func draggingExited(_ sender: NSDraggingInfo?) {
        construction = nil
        needsDisplay = true
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let component = construction as? Component {
            component.package?.assignReference(document)
            adjustPosition(component)
        }
        addConstruction()
        needsDisplay = true
        return true
    }
    
// MARK: Printing
    
    var printSize: NSSize {
        let printRect = document.printInfo.imageablePageBounds
        let printScale = document.printInfo.scalingFactor
        let width = printRect.size.width * 100 / (72 * printScale)
        let height = printRect.size.height * 100 / (72 * printScale)
        return NSSize(width: width, height: height)
    }
    
    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        let hcount = ceil(pageRect.size.width / printSize.width)
        let vcount = ceil(pageRect.size.height / printSize.height)
        let numPages = document.pages.count
        //let r = NSRange(1...Int(hcount * vcount * CGFloat(numPages)))
        range.pointee = NSMakeRange(1, Int(hcount * vcount * CGFloat(numPages)))
        return true
    }
    
    override func rectForPage(_ page: Int) -> NSRect {
        let pageIndex = page - 1
        let hcount = ceil(pageRect.size.width / printSize.width)
        let vcount = ceil(pageRect.size.height / printSize.height)
        let perPage = Int(hcount * vcount)
        let thisPage = pageIndex / perPage
        document.currentPage = thisPage
        needsDisplay = true
        let thisPageIndex = pageIndex % perPage
        let v = CGFloat(thisPageIndex / Int(hcount))
        let h = CGFloat(thisPageIndex % Int(hcount))
        let x = h * printSize.width
        let y = v * printSize.height
        return CGRect(x: x, y: y, width: printSize.width, height: printSize.height)
    }
    
// MARK: Actions
    
    func clearButtonStates() {
        if let toolbar = window?.toolbar {
            for item in toolbar.items {
                if let button = item.view as? NSButton {
                    button.state = NSOffState
                }
            }
        }
    }

    @IBAction func showFontPanel(_ sender: AnyObject) {
        NSFontPanel.shared().orderFront(self)
    }
    
    @IBAction func selectLineTool(_ sender: NSButton) {
        tool = LineTool()
        clearButtonStates()
        sender.state = NSOnState
    }
    
    @IBAction func selectRectTool(_ sender: NSButton) {
        tool = RectTool()
        clearButtonStates()
        sender.state = NSOnState
    }
    
    @IBAction func selectArrowTool(_ sender: NSButton) {
        tool = SelectTool()
        clearButtonStates()
        sender.state = NSOnState
    }
    
    @IBAction func selectArcTool(_ sender: NSButton) {
        tool = ArcTool()
        clearButtonStates()
        sender.state = NSOnState
    }
    
    @IBAction func selectCircleTool(_ sender: NSButton) {
        tool = CircleTool()
        clearButtonStates()
        sender.state = NSOnState
    }
    
    @IBAction func selectPolygonTool(_ sender: NSButton) {
        tool = PolygonTool()
        clearButtonStates()
        sender.state = NSOnState
    }
    
    @IBAction func selectTextTool(_ sender: NSButton) {
        tool = TextTool()
        clearButtonStates()
        sender.state = NSOnState
    }
    
    @IBAction func selectNetNameTool(_ sender: NSButton) {
        tool = NetNameTool()
        clearButtonStates()
        sender.state = NSOnState
    }
    
    @IBAction func selectNetTool(_ sender: NSButton) {
        tool = NetTool()
        clearButtonStates()
        sender.state = NSOnState
    }
    
    @IBAction func cut(_ sender: AnyObject) {
        copy(sender)
        delete(sender)
    }
    
    @IBAction func copy(_ sender: AnyObject) {
        let pasteBoard = NSPasteboard.general()
        
        pasteBoard.clearContents()
        let group = GroupGraphic(contents: selection)
        pasteOrigin = group.origin
        pasteOffset = DefaultPasteOffset
        pasteBoard.writeObjects(Array(selection))
    }
    
    @IBAction func paste(_ sender: AnyObject) {
        let pasteBoard = NSPasteboard.general()
        let classes = [Graphic.self]
        if pasteBoard.canReadObject(forClasses: classes, options: [:]) {
            if let graphics = pasteBoard.readObjects(forClasses: [Graphic.self], options:[:]) as? [Graphic] {
                let graphicSet = Set(graphics)
                let group = GroupGraphic(contents: graphicSet)
                group.moveTo(pasteOrigin + pasteOffset)
                pasteOrigin = group.origin
                addGraphics(graphicSet)
                graphicSet.forEach {
                    if let comp = $0 as? Component {
                        comp.package?.assignReference(document)
                    }
                    adjustPosition($0)
                }
                selection = graphicSet
                justPasted = true
            }
        }
    }
    
    @IBAction func delete(_ sender: AnyObject) {
        deleteSelection()
    }
    
    @IBAction func group(_ sender: AnyObject) {
        guard selection.count > 1 else { return }
        let g = GroupGraphic(contents: selection)
        deleteSelection()
        addGraphic(g)
        selection = [g]
        needsDisplay = true
    }
    
    @IBAction func ungroup(_ sender: AnyObject) {
        var newSelection: Set<Graphic> = []
        for g in selection {
            if let g = g as? GroupGraphic {
                newSelection.formUnion(g.contents)
                deleteGraphic(g)
                addGraphics(g.contents)
            } else {
                newSelection.insert(g)
            }
        }
        selection = newSelection
        needsDisplay = true
    }
    
    @IBAction func flipHorizontal(_ sender: AnyObject) {
        guard selection.count > 0 else { return }
        let g = GroupGraphic(contents: selection)
        g.flipHorizontalAroundPoint(g.centerPoint)
        adjustPosition(g)
        needsDisplay = true
    }

    @IBAction func flipVertical(_ sender: AnyObject) {
        guard selection.count > 0 else { return }
        let g = GroupGraphic(contents: selection)
        g.flipVerticalAroundPoint(g.centerPoint)
        adjustPosition(g)
        needsDisplay = true
    }
    
    @IBAction func rotateSelection(_ sender: AnyObject) {
        guard selection.count > 0 else { return }
        let g = GroupGraphic(contents: selection)
        g.rotateByAngle(PI / 2, center: g.centerPoint)
        selection.forEach { adjustPosition($0) }
        needsDisplay = true
    }
    
    @IBAction func createComponent(_ sender: AnyObject) {
        guard selection.count > 0 else { return }
        window?.beginSheet(componentSheet) { response in
            self.componentSheet.orderOut(self)
            if response == NSModalResponseOK {
                self.performCreateComponent()
            }
        }
    }
    
    func performCreateComponent() {
        let outline = GroupGraphic(contents: Set(selection.filter { !($0 is AttributedGraphic) }))
        let pins = Set(selection.filter { $0 is Pin } as! [Pin])
        let component = Component(origin: outline.origin, pins: pins, outline: outline)
        component.attributeTexts.insert(AttributeText(origin: component.bounds.topLeft, format: "=value", owner: component))
        component.value = componentSheet.nameField.stringValue
        deleteGraphics(outline.contents)
        deleteGraphics(component.pins)
        addGraphic(component)
        selection = [component]
        needsDisplay = true
        if componentSheet.packageSingleCheckbox.state == NSOnState {
            createPackage(self)
        }
    }
    
    @IBAction func ungroupComponents(_ sender: AnyObject) {
        var newSelection: Set<Graphic> = []
        for g in selection {
            if let comp = g as? Component {
                if let group = comp.outline as? GroupGraphic {
                    comp.outline = nil
                    newSelection.formUnion(group.contents)
                }
                let pins: Set<Graphic> = comp.pins
                comp.pins = []
                newSelection.formUnion(pins)
                addGraphics(Set(newSelection))
                deleteGraphic(comp)
            } else {
                newSelection.insert(g)
            }
        }
        selection = newSelection
        needsDisplay = true
    }
    
    @IBAction func createPackage(_ sender: AnyObject) {
        let components = selection.filter { $0 is Component } as! [Component]
        if components.count > 0 {
            window?.beginSheet(packagingSheet) { response in
                self.packagingSheet.orderOut(self)
                if response == NSModalResponseOK {
                    self.packagingSheet.orderOut(self)
                    self.performPackaging(Set(components))
                }
            }
        }
    }
    
    func performPackaging(_ components: Set<Component>) {
        let package = Package(components: components)
        package.prefix = packagingSheet.prefixField.stringValue
        package.partNumber = packagingSheet.partNumberField.stringValue
        package.footprint = packagingSheet.footprintField.stringValue
        package.manufacturer = packagingSheet.vendorField.stringValue
        package.assignReference(document)
        components.forEach {
            let refDes = AttributeText(origin: $0.bounds.topLeft, format: "=refDes", owner: $0)
            let partNumber = AttributeText(origin: refDes.bounds.topLeft, format: "=partNumber", owner: $0)
            $0.attributeTexts.insert(refDes)
            $0.attributeTexts.insert(partNumber)
        }
    }
    
    @IBAction func ungroupPackages(_ sender: AnyObject) {
        let components = selection.flatMap { $0 as? Component }
        let packages = Set(components.flatMap { $0.package })
        for pkg in packages {
            pkg.components = []
        }
        needsDisplay = true
    }
    
}
