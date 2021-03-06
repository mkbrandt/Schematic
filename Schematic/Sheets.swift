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
    
    @IBAction func ok(_ sender: AnyObject) {
        sheetParent?.endSheet(self, returnCode: NSApplication.ModalResponse.OK)
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        sheetParent?.endSheet(self, returnCode: NSApplication.ModalResponse.cancel)
    }
}

class PackagingSheet: NSWindow
{
    @IBOutlet var prefixField: NSTextField!
    @IBOutlet var footprintField: NSTextField!
    @IBOutlet var partNumberField: NSTextField!
    @IBOutlet var vendorField: NSTextField!
    
    @IBAction func ok(_ sender: AnyObject) {
        sheetParent?.endSheet(self, returnCode: NSApplication.ModalResponse.OK)
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        sheetParent?.endSheet(self, returnCode: NSApplication.ModalResponse.cancel)
    }
}

class QandASheet: NSWindow
{
    @IBOutlet var questionField: NSTextField!
    @IBOutlet var answerField: NSTextField!
    @IBOutlet var okButton: NSButton!
    @IBOutlet var cancelButton: NSButton!
    
    func askQuestion(question: String, in window: NSWindow?, completion: @escaping (_ answer: String?) -> ()) {
        questionField.stringValue = question

        window?.beginSheet(self) { response in
            self.orderOut(self)
            if response != NSApplication.ModalResponse.OK {
                completion(nil)
            } else {
                completion(self.answerField.stringValue)
            }
        }
    }
    
    @IBAction func ok(_ sender: AnyObject) {
        sheetParent?.endSheet(self, returnCode: NSApplication.ModalResponse.OK)
    }
    
    @IBAction func cancel(_ sender: AnyObject) {
        sheetParent?.endSheet(self, returnCode: NSApplication.ModalResponse.cancel)
    }
    
}
