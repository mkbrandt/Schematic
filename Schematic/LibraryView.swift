//
//  LibraryView.swift
//  Schematic
//
//  Created by Matt Brandt on 5/26/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class LibraryPreview: NSView, NSDraggingSource
{
    var component: Component? {
        didSet {
            if let component = component {
                let csize = component.bounds.size
                let hr = csize.height / frame.size.height
                let wr = csize.width / frame.size.width
                let r = max(max(hr, wr), 0.5)
                let size = frame.size * r
                let offset = CGPoint(x: size.width - csize.width, y: size.height - csize.height) / 2
                bounds = CGRect(origin: component.bounds.origin - offset, size: size).insetBy(dx: -5, dy: -5)
            }
            needsDisplay = true
        }
    }
    
    override func drawRect(dirtyRect: NSRect) {
        NSEraseRect(dirtyRect)
        component?.drawInRect(bounds)
    }
    
    // Dragging
    
    override func mouseDown(theEvent: NSEvent) {
        if let component = component {
            let item = NSDraggingItem(pasteboardWriter: component)
            item.setDraggingFrame(component.bounds, contents: component.image)
            beginDraggingSessionWithItems([item], event: theEvent, source: self)
        }
    }
    
    func draggingSession(session: NSDraggingSession, sourceOperationMaskForDraggingContext context: NSDraggingContext) -> NSDragOperation {
        return .Copy
    }
}

class LibraryManager: NSObject, NSTableViewDataSource, NSTableViewDelegate
{
    @IBOutlet var librariesTable: NSTableView!
    @IBOutlet var componentsTable: NSTableView!
    @IBOutlet var preview: LibraryPreview!
    
    var openLibs: [SchematicDocument] = []
    var currentIndex: Int = 0
    var currentLib: SchematicDocument?  {
        if currentIndex < openLibs.count {
            return openLibs[currentIndex]
        }
        return nil
    }
    
    var components: Set<Component>  { return currentLib?.components ?? [] }
    var packages: Set<Package>      { return Set(components.flatMap { $0.package }) }
    var sortedPackages: [Package]   { return packages.sort { $0.sortName < $1.sortName } }
    
    @IBAction func openLibrary(sender: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["sch"]
        openPanel.runModal()
        let urls = openPanel.URLs
        for url in urls {
            if let lib = try? SchematicDocument(contentsOfURL: url, ofType: "sch") {
                openLibs.append(lib)
                currentIndex = openLibs.count - 1
                componentsTable.reloadData()
                librariesTable.reloadData()
            }
        }
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if tableView == librariesTable {
            return openLibs.count
        } else if tableView == componentsTable {
            return sortedPackages.count
        }
        return 0
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        if tableView == librariesTable {
            return openLibs[row]
        } else {
            let pkg = sortedPackages[row]
            return pkg.sortName
        }
    }
    
    func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if tableView == librariesTable {
            currentIndex = row
            componentsTable.reloadData()
        } else {
            preview.component = sortedPackages[row].components.first
        }
        return true
    }
}
