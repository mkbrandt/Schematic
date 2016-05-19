//
//  SCHPackage.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Foundation

class SCHPackage: SCHElement
{
    var components: [SCHComponent] = []
    
    required init?(coder decoder: NSCoder) {
        components = decoder.decodeObjectForKey("components") as? [SCHComponent] ?? []
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

