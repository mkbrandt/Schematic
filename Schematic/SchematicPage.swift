//
//  SchematicPage.swift
//  Schematic
//
//  Created by Matt Brandt on 5/15/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa
import CloudKit

var pageSeq = 0

class SchematicPage: NSObject, NSCoding
{
    var name: String
    var pageSize: CGSize = CGSize(width: 100 * 17, height: 100 * 11)            // B Size by default
    var displayList: Set<Graphic> = []
    var record: CKRecord?
    var parentPage: SchematicPage? {
        willSet {
            if let parent = parentPage {
                parent.childPages = parent.childPages.filter { $0 != self }
            }
        }
        didSet {
            if let parent = parentPage {
                parent.childPages.append(self)
            }
        }
    }
    var childPages: [SchematicPage] = []
    
    var pageRect: CGRect    { return CGRect(origin: CGPoint(x: 0, y: 0), size: pageSize) }
    
    override init() {
        pageSeq += 1
        name = "New Page"
        super.init()
    }
    
    required init?(coder decoder: NSCoder) {
        name = decoder.decodeObject(of: NSString.self, forKey: "name") as String? ?? "unnamed"
        pageSize = decoder.decodeSize(forKey: "pageSize")
        parentPage = decoder.decodeObject(of: SchematicPage.self, forKey: "parentPage")
        if let displayList = decoder.decodeObject(of: NSSet.self, forKey: "displayList") as? Set<Graphic> {
            self.displayList = displayList
        }
        record = decoder.decodeObject(of: CKRecord.self, forKey: "record")
        super.init()
        if let parent = parentPage {
            parent.childPages.append(self)
        }
    }
    
    func encode(with encoder: NSCoder) {
        encoder.encode(name, forKey: "name")
        encoder.encode(displayList, forKey: "displayList")
        encoder.encode(pageSize, forKey: "pageSize")
        if let parent = parentPage {
            encoder.encode(parent, forKey: "parentPage")
            //print("page \(name) has parent \(parent.name)")
        }
        if let record = record {
            encoder.encode(record, forKey: "record")
        }
    }
    
    var components: Set<Component>      { return Set(displayList.flatMap { $0 as? Component }) }
    var freeComponents: Set<Component>  { return Set(components.filter { $0.package == nil }) }
    var packages: Set<Package>          { return Set(components.flatMap { $0.package }) }
}
