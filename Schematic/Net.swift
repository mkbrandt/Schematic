//
//  SCHNet.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

enum NetSegmentAttachment {
    case pin(pin: Pin)
    case segmentOrigin(segment: NetSegment)
    case onSegment(segment: NetSegment)
    
    var location: CGPoint {
        switch self {
        case pin(let p):
            return p.endPoint
        case segmentOrigin(let seg):
            return seg.origin
        case onSegment(let seg):
            return seg.origin
        }
    }
}

class NetSegment: AttributedGraphic
{
    var net: Net?
    var endPoint: CGPoint
    
    var netNameText: NetNameAttributeText? {
        let netNameTexts = attributeTexts.flatMap { $0 as? NetNameAttributeText }
        return netNameTexts.first
    }
    
    var netName: String? {
        return netNameText?.netName
    }
    
    init(origin: CGPoint, endPoint: CGPoint) {
        self.endPoint = endPoint
        super.init(origin: origin)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    required init?(coder decoder: NSCoder) {
        endPoint = decoder.decodePointForKey("endPoint")
        super.init(coder: decoder)
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodePoint(endPoint, forKey: "endPoint")
        super.encodeWithCoder(coder)
    }
}

class NetNameAttributeText: AttributeText
{
    var netName: String
    
    init(origin: CGPoint, netName: String, owner: NetSegment) {
        self.netName = netName
        super.init(origin: origin, format: "=netName", angle: 0, owner: owner)
    }
    
    required init?(coder decoder: NSCoder) {
        if let netName = decoder.decodeObjectForKey("netName") as? String {
            self.netName = netName
        } else {
            return nil
        }
        super.init(coder: decoder)
    }
    
    required init?(pasteboardPropertyList propertyList: AnyObject, ofType type: String) {
        fatalError("init(pasteboardPropertyList:ofType:) has not been implemented")
    }
    
    override func encodeWithCoder(coder: NSCoder) {
        coder.encodeObject(netName, forKey: "netName")
        super.encodeWithCoder(coder)
    }
}

class Net: AttributedGraphic
{
    var pins: [Pin] = []
    var segments: [NetSegment] = []
    var name: String?
    
    override var inspectionName: String     { return "Net" }
    
}