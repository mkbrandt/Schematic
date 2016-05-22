//
//  AppDelegate.swift
//  Schematic
//
//  Created by Matt Brandt on 5/13/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let initialUserDefaults: [String: AnyObject] = [
    "pinNameColor": NSColor.blueColor(),
    "pinNumberColor": NSColor.redColor(),
    "pinColor": NSColor.blackColor(),
    "graphicColor": NSColor.blackColor(),
    "attributeColor": NSColor.greenColor(),
    "wireColor": NSColor.blackColor(),
]

let Defaults = NSUserDefaults.standardUserDefaults()

var pinNameColor: NSColor   { return Defaults.objectForKey("pinNameColor")      as? NSColor ?? NSColor.blueColor()  }
var pinNumberColor: NSColor { return Defaults.objectForKey("pinNumberColor")    as? NSColor ?? NSColor.redColor()   }
var pinColor: NSColor       { return Defaults.objectForKey("pinColor")          as? NSColor ?? NSColor.blackColor() }
var graphicsColor: NSColor  { return Defaults.objectForKey("graphicsColor")     as? NSColor ?? NSColor.blackColor() }
var attributeColor: NSColor { return Defaults.objectForKey("attributeColor")    as? NSColor ?? NSColor.greenColor() }
var wireColor: NSColor      { return Defaults.objectForKey("wireColor")         as? NSColor ?? NSColor.blackColor() }

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate
{
    func applicationDidFinishLaunching(aNotification: NSNotification) {
        Defaults.registerDefaults(initialUserDefaults)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

}

