//
//  SchematicPrefs.swift
//  Schematic
//
//  Created by Matt Brandt on 5/22/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let initialUserDefaults: [String: AnyObject] = [
    "pinNameColor": NSKeyedArchiver.archivedDataWithRootObject(NSColor.blueColor()),
    "pinNumberColor": NSKeyedArchiver.archivedDataWithRootObject(NSColor.redColor()),
    "pinColor": NSKeyedArchiver.archivedDataWithRootObject(NSColor.blackColor()),
    "graphicColor": NSKeyedArchiver.archivedDataWithRootObject(NSColor.blackColor()),
    "attributeColor": NSKeyedArchiver.archivedDataWithRootObject(NSColor.greenColor()),
    "wireColor": NSKeyedArchiver.archivedDataWithRootObject(NSColor.blackColor()),
]

let Defaults = NSUserDefaults.standardUserDefaults()

var pinNameColor: NSColor   { return Defaults.colorForKey("pinNameColor")      ?? NSColor.blueColor()  }
var pinNumberColor: NSColor { return Defaults.colorForKey("pinNumberColor")    ?? NSColor.redColor()   }
var pinColor: NSColor       { return Defaults.colorForKey("pinColor")          ?? NSColor.blackColor() }
var graphicsColor: NSColor  { return Defaults.colorForKey("graphicsColor")     ?? NSColor.blackColor() }
var attributeColor: NSColor { return Defaults.colorForKey("attributeColor")    ?? NSColor.greenColor() }
var wireColor: NSColor      { return Defaults.colorForKey("wireColor")         ?? NSColor.blackColor() }



class PrefToolBarButton: NSButton
{
    @IBOutlet var preferenceView: NSView?
    
}

class SchematicPreferenceWindow: NSWindow
{
    
    @IBAction func setPrefViewFrom(sender: PrefToolBarButton) {
        if let view = sender.preferenceView {
            if let subviews = contentView?.subviews {
                subviews.forEach({ $0.removeFromSuperview() })
            }
            self.setContentSize(view.frame.size)
            self.contentView?.addSubview(view)
        }
    }
}

extension NSUserDefaults
{
    func colorForKey(key: String) -> NSColor? {
        var color: NSColor?
        if let colorData = dataForKey(key) {
            color = NSKeyedUnarchiver.unarchiveObjectWithData(colorData) as? NSColor
        }
        return color
    }
    
    func setColor(color: NSColor?, forKey key: String) {
        var colorData: NSData?
        if let color = color {
            colorData = NSKeyedArchiver.archivedDataWithRootObject(color)
        }
        setObject(colorData, forKey: key)
    }
}