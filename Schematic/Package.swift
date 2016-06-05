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
    var prefix: String {
        get { return attributes["prefix"] ?? "U" }
        set { attributes["prefix"] = newValue }
    }
    
    var refDes: String?  {
        get { return attributes["refDes"] }
        set { attributes["refDes"] = newValue }
    }

    var footprint: String?  {
        get { return attributes["footprint"] }
        set { attributes["footprint"] = newValue }
    }

    var partNumber: String?  {
        get { return attributes["partNumber"] }
        set { attributes["partNumber"] = newValue }
    }
    
    var manufacturer: String? {
        get { return attributes["manufacturer"] }
        set { attributes["manufacturer"] = newValue }
    }
    
    var components: Set<Component> = [] {
        willSet {
            components.forEach({ $0.package = nil })
        }
        didSet {
            components.forEach({ $0.package = self })
        }
    }
    
    override var json: JSON {
        var json = super.json
        json["__class__"] = "Package"
        json["components"] = JSON(components.map { $0.json })
        return json
    }
    
    var sortName: String { return partNumber ?? components.first?.value ?? "unnamed" }
    
    override var inspectionName: String     { return "Package" }
    
    init(components: Set<Component>) {
        self.components = components
        super.init(origin: CGPoint())
        components.forEach { $0.package = self }
    }

    required init?(coder decoder: NSCoder) {
        components = decoder.decodeObjectForKey("components") as? Set<Component> ?? []
        super.init(coder: decoder)
    }
    
    override init(json: JSON) {
        components = Set(json["components"].arrayValue.map { Component(json: $0) })
        super.init(json: json)
        components.forEach { $0.package = self }
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(components, forKey: "components")
        super.encodeWithCoder(coder)
    }
    
    func assignReference(document: SchematicDocument) {
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

