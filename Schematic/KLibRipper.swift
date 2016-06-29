//
//  KLibRipper.swift
//  Schematic
//
//  Created by Matt Brandt on 5/25/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

func runRipper(_ document: SchematicDocument) {
    
    let openPanel = NSOpenPanel()
    openPanel.runModal()
    let urls = openPanel.urls
    openPanel.orderOut(document)
    for url in urls {
        let ripper = KLibRipper()
        let text = String(contentsOfURL: url, encoding: String.Encoding.utf8)
        ripper.ripString(text, document: document)
    }
}

extension CGFloat {
    init?(_ s: String) {
        if let d = Double(s) {
            self = CGFloat(d)
        } else {
            return nil
        }
    }
}

class KLibRipper: NSObject
{
    var document: SchematicDocument?
    var origin = CGPoint(x: 100, y: 100)
    var comp: Component?
    var pkg: Package?
    var value: String = ""
    var prefix: String = ""
    var drawPinNumber = true
    var drawPinName = true
    var footprint: String?
    var group: GroupGraphic?
    
    func scaledNumber(_ s: String) -> CGFloat {
        if let n = Double(s) {
            return CGFloat(n / 10)
        }
        return 0
    }
    
    func processComponent(_ lines: [String]) {
        footprint = nil
        for line in lines {
            let fields = line.components(separatedBy: CharacterSet.whitespaces) // should account for quotes
            switch fields[0] {
            case "DEF":
                value = fields[1]
                prefix = fields[2]
                drawPinNumber = fields[5] == "Y"
                drawPinName = fields[6] == "Y"
                //let units = Int(fields[7]) ?? 0
                //let homogeneous = fields[8] == "F"
                group = GroupGraphic(contents: [])
                comp = Component(origin: CGPoint(), pins: [], outline: group!)
                comp?.value = value
                pkg = Package(components: [comp!])
            case "F0":
                let x = scaledNumber(fields[2])
                let y = scaledNumber(fields[3])
                let refText = AttributeText(origin: CGPoint(x: x, y: y), format: "=refDes", angle: 0, owner: comp)
                comp?.attributeTexts.insert(refText)
            case "F1":
                let x = scaledNumber(fields[2])
                let y = scaledNumber(fields[3])
                let valueText = AttributeText(origin: CGPoint(x: x, y: y), format: "=value", angle: 0, owner: comp)
                comp?.attributeTexts.insert(valueText)
            case "F2":
                let x = scaledNumber(fields[2])
                let y = scaledNumber(fields[3])
                footprint = fields[1]
                let fpText = AttributeText(origin: CGPoint(x: x, y: y), format: "=footprint", angle: 0, owner: comp)
                comp?.attributeTexts.insert(fpText)
            case "S":
                let x = scaledNumber(fields[1])
                let y = scaledNumber(fields[2])
                let x2 = scaledNumber(fields[3])
                let y2 = scaledNumber(fields[4])
                let g = RectGraphic(rect: rectContainingPoints([CGPoint(x: x, y: y), CGPoint(x: x2, y: y2)]))
                group?.contents.insert(g)
            case "P":
                let n = Int(fields[1]) ?? 0
                var pts: [CGPoint] = []
                for i in 0 ..< n {
                    let x = scaledNumber(fields[i * 2 + 5])
                    let y = scaledNumber(fields[i * 2 + 6])
                    pts.append(CGPoint(x: x, y: y))
                }
                let filled = fields[n * 2 + 5] != "N"
                let poly = PolygonGraphic(vertices: pts, filled: filled)
                group?.contents.insert(poly)
            case "C":
                let x = scaledNumber(fields[1])
                let y = scaledNumber(fields[2])
                let r = scaledNumber(fields[3])
                let g = CircleGraphic(origin: CGPoint(x: x, y: y), radius: r)
                group?.contents.insert(g)
            case "A":
                let x = scaledNumber(fields[1])
                let y = scaledNumber(fields[2])
                let r = scaledNumber(fields[3])
                let sa = scaledNumber(fields[4]) * PI / 180
                let ea = scaledNumber(fields[5]) * PI / 180
                let g = ArcGraphic(origin: CGPoint(x: x, y: y), radius: r, startAngle: sa, endAngle: ea, clockwise: true)
                if g.sweep > PI {
                    g.clockwise = false
                }
                group?.contents.insert(g)
            case "T":
                let angle = fields[1] == "0" ? 0 : PI
                let x = scaledNumber(fields[2])
                let y = scaledNumber(fields[3])
                let t = fields[7 ..< fields.count].joined(separator: " ")
                let attr = AttributeText(origin: CGPoint(x: x, y: y), format: t, angle: angle, owner: comp)
                comp?.attributeTexts.insert(attr)
            case "X":
                let pinName = fields[1] == "~" ? "" : fields[1]
                let pinNumber = fields[2] == "~" ? "" : fields[2]
                var x = scaledNumber(fields[3])
                var y = scaledNumber(fields[4])
                let length = scaledNumber(fields[5])
                var orientation: PinOrientation = .right
                switch fields[6] {
                case "R":
                    orientation = .left
                    x += length
                case "L":
                    orientation = .right
                    x -= length
                case "D":
                    orientation = .top
                    y -= length
                case "U":
                    orientation = .bottom
                    y += length
                default: break
                }
                let pin = Pin(origin: CGPoint(x: x, y: y), component: comp, name: pinName, number: pinNumber, orientation: orientation)
                comp?.pins.insert(pin)
            default:
                break
            }
        }
        if let comp = comp, let page = document?.page {
            let pkg = Package(components: [comp])
            pkg.footprint = footprint
            pkg.prefix = prefix
            if let document = document {
                pkg.assignReference(document)
            }
            comp.origin = origin
            origin.x += 100
            if origin.x > 1500 {
                origin.y += 100
                origin.x = 100
            }
            page.displayList.insert(comp)
        }
    }
    
    func ripString(_ text: String, document: SchematicDocument) {
        self.document = document
        let lines = text.components(separatedBy: CharacterSet.newlines)
        
        var ripLines: [String] = []
        for line in lines {
            if line.hasPrefix("DEF ") {
                ripLines = [line]
            } else if line.hasPrefix("ENDDEF") {
                processComponent(ripLines)
            } else {
                ripLines.append(line)
            }
        }
    }
}
