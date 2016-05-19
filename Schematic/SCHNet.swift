//
//  SCHNet.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class SCHNetSegment: NSObject, NSCoding
{
    var origin: CGPoint
    var endPoint: CGPoint
    
    init(origin: CGPoint) {
        self.origin = origin
        self.endPoint = origin
        super.init()
    }
    
    required init?(coder decoder: NSCoder) {
        origin = decoder.decodePointForKey("origin")
        endPoint = decoder.decodePointForKey("endPoint")
        super.init()
    }
    
    func encodeWithCoder(encoder: NSCoder) {
        encoder.encodePoint(origin, forKey: "origin")
        encoder.encodePoint(endPoint, forKey: "endPoint")
    }
    
    func draw() {
        NSColor.blackColor().set()
        NSBezierPath.setDefaultLineWidth(1.0)
        NSBezierPath.strokeLineFromPoint(origin, toPoint: endPoint)
    }
}

class SCHNet: SCHElement
{
    var pins: [SCHPin] = []
    var segments: [SCHNetSegment] = []
    
    var nameAttribute: SCHAttribute {
        get { return attributes["name"] ?? SCHAttribute(string: "unnamed") }
        set { attributes["name"] = newValue }
    }
    
    var name: String {
        get { return nameAttribute.string as String }
        set { nameAttribute.string = newValue }
    }
}