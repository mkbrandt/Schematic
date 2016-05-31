//
//  PageInspector.swift
//  Schematic
//
//  Created by Matt Brandt on 5/27/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class PageInspector: NSView, NSTableViewDataSource, NSTableViewDelegate
{
    @IBOutlet var document: SchematicDocument!
    @IBOutlet var schematic: SchematicView!
    @IBOutlet var pageTable: NSTableView!
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return document.pages.count
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        let page = document.pages[row]
        
        return page.name
    }
    
    func tableView(tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        document.currentPage = row
        schematic.needsDisplay = true
        return true
    }
    
    @IBAction func changePageName(sender: NSTextField) {
        let page = document.pages[pageTable.selectedRow]
        page.name = sender.stringValue
    }

    @IBAction func addPage(sender: AnyObject) {
        let page = SchematicPage()
        insertPage(page, index: document.pages.count)
    }
    
    func deletePageAtIndex(index: Int) {
        let page = document.pages[index]
        document.undoManager?.registerUndoWithTarget(self, handler: { _ in
            self.insertPage(page, index: index)
        })
        if document.pages.count > 1 {
            document.pages.removeAtIndex(index)
            if document.currentPage >= index {
                document.currentPage -= 1
            }
        }
        schematic.needsDisplay = true
        pageTable.reloadData()
    }
    
    func insertPage(page: SchematicPage, index: Int) {
        if index <= document.pages.count {
            document.pages.insert(page, atIndex: index)
            schematic.needsDisplay = true
            document.undoManager?.registerUndoWithTarget(self, handler: { _ in
                self.deletePageAtIndex(index)
            })
        }
        pageTable.reloadData()
    }
    
    @IBAction func deletePage(sender: AnyObject) {
        deletePageAtIndex(document.currentPage)
    }
}
