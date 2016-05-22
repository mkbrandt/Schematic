//
//  AttributedGraphic.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class AttributedGraphic: Graphic
{
    var attributes: [AttributeText] = []
    
    override var elements: [Graphic]     { return attributes }
    
    override var bounds: CGRect {
        return attributes.reduce(super.bounds, combine: { $0 + $1.bounds })
    }
    
    override init(origin: CGPoint) {
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        attributes = decoder.decodeObjectForKey("attributes") as? [AttributeText] ?? []
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(attributes, forKey: "attributes")
        super.encodeWithCoder(coder)
    }

    override var inspectionName: String     { return "AttributedGraphic" }

    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        return nil
    }
    
    func attributeValue(name: String) -> String {
        return name
    }
    
// MARK: Drawing
    
    override func draw() {
        for attr in attributes {
            attr.draw();
        }
    }

}

