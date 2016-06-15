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

var printInColor = false

/*
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
*/

class Schematic: NSObject, NSCoding
{
    var pages: [SchematicPage] = [SchematicPage()]
    var currentPage: Int = 0
    var openLibraries: [NSData] = []
    var printInfoDict: [String: AnyObject] = [:]
    var savedScale: CGFloat?
    var centeredPoint = CGPoint()
    
    override init() {
        super.init()
    }
    
    required init?(coder decoder: NSCoder) {
        pages = decoder.decodeObjectForKey("pages") as? [SchematicPage] ?? [SchematicPage()]
        currentPage = decoder.decodeIntegerForKey("currentPage")
        if let libs = decoder.decodeObjectForKey("libraries") as? [NSData] {
            openLibraries = libs
        }
        if let printInfo = decoder.decodeObjectForKey("printInfo") as? [String: AnyObject] {
            printInfoDict = printInfo
        }
        if let scale = decoder.decodeObjectForKey("savedScale") {
            centeredPoint = decoder.decodePointForKey("centeredPoint")
            savedScale = CGFloat(scale.doubleValue)
        }
    }
    
    func encodeWithCoder(encoder: NSCoder) {
        encoder.encodeObject(pages, forKey: "pages")
        encoder.encodeInteger(currentPage, forKey: "currentPage")
        encoder.encodeObject(openLibraries, forKey: "libraries")
        encoder.encodeObject(printInfoDict, forKey: "printInfo")
        if let savedScale = savedScale {
            let scale = NSNumber(double: Double(savedScale))
            encoder.encodeObject(scale, forKey: "savedScale")
            encoder.encodePoint(centeredPoint, forKey: "centeredPoint")
        }
    }
}

class SchematicDocument: NSDocument {
    
    @IBOutlet var drawingView: SchematicView?
    @IBOutlet var newPageDialog: NewPageDialog?
    @IBOutlet var pageLayoutAccessory: SchematicPageLayoutController?
    @IBOutlet var libraryManager: LibraryManager?
    @IBOutlet var octopartWindow: OctoPartWindow?
    @IBOutlet var netlistAccessory: NSView?
    @IBOutlet var netlistChooser: NSPopUpButton?
    
    var schematic = Schematic()
    
    var pages: [SchematicPage] {
        get { return schematic.pages }
        set { schematic.pages = newValue }
    }
    
    var currentPage: Int {
        get { return schematic.currentPage }
        set {
            schematic.currentPage = newValue
            drawingView?.needsDisplay = true
        }
    }
    
    var page: SchematicPage {
        return pages[currentPage]
    }
    
    var displayList: [Graphic] {
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
        if let libs = libraryManager?.bookmarks {
            schematic.openLibraries = libs
        }
        schematic.savedScale = drawingView?.scale
        schematic.centeredPoint = drawingView?.centeredPointInDocView ?? CGPoint()
        let data = NSKeyedArchiver.archivedDataWithRootObject(schematic)
        
        return data
    }
    
    override func readFromData(data: NSData, ofType typeName: String) throws
    {
        let doc = NSKeyedUnarchiver.unarchiveObjectWithData(data)
        if let schematic = doc as? Schematic {
            self.schematic = schematic
            printInfo = NSPrintInfo(dictionary: schematic.printInfoDict)
        } else {
            throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
        }
    }
    
    override func awakeFromNib() {
        libraryManager?.openLibrariesByBookmark(schematic.openLibraries)
        printInColor = Defaults.boolForKey("printColor")
        if let scale = schematic.savedScale {
            drawingView?.zoomToFit(self)
            drawingView?.zoomByFactor(100)
            drawingView?.zoomByFactor(0.01)
            drawingView?.zoomToAbsoluteScale(scale)
            drawingView?.scrollPointToCenter(schematic.centeredPoint)
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
        if let matchButton = pageLayoutAccessory?.matchDrawingPageToLayout where matchButton.state == NSOnState {
            page.pageSize = printInfo.imageablePageBounds.size * (100.0 / 72.0)
        }
        if let dict = (printInfo.dictionary() as NSDictionary) as? [String: AnyObject] {
            schematic.printInfoDict = dict
            printInColor = (pageLayoutAccessory?.printInColor?.state ?? NSOffState) == NSOnState
            Defaults.setBool(printInColor, forKey: "printColor")
        }
    }
    
    override func preparePageLayout(pageLayout: NSPageLayout) -> Bool {
        if let pageLayoutAccessory = pageLayoutAccessory {
            pageLayoutAccessory.printInColor?.state = Defaults.boolForKey("printColor") ? NSOnState : NSOffState
            pageLayoutAccessory.matchDrawingPageToLayout?.state = NSOffState
            pageLayout.addAccessoryController(pageLayoutAccessory)
        }
        return true
    }
    
    enum PrinterError: ErrorType {
        case NoViewError
    }
    
    var printSaveZoomState = ZoomState(scale: 1, centerPoint: CGPoint())
    var printSavePageNumber = 0
    
    override func printOperationWithSettings(printSettings: [String : AnyObject]) throws -> NSPrintOperation {
        if let drawingView = drawingView {
            let operation = NSPrintOperation(view: drawingView, printInfo: printInfo)
            return operation
        } else {
            throw PrinterError.NoViewError
        }
    }
    
    func document(document: NSDocument, didPrintSuccessfully: Bool,  contextInfo: UnsafeMutablePointer<Void>) {
        currentPage = printSavePageNumber
        drawingView?.zoomState = printSaveZoomState
        drawingView?.constrainViewToSuperview = true
        drawingView?.needsDisplay = true
    }
    
    override func printDocument(sender: AnyObject?) {
        if let drawingView = drawingView {
            printSavePageNumber = currentPage
            drawingView.constrainViewToSuperview = false        // allow random zooming
            printSaveZoomState = drawingView.zoomState
            drawingView.zoomToAbsoluteScale((72.0 / 100.0) * printInfo.scalingFactor)
            printDocumentWithSettings([:], showPrintPanel: true, delegate: self, didPrintSelector: #selector(SchematicDocument.document(_:didPrintSuccessfully:contextInfo:)), contextInfo: nil)
        }
    }
    
    // MARK: Sanity Checks
    
    var components: Set<Component> {
        let allGraphics = pages.reduce([]) { $0 + $1.displayList }
        return Set(allGraphics.flatMap { $0 as? Component })
    }
    
    var unplacedComponents: Set<Component> {
        let allGraphics = pages.reduce([]) { $0 + $1.displayList }
        let placedComponents = Set(allGraphics.flatMap { $0 as? Component })
        let packages = Set(placedComponents.flatMap { $0.package })
        let allComponents = Set(packages.reduce([]) { $0 + $1.components })
        let unplacedComponents = allComponents.subtract(placedComponents)
        return unplacedComponents
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

    @IBAction func openKiCadLibrary(sender: AnyObject) {
        libraryManager?.openKiCadLibrary(self)
    }
    
    @IBAction func openLibrary(sender: AnyObject) {
        libraryManager?.openLibrary(self)
    }
    
    @IBAction func closeLibrary(sender: AnyObject) {
        libraryManager?.closeLibrary(self)
    }
    
    @IBAction func populatePartParameters(sender: AnyObject) {
        if let selection = drawingView?.selection, let component = selection.first as? Component where selection.count == 1 {
            octopartWindow?.orderFront(self)
            octopartWindow?.prepopulateWithComponent(component)
        }
    }
}

class SchematicPageLayoutController: NSViewController
{
    @IBOutlet var matchDrawingPageToLayout: NSButton?
    @IBOutlet var printInColor: NSButton?
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

