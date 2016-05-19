//
//  Document.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let GridSize: CGFloat = 10.0
let MajorGridSize: CGFloat = 100.0

class SchematicDocumentState: NSObject, NSCoding
{
    var pages: [SchematicPage] = [SchematicPage()]
    var currentPage: Int = 0
    
    override init() {
        super.init()
    }
    
    required init?(coder decoder: NSCoder) {
        pages = decoder.decodeObjectForKey("pages") as? [SchematicPage] ?? [SchematicPage()]
        currentPage = decoder.decodeIntegerForKey("currentPage")
    }
    
    func encodeWithCoder(encoder: NSCoder) {
        encoder.encodeObject(pages, forKey: "pages")
        encoder.encodeInteger(currentPage, forKey: "currentPage")
    }
}

class SchematicDocument: NSDocument {
    
    @IBOutlet var drawingView: SchematicView?
    @IBOutlet var newPageDialog: NewPageDialog?
    
    var state = SchematicDocumentState()
    
    var pages: [SchematicPage] {
        get { return state.pages }
        set { state.pages = newValue }
    }
    
    var currentPage: Int {
        get { return state.currentPage }
        set {
            state.currentPage = newValue
            drawingView?.needsDisplay = true
        }
    }
    
    var page: SchematicPage {
        return pages[currentPage]
    }
    
    var displayList: [SCHGraphic] {
        get { return page.displayList }
        set { page.displayList = newValue }
    }
    
    var pageRect: CGRect {
        get { return page.pageRect }
        set { page.pageSize = newValue.size }
    }
    
    override init() {
        super.init()
    }

    override class func autosavesInPlace() -> Bool {
        return true
    }

    override var windowNibName: String? {
        return "SchematicDocument"
    }

    override func dataOfType(typeName: String) throws -> NSData
    {
        let data = NSKeyedArchiver.archivedDataWithRootObject(state)
        
        return data
    }
    
    override func readFromData(data: NSData, ofType typeName: String) throws
    {
        if let state = NSKeyedUnarchiver.unarchiveObjectWithData(data) as? SchematicDocumentState {
            self.state = state
            currentPage = 0
        } else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
    }

    // MARK: Window Delegate
    
    func windowDidResize(notification: NSNotification) {
        drawingView?.zoomByFactor(2)
        drawingView?.zoomByFactor(0.5)
    }
    
    // MARK: Printing
    
    override func runPageLayout(sender: AnyObject?) {
        runModalPageLayoutWithPrintInfo(printInfo, delegate: self, didRunSelector: #selector(SchematicDocument.pageLayoutDone), contextInfo: nil)
    }
    
    func pageLayoutDone(context: AnyObject?) {
        page.pageSize = printInfo.imageablePageBounds.size * (100.0 / 72.0)
    }
    
    override func preparePageLayout(pageLayout: NSPageLayout) -> Bool {
        //pageLayout.addAccessoryController(pageLayoutAccessory)
        return true
    }
    
    enum PrinterError: ErrorType {
        case NoViewError
    }
    
    var printSaveZoomState = ZoomState(scale: 1, centerPoint: CGPoint())
    
    override func printOperationWithSettings(printSettings: [String : AnyObject]) throws -> NSPrintOperation {
        if let drawingView = drawingView {
            let operation = NSPrintOperation(view: drawingView, printInfo: printInfo)
            return operation
        } else {
            throw PrinterError.NoViewError
        }
    }
    
    func document(document: NSDocument, didPrintSuccessfully: Bool,  contextInfo: UnsafeMutablePointer<Void>) {
        drawingView?.zoomState = printSaveZoomState
        drawingView?.constrainViewToSuperview = true
        drawingView?.needsDisplay = true
    }
    
    override func printDocument(sender: AnyObject?) {
        if let drawingView = drawingView {
            drawingView.constrainViewToSuperview = false        // allow random zooming
            printSaveZoomState = drawingView.zoomState
            drawingView.zoomToAbsoluteScale(0.72 * printInfo.scalingFactor)
            printDocumentWithSettings([:], showPrintPanel: true, delegate: self, didPrintSelector: #selector(SchematicDocument.document(_:didPrintSuccessfully:contextInfo:)), contextInfo: nil)
        }
    }
    
    // MARK: Actions
    
    @IBAction func newPage(sender: AnyObject) {
        newPageDialog?.nameField.stringValue = "Page_\(pageSeq)"
        drawingView?.window?.beginSheet(newPageDialog!) { response in
            if response != NSModalResponseOK {
                return
            } else {
                let newPage = SchematicPage()
                
                self.pages.append(newPage)
                self.currentPage = self.pages.count - 1
            }
        }
        
    }
    
    @IBAction func deletePage(sender: AnyObject) {
        
    }
}

class NewPageDialog: NSWindow
{
    @IBOutlet var nameField: NSTextField!
    
    override var canBecomeKeyWindow: Bool {
        return true
    }
    
    @IBAction func ok(sender: AnyObject?) {
        sheetParent?.endSheet(self, returnCode: NSModalResponseOK)
        orderOut(self)
    }
    
    @IBAction func cancel(sender: AnyObject?) {
        sheetParent?.endSheet(self, returnCode: NSModalResponseCancel)
        orderOut(self)
    }
}
