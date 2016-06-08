//
//  NetList.swift
//  Schematic
//
//  Created by Matt Brandt on 6/5/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

struct NetInfo {
    var pinNames: [String]
    var attributes: [String: String]
}

extension SchematicDocument
{
    @IBAction func repackage(sender: AnyObject) {
        var prefixes: [String: Int] = [:]
        let packages = Set(self.components.flatMap { $0.package })

        for pkg in packages {
            let prefix: String = pkg.prefix
            var pseq: Int
            if let seq = prefixes[prefix] {
                pseq = seq + 1
            } else {
                pseq = 1
            }
            prefixes[prefix] = pseq
            pkg.refDes = "\(prefix)\(pseq)"
        }
        drawingView?.needsDisplay = true
    }
    
    func jsonNetList() -> JSON
    {
        var errors: [String] = []
        var warnings: [String] = []
        var netDict: [String: JSON] = [:]
        var autoRef = 10000
        let packages = Set(self.components.flatMap { $0.package })
        var packageArray: [JSON] = []
        
        for pkg in packages {
            var pjson: [String: JSON] = [:]
            let pins = pkg.components.reduce([]) { $0 + $1.pins }
            pjson["pins"] = JSON(pins.map { JSON(["pinName": $0.pinName, "pinNumber": $0.pinNumber]) })
            for (k, v) in pkg.attributes {
                pjson[k] = JSON(v)
            }
            packageArray.append(JSON(pjson))
        }
        
        let allGraphics = pages.reduce([]) { $0 + $1.displayList }
        var allNets = Set(allGraphics.flatMap { $0 as? Net })
        
        while let segment = allNets.first {
            var nets: Set<Net>
            var netName: String
            if let name = segment.name {
                nets = Set(allNets.filter { $0.name == name })
                netName = name
            } else {
                nets = segment.physicallyConnectedNets([])
                netName = "NET_\(autoRef)"
                autoRef += 1
                nets.forEach { $0.attributes["autoNetName"] = netName }
            }
            allNets.subtractInPlace(nets)
            let nodes = nets.reduce([]) { $0 + [$1.originNode, $1.endPointNode] }
            let pins = Set(nodes).flatMap { $0.pin }
            var pinNames: [String] = []
            for pin in pins {
                let refDes = pin.component?.refDes
                let pinNumber = pin.pinNumber
                if let refDes = refDes where pin.component?.package != nil {
                    if pinNumber == "" {
                        errors.append("unnamed pin on net \(netName) component \(refDes)")
                    }
                    pinNames.append("\(refDes):\(pinNumber)")
                } else if refDes == nil {
                    errors.append("net \(netName) attached to pin \(pinNumber) of unnamed component")
                }
            }
            if pinNames.count == 0 {
                warnings.append("No pins present on net \(netName)")
            }
            let attributes: [String: String] = nets.reduce([:]) { attr, net in
                var attr = attr
                for (k, v) in net.attributes {
                    attr[k] = v
                }
                return attr
            }
            var netInfo = ["connections": JSON(pinNames)]
            if attributes.count > 0 {
                netInfo["attributes"] = JSON(attributes)
            }
            netDict[netName] = JSON(netInfo)
        }
        
        var netlist: [String: JSON] = ["packages": JSON(packageArray), "nets": JSON(netDict)]
        netlist["errors"] = JSON(errors)
        netlist["warnings"] = JSON(warnings)
        
        return JSON(netlist)
    }
    
    func orcadNetlist() -> String {
        var autoRef = 1
        let allGraphics = pages.reduce([]) { $0 + $1.displayList }
        var allNets = Set(allGraphics.flatMap { $0 as? Net })
        
        while let segment = allNets.first {
            var nets: Set<Net>
            var netName: String
            if let name = segment.name {
                nets = Set(allNets.filter { $0.name == name })
                netName = name
            } else {
                nets = segment.physicallyConnectedNets([])
                netName = "N\(autoRef)"
                autoRef += 1
                nets.forEach { $0.attributes["autoNetName"] = netName }
            }
            allNets.subtractInPlace(nets)
        }
        
        var netlist = "( { OrCAD/PCB II Netlist Format 2000 Time Stamp - }\n"
        let packages = Set(self.components.flatMap { $0.package })
        for pkg in packages {
            let id = pkg.graphicID
            let footprint = pkg.footprint ?? "NONE"
            let refDes = pkg.refDes ?? "NONE"
            let value = (pkg.components.first?.value ?? "value").stringByReplacingOccurrencesOfString(" ", withString: "/")
            netlist += "\t( E\(id) \(footprint) \(refDes) \(value)\n"
            let pins = pkg.components.reduce([]) { $0 + $1.pins }.sort { $0.pinNumber < $1.pinNumber }
            for pin in pins {
                if let net = pin.node?.attachments.first {
                    let netName = net.name ?? net.attributes["autoNetName"] ?? "BAD"
                    netlist += "\t\t( \(pin.pinNumber) \(netName) )\n"
                }
            }
            netlist += "\t)\n"
        }
        netlist += ")\n"
        
        return netlist
    }
    
    @IBAction func runNetlist(sender: AnyObject) {
        let netlist = jsonNetList()
        let errors = netlist["errors"].arrayValue
        let warnings = netlist["warnings"].arrayValue
        
        if errors.count > 0 || warnings.count > 0 {
            let alert = NSAlert()
            var infoText = ""
            alert.messageText = "Netlist complete, \(errors.count) errors, \(warnings.count) warnings"
            infoText += (errors.map { $0.stringValue }).joinWithSeparator("\n")
            infoText += (warnings.map { $0.stringValue }).joinWithSeparator("\n")
            alert.informativeText = infoText
            alert.runModal()
        }
        
        if errors.count == 0 {
            let savePanel = NSSavePanel()
            savePanel.allowedFileTypes = ["json"]
            savePanel.allowsOtherFileTypes = true
            if savePanel.runModal() == NSFileHandlingPanelOKButton {
                if let url = savePanel.URL {
                    if let json = netlist.rawString() {
                        _ = try? json.writeToURL(url, atomically: true, encoding: NSUTF8StringEncoding)
                    }
                }
            }
        }
    }
    
    @IBAction func runOrcadNetlist(sender: AnyObject) {
        let netlist = orcadNetlist()
        
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["net"]
        savePanel.allowsOtherFileTypes = true
        if savePanel.runModal() == NSFileHandlingPanelOKButton {
            if let url = savePanel.URL {
                _ = try? netlist.writeToURL(url, atomically: true, encoding: NSUTF8StringEncoding)
            }
        }
    }    
}
