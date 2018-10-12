//
//  Package.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import AppKit

class Package: AttributedGraphic
{
    override class var supportsSecureCoding: Bool { return true }
    
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
    
    var netpins: String? {
        get { return attributes["netpins"] }
        set { attributes["netpins"] = newValue }
    }
    
    var primaryComponent: Component?
    
    var components: Set<Component> = [] {
        willSet {
            components.forEach({ $0.package = nil })
        }
        didSet {
            components.forEach({ $0.package = self })
            primaryComponent = components.first
        }
    }
    
    var pins: [Pin] {
        var pins: [Pin] = []
        
        for comp in components {
            pins = pins + comp.pins
        }
        
        if let np = netpins {
            let pindefs = np.components(separatedBy: ",")
            for pdef in pindefs {
                let pd = pdef.components(separatedBy: "=")
                if pd.count == 2 {
                    let netName = pd[0].trimmingCharacters(in: .whitespaces)
                    let pinNumber = pd[1].trimmingCharacters(in: .whitespaces)
                    let phantomPin = Pin(origin: CGPoint(), component: nil, name: netName, number: pinNumber, orientation: .right)
                    phantomPin._implicitNetName = netName
                    pins.append(phantomPin)
                }
            }
        }
        return pins
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
        self.primaryComponent = components.first
        super.init(origin: CGPoint())
        components.forEach { $0.package = self }
        self.netpins = ""
    }

    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        components = decoder.decodeObject(of: [NSSet.self, Component.self], forKey: "components") as? Set<Component> ?? []
        primaryComponent = decoder.decodeObject(of: Component.self, forKey: "primaryComponent") ?? components.first
    }
    
    override init(json: JSON) {
        components = Set(json["components"].arrayValue.map { Component(json: $0) })
        super.init(json: json)
        components.forEach { $0.package = self }
    }
    
    required init?(pasteboardPropertyList propertyList: Any, ofType type: NSPasteboard.PasteboardType) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encode(with coder: NSCoder) {
        coder.encode(components, forKey: "components")
        super.encode(with: coder)
    }
    
    func assignReference(_ document: SchematicDocument) {
        let allGraphics = document.pages.reduce([]) { $0 + $1.displayList }
        let components = allGraphics.filter { $0 is Component } as! [Component]
        let designators = Set(components.map { $0.refDes })
        var index = 0
        var des = ""
        repeat {
            index = index + 1
            des = prefix + "\(index)"
        } while designators.contains(des)
        refDes = des
    }
}

