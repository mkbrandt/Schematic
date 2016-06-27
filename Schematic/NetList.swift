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

var _autoNameSequence = 10000
var autoNameSequence: Int    { let an = _autoNameSequence; _autoNameSequence += 1; return an }

class NetList: NSObject
{
    var nets: Set<Net> = []
    var name: String {
        if let name = nets.first?.name {
            return name
        }
        let autoName = nets.first?.attributes["autoNetName"] ?? "N\(autoNameSequence)"
        for net in nets {
            net.attributes["autoNetName"] = autoName
        }
        return autoName
    }
    
    var nodes: Set<Node>    { return Set(nets.reduce([]) { $0 + [$1.originNode, $1.endPointNode] }) }
    var pins: Set<Pin>      { return Set(nodes.flatMap { $0.pin }) }
}

extension SchematicDocument
{
    @IBAction func repackage(_ sender: AnyObject) {
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
    
    var packages: Set<Package>      { return Set(self.components.flatMap { $0.package }) }
    var netLists: Set<NetList> {
        var netLists: [NetList] = []
        let allGraphics = pages.reduce([]) { $0 + $1.displayList }
        var allNets = Set(allGraphics.flatMap { $0 as? Net })
        
        while let net = allNets.first {
            let netList = NetList()
            if let drawingView = drawingView {
                netList.nets = net.logicallyConnectedNets(drawingView)
            } else {
                netList.nets = net.physicallyConnectedNets([])
            }
            allNets.subtract(netList.nets)
            netLists.append(netList)
        }
        return Set(netLists)
    }
    
    func jsonNetList() -> JSON
    {
        var errors: [String] = []
        var warnings: [String] = []
        var netDict: [String: JSON] = [:]

        var packageArray: [JSON] = []
        
        for pkg in packages {
            var pjson: [String: JSON] = [:]
            let pins = pkg.components.reduce([]) { $0 + $1.pins }
            pjson["pins"] = JSON(pins.map { JSON(["pinName": $0.pinName, "pinNumber": $0.pinNumber]) })
            for (k, v) in pkg.attributes {
                pjson[k] = JSON(v)
            }
            for comp in pkg.components {
                for (k, v) in comp.attributes {
                    pjson[k] = JSON(v)
                }
            }
            packageArray.append(JSON(pjson))
        }

        for nlist in netLists {
            var pinNames: [String] = []

            for pin in nlist.pins {
                let refDes = pin.component?.refDes
                let pinNumber = pin.pinNumber
                if let refDes = refDes where pin.component?.package != nil {
                    if pinNumber == "" {
                        errors.append("unnamed pin on net \(nlist.name) component \(refDes)")
                    }
                    pinNames.append("\(refDes):\(pinNumber)")
                } else if refDes == nil {
                    errors.append("net \(nlist.name) attached to pin \(pinNumber) of unnamed component")
                }
            }
            
            if pinNames.count == 0 {
                warnings.append("No pins present on net \(nlist.name)")
            }
            
            let attributes: [String: String] = nlist.nets.reduce([:]) { attr, net in
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
            netDict[nlist.name] = JSON(netInfo)
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
            allNets.subtract(nets)
        }
        
        var netlist = "( { OrCAD/PCB II Netlist Format 2000 Time Stamp - }\n"
        let packages = Set(self.components.flatMap { $0.package })
        for pkg in packages {
            let id = pkg.graphicID
            let footprint = pkg.footprint ?? "NONE"
            let refDes = pkg.refDes ?? "NONE"
            let value = (pkg.components.first?.value ?? "value").replacingOccurrences(of: " ", with: "/")
            netlist += "\t( E\(id) \(footprint) \(refDes) \(value)\n"
            let pins = Set(pkg.components.reduce([]) { $0 + $1.pins }).sorted { $0.pinNumber < $1.pinNumber }
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
    
    @IBAction func runGenericNetlist(_ sender: AnyObject) {
        let netlisters = self.netlisters
        let savePanel = NSSavePanel()
        savePanel.accessoryView = netlistAccessory
        netlistChooser?.removeAllItems()
        let netlisterFileNames = netlisters.flatMap { $0.lastPathComponent }
        let netlisterExtensions = netlisterFileNames.map { $0.components(separatedBy: ".").last ?? "" }
        let netListerNames = netlisterFileNames.map { $0.components(separatedBy: ".").first ?? "--error--" }
        netlistChooser?.addItems(withTitles: netListerNames)
        netlistChooser?.block_setAction { (sender: AnyObject?) -> () in
            let sender = sender as! NSPopUpButton
            let index = sender.indexOfSelectedItem
            let ext = netlisterExtensions[index]
            savePanel.allowedFileTypes = [ext]
        }
        savePanel.allowedFileTypes = netlisterExtensions
        savePanel.allowsOtherFileTypes = true
        if savePanel.runModal() == NSFileHandlingPanelOKButton {
            let netlister = netlisters[netlistChooser?.indexOfSelectedItem ?? 0]
            if let url = savePanel.url {
                if let netlist = runNetlister(netlister) {
                    _ = try? netlist.write(to: url, atomically: true, encoding: String.Encoding.utf8)
                }
            }
        }
    }
    
    @IBAction func runNetlist(_ sender: AnyObject) {
        let netlist = jsonNetList()
        let errors = netlist["errors"].arrayValue
        let warnings = netlist["warnings"].arrayValue
        
        if errors.count > 0 || warnings.count > 0 {
            let alert = NSAlert()
            var infoText = ""
            alert.messageText = "Netlist complete, \(errors.count) errors, \(warnings.count) warnings"
            infoText += (errors.map { $0.stringValue }).joined(separator: "\n")
            infoText += (warnings.map { $0.stringValue }).joined(separator: "\n")
            alert.informativeText = infoText
            alert.runModal()
        }
        
        if errors.count == 0 {
            let savePanel = NSSavePanel()
            savePanel.allowedFileTypes = ["json"]
            savePanel.allowsOtherFileTypes = true
            if savePanel.runModal() == NSFileHandlingPanelOKButton {
                if let url = savePanel.url {
                    if let json = netlist.rawString() {
                        _ = try? json.write(to: url, atomically: true, encoding: String.Encoding.utf8)
                    }
                }
            }
        }
    }
    
    @IBAction func runOrcadNetlist(_ sender: AnyObject) {
        let netlist = orcadNetlist()
        
        let savePanel = NSSavePanel()
        savePanel.allowedFileTypes = ["net"]
        savePanel.allowsOtherFileTypes = true
        if savePanel.runModal() == NSFileHandlingPanelOKButton {
            if let url = savePanel.url {
                _ = try? netlist.write(to: url, atomically: true, encoding: String.Encoding.utf8)
            }
        }
    }
    
    var netlisters: [URL] {
        let fileManager = FileManager.default()
        let libURLs = fileManager.urlsForDirectory(.applicationScriptsDirectory, inDomains: .userDomainMask)
        
        var netlisters: [URL] = []
        for url in libURLs {
            do {
                let fileManager = FileManager.default()
                let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [URLResourceKey.isExecutableKey.rawValue], options: [])
                for item in contents {
                    var exec: AnyObject? = nil
                    try (item as NSURL).getResourceValue(&exec, forKey: URLResourceKey.isExecutableKey)
                    if let exec = exec as? NSNumber where exec.boolValue == true {
                        netlisters.append(item)
                    }
                }
            } catch (let err) {
                Swift.print("error: \(err)")
            }
        }
        return netlisters
    }
    
    func runNetlister(_ url: URL) -> String? {
        do {
            let script = try NSUserUnixTask(url: url)
            let inpipe = Pipe()
            let outpipe = Pipe()
            let json = jsonNetList()
            let jsonData = try json.rawData()
            script.standardInput = inpipe.fileHandleForReading
            script.standardOutput = outpipe.fileHandleForWriting
            script.execute(withArguments: nil, completionHandler: nil)
            inpipe.fileHandleForWriting.write(jsonData)
            script.standardInput?.closeFile()
            inpipe.fileHandleForWriting.closeFile()
            let netlist = outpipe.fileHandleForReading.readDataToEndOfFile()
            script.standardOutput?.closeFile()
            outpipe.fileHandleForReading.closeFile()
            return String(data: netlist, encoding: String.Encoding.utf8)
        } catch (let err) {
            Swift.print("error: \(err)")
        }
        return nil
    }
    
    class func installScripts() {
        let fileManager = FileManager.default()
        let scriptDirURLs = fileManager.urlsForDirectory(.applicationScriptsDirectory, inDomains: .userDomainMask)
        
        if let scriptDirURL = scriptDirURLs.first {
            if let contents = try?fileManager.contentsOfDirectory(at: scriptDirURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) where contents.count > 0 {
                return
            }
            do {
                let _ = try? fileManager.createDirectory(at: scriptDirURL, withIntermediateDirectories: true, attributes: nil)
                let panel = NSOpenPanel()
                panel.canCreateDirectories = true
                panel.directoryURL = scriptDirURL
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.title = "Allow access to Script Directory"
                panel.prompt = "Allow"
                panel.message = "I need to copy some things to the script directory to complete installation"
                if panel.runModal() != NSFileHandlingPanelOKButton {
                    return
                }
                if let bookmark = try (panel.url as NSURL?)?.bookmarkData(.withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil) {
                    if let srcURLs = Bundle.main().urlsForResources(withExtension: "netlister", subdirectory: nil) {
                        for srcURL in srcURLs {
                            if let baseName = srcURL.lastPathComponent?.replacingOccurrences(of: ".netlister", with: "") {
                                var stale: ObjCBool = false
                                let destURL = try (NSURL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &stale) as URL).appendingPathComponent(baseName)
                                try fileManager.copyItem(at: srcURL, to: destURL)
                            }
                        }
                    }
                }
            } catch(let err) {
                Swift.print("directory exists: \(err)")
            }
            
        }
    }
}
