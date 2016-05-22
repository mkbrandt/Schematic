//
//  SchematicPage.swift
//  Schematic
//
//  Created by Matt Brandt on 5/15/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

var pageSeq = 0

class SchematicPage: NSObject, NSCoding
{
    var name: String
    var pageSize: CGSize = CGSize(width: 100 * 17, height: 100 * 11)            // B Size by default
    var displayList: [Graphic] = []
    
    var pageRect: CGRect    { return CGRect(origin: CGPoint(x: 0, y: 0), size: pageSize) }
    
    override init() {
        pageSeq += 1
        name = "Page_\(pageSeq)"
    }
    
    required init?(coder decoder: NSCoder) {
        name = decoder.decodeObjectForKey("name") as? String ?? "unnamed"
        pageSize = decoder.decodeSizeForKey("pageSize")
        displayList = decoder.decodeObjectForKey("displayList") as? [Graphic] ?? []
    }
    
    func encodeWithCoder(encoder: NSCoder) {
        encoder.encodeObject(name, forKey: "name")
        encoder.encodeObject(displayList, forKey: "displayList")
        encoder.encodeSize(pageSize, forKey: "pageSize")
    }
}
