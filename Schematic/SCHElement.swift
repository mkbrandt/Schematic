//
//  SCHElement.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class SCHElement: SCHGraphic
{
    var attributes: [String: SCHAttribute] = [:]
    
    override var bounds: CGRect {
        return attributes.reduce(super.bounds, combine: { $0 + $1.1.bounds })
    }
    
    override var inspectables: [Inspectable] {
        get { return attributes.map { (key, value) in return Inspectable(name: key, type: .Attribute) }}
        set {}
    }
    
    override init(origin: CGPoint) {
        super.init(origin: origin)
    }
    
    required init?(coder decoder: NSCoder) {
        attributes = decoder.decodeObjectForKey("attributes") as? Dictionary ?? [:]
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(attributes, forKey: "attributes")
        super.encodeWithCoder(coder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        return nil
    }
    
// MARK: Selection
    
    override func elementAtPoint(point: CGPoint) -> SCHGraphic? {
        if bounds.contains(point) {
            let relativePoint = point - origin
            for (_, attr) in attributes {
                if let el = attr.elementAtPoint(relativePoint) {
                    return el
                }
            }
            return self
        }
        return nil
    }
    
    
// MARK: Drawing
    
    override func draw() {
        attributes.forEach { _, attr in
            attr.draw();
        }
    }

}

