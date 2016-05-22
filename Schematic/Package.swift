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
    var components: [Component] = []
    
    override var inspectionName: String     { return "Package" }

    required init?(coder decoder: NSCoder) {
        components = decoder.decodeObjectForKey("components") as? [Component] ?? []
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(components, forKey: "components")
        super.encodeWithCoder(coder)
    }
}

