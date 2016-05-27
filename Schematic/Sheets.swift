//
//  Sheets.swift
//  Schematic
//
//  Created by Matt Brandt on 5/24/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class ComponentSheet: NSWindow
{
    @IBOutlet var nameField: NSTextField!
    @IBOutlet var packageSingleCheckbox: NSButton!
    
    @IBAction func ok(sender: AnyObject) {
        sheetParent?.endSheet(self, returnCode: NSModalResponseOK)
    }
    
    @IBAction func cancel(sender: AnyObject) {
        sheetParent?.endSheet(self, returnCode: NSModalResponseCancel)
    }
}

class PackagingSheet: NSWindow
{
    @IBOutlet var prefixField: NSTextField!
    @IBOutlet var footprintField: NSTextField!
    @IBOutlet var partNumberField: NSTextField!
    
    @IBAction func ok(sender: AnyObject) {
        sheetParent?.endSheet(self, returnCode: NSModalResponseOK)
    }
    
    @IBAction func cancel(sender: AnyObject) {
        sheetParent?.endSheet(self, returnCode: NSModalResponseCancel)
    }
}
