//
//  Package.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Foundation

class Package: AttributedGraphic
{
    var prefix: String = "U"
    var refDes: String?
    var footprint: String?
    var partNumber: String?
    
    var components: Set<Component> = [] {
        willSet {
            components.forEach({ $0.package = nil })
        }
        didSet {
            components.forEach({ $0.package = self })
        }
    }
    
    var sortName: String { return partNumber ?? components.first?.name ?? "unnamed" }
    
    override var inspectionName: String     { return "Package" }
    override var inspectables: [Inspectable] {
        return [
            Inspectable(name: "prefix", type: .String, displayName: "Ref Prefix"),
            Inspectable(name: "refDes", type: .String, displayName: "RefDes"),
            Inspectable(name: "partNumber", type: .String, displayName: "Part Number"),
            Inspectable(name: "footprint", type: .String, displayName: "Footprint")
        ]
    }
    
    override var attributeNames: [String] {
        return super.attributeKeys + ["prefix", "refDes", "partNumber", "footprint"]
    }
    
    init(components: Set<Component>) {
        self.components = components
        super.init(origin: CGPoint())
        components.forEach { $0.package = self }
    }

    required init?(coder decoder: NSCoder) {
        components = decoder.decodeObjectForKey("components") as? Set<Component> ?? []
        prefix = decoder.decodeObjectForKey("prefix") as? String ?? "U"
        refDes = decoder.decodeObjectForKey("refDes") as? String
        footprint = decoder.decodeObjectForKey("footprint") as? String
        partNumber = decoder.decodeObjectForKey("partNumber") as? String
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(components, forKey: "components")
        coder.encodeObject(refDes, forKey: "refDes")
        coder.encodeObject(prefix, forKey: "prefix")
        coder.encodeObject(footprint, forKey: "footprint")
        coder.encodeObject(partNumber, forKey: "partNumber")
        super.encodeWithCoder(coder)
    }
    
    func assignReference(document: SchematicDocumentState) {
        let allGraphics = document.pages.reduce([]) { $0 + $1.displayList }
        let components = allGraphics.filter { $0 is Component } as! [Component]
        let designators = Set(components.flatMap { $0.refDes })
        var index = 0
        var des = ""
        repeat {
            index = index + 1
            des = prefix + "\(index)"
        } while designators.contains(des)
        refDes = des
    }
}

