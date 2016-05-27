//
//  LibraryView.swift
//  Schematic
//
//  Created by Matt Brandt on 5/17/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class UnplacedcomponentsTableViewDataSource: NSObject, NSTableViewDataSource
{
    @IBOutlet var document: SchematicDocument!
    @IBOutlet var tableView: NSTableView!
    
    var draggedComponent: Component?
    
    override func awakeFromNib() {
        document.addObserver(self, forKeyPath: "unplacedComponents", options: .New, context: nil)
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        tableView?.reloadData()
    }
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return document.unplacedComponents.count
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        let components = document.unplacedComponents.sort { $0.partNumber < $1.partNumber }
        
        return components[row]
    }
    
    func tableView(tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let components = document.unplacedComponents.sort { $0.partNumber < $1.partNumber }
        
        draggedComponent = components[row]
        return components[row]
    }
}
