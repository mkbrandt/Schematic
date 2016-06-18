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
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return document.pages.count
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        let page = document.pages[row]
        
        return page.name
    }
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        document.currentPage = row
        schematic.needsDisplay = true
        return true
    }
    
    @IBAction func changePageName(_ sender: NSTextField) {
        guard pageTable.selectedRow >= 0 else { return }
        let page = document.pages[pageTable.selectedRow]
        page.name = sender.stringValue
    }

    @IBAction func addPage(_ sender: AnyObject) {
        let page = SchematicPage()
        insertPage(page, index: document.pages.count)
    }
    
    func deletePageAtIndex(_ index: Int) {
        let page = document.pages[index]
        document.undoManager?.registerUndoWithTarget(self, handler: { _ in
            self.insertPage(page, index: index)
        })
        if document.pages.count > 1 {
            document.pages.remove(at: index)
            if document.currentPage >= index {
                document.currentPage -= 1
            }
        }
        schematic.needsDisplay = true
        pageTable.reloadData()
    }
    
    func insertPage(_ page: SchematicPage, index: Int) {
        if index <= document.pages.count {
            document.pages.insert(page, at: index)
            schematic.needsDisplay = true
            document.undoManager?.registerUndoWithTarget(self, handler: { _ in
                self.deletePageAtIndex(index)
            })
        }
        pageTable.reloadData()
    }
    
    @IBAction func deletePage(_ sender: AnyObject) {
        deletePageAtIndex(document.currentPage)
    }
}
