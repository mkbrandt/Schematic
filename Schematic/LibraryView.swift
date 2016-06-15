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

class LibraryManager: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate
{
    @IBOutlet var librariesTable: NSTableView!
    @IBOutlet var componentsTable: NSOutlineView!
    @IBOutlet var preview: LibraryPreview!
    @IBOutlet var librarySplitView: NSView!
    
    var openLibs: [SchematicDocument] = []
    var currentIndex: Int = 0
    var currentLib: SchematicDocument?  {
        if currentIndex < openLibs.count {
            return openLibs[currentIndex]
        }
        return nil
    }
    
    var components: Set<Component>  { return currentLib?.components ?? [] }
    var sortedComponents: [Component] {
        return components.sort { $0.sortName < $1.sortName }
    }
    
    var bookmarks: [NSData] {
        let answer: [NSData] = openLibs.flatMap { (lib: SchematicDocument) in
            let bookmark = try? lib.fileURL?.bookmarkDataWithOptions(NSURLBookmarkCreationOptions.WithSecurityScope, includingResourceValuesForKeys: nil, relativeToURL: nil)
            if let bookmark = bookmark {
                return bookmark
            }
            return nil
        }
        return answer
    }
    
    //var packages: Set<Package>      { return Set(components.flatMap { $0.package }) }
    //var sortedPackages: [Package]   { return packages.sort { $0.sortName < $1.sortName } }
    
    func setViewState() {
        if openLibs.count == 0 {
            librarySplitView.hidden = true
        } else {
            librarySplitView.hidden = false
        }
    }
    
    override func awakeFromNib() {
        setViewState()
    }
    
    func openLibraryURL(url: NSURL) {
        do {
            let lib = try SchematicDocument(contentsOfURL: url, ofType: "")
            openLibs.append(lib)
            currentIndex = openLibs.count - 1
            componentsTable.reloadData()
            librariesTable.reloadData()
        } catch(let err) {
            print("Error opening: \(err)")
        }
        setViewState()
    }
    
    func openLibrariesByBookmark(bookmarks: [NSData]) {
        for bookmark in bookmarks {
            var stale: ObjCBool = false
            if let url = try? NSURL(byResolvingBookmarkData: bookmark, options: .WithSecurityScope, relativeToURL: nil, bookmarkDataIsStale: &stale) {
                url.startAccessingSecurityScopedResource()
                openLibraryURL(url)
            }
        }
    }
    
    func openLibrarysByURL(urls: [NSURL]) {
        for url in urls {
            openLibraryURL(url)
        }
    }
    
    @IBAction func openLibrary(sender: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["sch"]
        openPanel.runModal()
        let urls = openPanel.URLs
        openLibrarysByURL(urls)
    }
    
    @IBAction func closeLibrary(sender: AnyObject) {
        if currentIndex >= 0 && currentIndex < openLibs.count {
            let lib = openLibs.removeAtIndex(currentIndex)
            lib.close()
        }
        setViewState()
        currentIndex = 0
        librariesTable.reloadData()
        componentsTable.reloadData()
    }
    
    @IBAction func openKiCadLibrary(sender: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["lib"]
        openPanel.runModal()
        let urls = openPanel.URLs
        for url in urls {
            let lib = SchematicDocument()
            let ripper = KLibRipper()
            if let text = try? String(contentsOfURL: url, encoding: NSUTF8StringEncoding) {
                ripper.ripString(text, document: lib)
                openLibs.append(lib)
                currentIndex = openLibs.count - 1
                componentsTable.reloadData()
                librariesTable.reloadData()
            }
        }
    }

// MARK: TableView Data and Delegate
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if tableView == librariesTable {
            return openLibs.count
        } else if tableView == componentsTable {
            return sortedComponents.count
        }
        return 0
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        if tableView == librariesTable {
            return openLibs[row]
        } else {
            let comp = sortedComponents[row]
            return comp.sortName
        }
    }
    
    func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        if tableView == librariesTable {
            currentIndex = row
            componentsTable.reloadData()
        } else {
            preview.component = sortedComponents[row]
        }
        return true
    }

// MARK: Outline View Data and Delegate
    
    func outlineView(outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        if let currentLib = currentLib where item == nil {
            return currentLib.pages[index]
        } else if let page = item as? SchematicPage {
            let components = page.displayList.flatMap { $0 as? Component }
            //let packages = Set(components.flatMap { $0.package }).sort { $0.partNumber < $1.partNumber }
            return components[index]
        }
        return "---"
    }
    
    func outlineView(outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if item == nil {
            return currentLib?.pages.count ?? 0
        } else if let page = item as? SchematicPage {
            let components = page.displayList.flatMap { $0 as? Component }
            //let packages = Set(components.flatMap { $0.package }).sort { $0.partNumber < $1.partNumber }
            return components.count
        }
        return 0
    }
    
    func outlineView(outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        return item is SchematicPage
    }
    
    func outlineView(outlineView: NSOutlineView, objectValueForTableColumn tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject? {
        if let page = item as? SchematicPage {
            return page.name
        } else if let package = item as? Package {
            return package.partNumber ?? package.components.first?.value ?? "---"
        } else if let component = item as? Component {
            return component.value
        }
        return "-"
    }
    
    func outlineView(outlineView: NSOutlineView, shouldSelectItem item: AnyObject) -> Bool {
        if let package = item as? Package, let component = package.components.first {
            preview.component = component
        } else if let component = item as? Component {
            preview.component = component
        }
        return true
    }
}
