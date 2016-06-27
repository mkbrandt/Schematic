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
    @IBOutlet var drawingView: SchematicView?
    
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
                drawingView?.selection = [component]     // make it show in the graphic inspector
            }
            needsDisplay = true
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        NSEraseRect(dirtyRect)
        component?.drawInRect(bounds)
    }
    
    // Dragging
    
    override func mouseDown(_ theEvent: NSEvent) {
        if let component = component {
            let item = NSDraggingItem(pasteboardWriter: component)
            item.setDraggingFrame(component.bounds, contents: component.image)
            beginDraggingSession(with: [item], event: theEvent, source: self)
        }
    }
    
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        return .copy
    }
}

extension SchematicDocument
{
    var categories: [SchematicPage]     { return schematic.pages.filter { $0.parentPage == nil }}
}

extension SchematicPage
{
    var categories: [SchematicPage]     { return childPages.sorted { $0.name < $1.name } }
}

class LibraryManager: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, SchematicDelegate
{
    @IBOutlet var librariesTable: NSTableView!
    @IBOutlet var componentsTable: NSOutlineView!
    @IBOutlet var preview: LibraryPreview!
    @IBOutlet var librarySplitView: NSView!
    
    var currentSelectedPage: SchematicPage?
    var currentSelectedComponent: Component?    { return preview.component }
    
    var openLibs: [SchematicDocument] = []
    var currentIndex: Int = 0
    var currentLib: SchematicDocument?  {
        if currentIndex < openLibs.count {
            return openLibs[currentIndex]
        }
        return nil
    }
    
    var bookmarks: [Data] {
        let answer: [Data] = openLibs.dropFirst().flatMap { lib in
            let bookmark = try? lib.fileURL?.bookmarkData(NSURL.BookmarkCreationOptions.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            if let bookmark = bookmark {
                return bookmark
            }
            return nil
        }
        return answer
    }
    
    func setViewState() {
        if openLibs.count == 0 {
            librarySplitView.isHidden = true
        } else {
            librarySplitView.isHidden = false
        }
    }
    
    func documentDidChangeStructure() {
        forceRefresh()
    }
    
    func forceRefresh() {
        DispatchQueue.main.async {
            self.librariesTable.reloadData()
            self.componentsTable.reloadData()
        }
    }
    
    override func awakeFromNib() {
        if openLibs.count == 0 {
            openLibs.append(cloudLibrary)
            cloudLibrary.subscribeToChanges(delegate: self)
            forceRefresh()
        }
        setViewState()
    }
    
    func openLibraryURL(_ url: URL) {
        do {
            let sch = try SchematicDocument(contentsOf: url, ofType: "")
            openLibs.append(sch)
            sch.subscribeToChanges(delegate: self)
            currentIndex = openLibs.count - 1
            forceRefresh()
        } catch(let err) {
            print("Error opening: \(err)")
        }
        setViewState()
    }
    
    func openLibrariesByBookmark(_ bookmarks: [Data]) {
        for bookmark in bookmarks {
            var stale: ObjCBool = false
            if let url = try? (NSURL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) as URL) {
                _ = url.startAccessingSecurityScopedResource()
                openLibraryURL(url)
            }
        }
    }
    
    func openLibrarysByURL(_ urls: [URL]) {
        for url in urls {
            openLibraryURL(url)
        }
    }
    
    @IBAction func openLibrary(_ sender: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["sch"]
        openPanel.runModal()
        let urls = openPanel.urls
        openLibrarysByURL(urls)
    }
    
    @IBAction func closeLibrary(_ sender: AnyObject) {
        if currentIndex > 0 && currentIndex < openLibs.count {
            let lib = openLibs.remove(at: currentIndex)
            lib.close()
            lib.fileURL?.stopAccessingSecurityScopedResource()
        }
        setViewState()
        currentIndex = 0
        librariesTable.reloadData()
        componentsTable.reloadData()
    }
    
    @IBAction func openKiCadLibrary(_ sender: AnyObject) {
        let openPanel = NSOpenPanel()
        openPanel.allowedFileTypes = ["lib"]
        openPanel.runModal()
        let urls = openPanel.urls
        for url in urls {
            let lib = SchematicDocument()
            let ripper = KLibRipper()
            let text = String(contentsOfURL: url, encoding: String.Encoding.utf8)
            ripper.ripString(text, document: lib)
            openLibs.append(lib)
            currentIndex = openLibs.count - 1
            componentsTable.reloadData()
            librariesTable.reloadData()
        }
    }
    
    @IBAction func deleteSelected(_ sender: AnyObject) {
        if let lib = currentLib {
            if let component = currentSelectedComponent {
                lib.delete(component: component)
            } else if let page = currentSelectedPage {
                lib.delete(page: page)
            }
        }
    }
    
    func unhook() {
        for lib in openLibs {
            lib.unsubscribeToChanges(delegate: self)
        }
    }
    
    func writePartsToLibrary(components: [Component]) {
        if let lib = currentLib {
            if let page = currentSelectedPage {
                lib.insert(components: components, in: page, at: 0)
            }
        }
    }

// MARK: TableView Data and Delegate
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return openLibs.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        return openLibs[row].name
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        currentIndex = row
        componentsTable.reloadData()
        return true
    }

// MARK: OutlineView Data and Delegate
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: AnyObject?) -> AnyObject {
        //print("self = \(self), index = \(currentIndex), current lib = \(currentLib), count = \(currentLib?.categories.count)")
        if let currentLib = currentLib where item == nil {
            return currentLib.categories[index]
        } else if let category = item as? SchematicPage {
            let subcategories = category.categories
            let components = category.components.sorted { $0.name < $1.name }
            //let freeComponents = components.filter { $0.package == nil }
            //let packages = Set(components.flatMap { $0.package }).sorted { $0.partNumber < $1.partNumber }
            if index < subcategories.count {
                return subcategories[index]
            //} else if index - subcategories.count < freeComponents.count {
            //    return freeComponents[index - subcategories.count]
            //} else {
            //    return packages[index - subcategories.count - freeComponents.count]
            //}
            } else {
                return components[index - subcategories.count]
            }
        }
        return "WTF"
    }
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: AnyObject?) -> Int {
        if item == nil {
            //print("self = \(self), index = \(currentIndex), current lib = \(currentLib), count = \(currentLib?.categories.count)")
            return currentLib?.categories.count ?? 0
        } else if let category = item as? SchematicPage {
            let subcategories = category.categories
            let components = category.components
            //let freeComponents = components.filter { $0.package == nil }
            //let packages = Set(components.flatMap { $0.package }).sorted { $0.partNumber < $1.partNumber }
            //return subcategories.count + packages.count + freeComponents.count
            return subcategories.count + components.count
        }
        return 0
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: AnyObject) -> Bool {
        return item is SchematicPage
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: AnyObject?) -> AnyObject? {
        if let category = item as? SchematicPage {
            return category.name
        } else if let package = item as? Package {
            return package.components.first?.name ?? "UNNAMED"
        } else if let component = item as? Component {
            return component.name
        }
        return "-"
    }
    
    func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: AnyObject) -> Bool {
        currentSelectedPage = nil
        if let package = item as? Package, let component = package.components.first {
            preview.component = component
        } else if let component = item as? Component {
            preview.component = component
        } else {
            if let page = item as? SchematicPage {
                currentSelectedPage = page
            }
            preview.component = nil
        }
        Swift.print("selected page = \(currentSelectedPage?.name), object = \(preview.component?.name)")
        return true
    }
}
