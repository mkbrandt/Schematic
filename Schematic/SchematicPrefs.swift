//
//  SchematicPrefs.swift
//  Schematic
//
//  Created by Matt Brandt on 5/22/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let initialUserDefaults: [String: AnyObject] = [
    "pinNameColor": NSKeyedArchiver.archivedData(withRootObject: NSColor.blue()),
    "pinNumberColor": NSKeyedArchiver.archivedData(withRootObject: NSColor.red()),
    "pinColor": NSKeyedArchiver.archivedData(withRootObject: NSColor.black()),
    "graphicColor": NSKeyedArchiver.archivedData(withRootObject: NSColor.black()),
    "attributeColor": NSKeyedArchiver.archivedData(withRootObject: NSColor.green()),
    "wireColor": NSKeyedArchiver.archivedData(withRootObject: NSColor.black()),
]

let Defaults = UserDefaults.standard()

var pinNameColor: NSColor   { return Defaults.colorForKey("pinNameColor")      ?? NSColor.blue()  }
var pinNumberColor: NSColor { return Defaults.colorForKey("pinNumberColor")    ?? NSColor.red()   }
var pinColor: NSColor       { return Defaults.colorForKey("pinColor")          ?? NSColor.black() }
var graphicsColor: NSColor  { return Defaults.colorForKey("graphicsColor")     ?? NSColor.black() }
var attributeColor: NSColor { return Defaults.colorForKey("attributeColor")    ?? NSColor.green() }
var wireColor: NSColor      { return Defaults.colorForKey("wireColor")         ?? NSColor.black() }



class PrefToolBarButton: NSButton
{
    @IBOutlet var preferenceView: NSView?
    
}

class SchematicPreferenceWindow: NSWindow
{
    
    @IBAction func setPrefViewFrom(_ sender: PrefToolBarButton) {
        if let view = sender.preferenceView {
            if let subviews = contentView?.subviews {
                subviews.forEach({ $0.removeFromSuperview() })
            }
            self.setContentSize(view.frame.size)
            self.contentView?.addSubview(view)
        }
    }
}

extension UserDefaults
{
    func colorForKey(_ key: String) -> NSColor? {
        var color: NSColor?
        if let colorData = data(forKey: key) {
            color = NSKeyedUnarchiver.unarchiveObject(with: colorData) as? NSColor
        }
        return color
    }
    
    func setColor(_ color: NSColor?, forKey key: String) {
        var colorData: Data?
        if let color = color {
            colorData = NSKeyedArchiver.archivedData(withRootObject: color)
        }
        set(colorData, forKey: key)
    }
}
