//
//  NetNameTool.swift
//  Schematic
//
//  Created by Matt Brandt on 6/1/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class NetNameTool: TextTool
{
    override func mouseDown(_ location: CGPoint, view: SchematicView) {
        clearEditing()
        let el = view.findElementAtPoint(location)
        let location = view.snapToGrid(location)
        if let attr = el as? AttributeText {
            currentAttribute = attr
        } else if let net = el as? Net {
            if let name = net.name {
                currentAttribute = NetNameAttributeText(origin: location, netName: name, owner: net)
            } else {
                currentAttribute = NetNameAttributeText(origin: location, netName: "UNNAMED", owner: net)
            }
        } else if let pin = el as? Pin {
            currentAttribute = NetNameAttributeText(origin: pin.origin, netName: "UNNAMED", owner: pin)
        }
    }
}
