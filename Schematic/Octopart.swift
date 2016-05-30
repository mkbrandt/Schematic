//
//  Octopart.swift
//  Schematic
//
//  Created by Matt Brandt on 5/27/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

let API_KEY = "997c8394"

class OctopartInfo: NSObject
{
    var partDescription: String = ""
    var partNumber: String = ""
    var manufacturer: String = ""
    var value: String?
    var specs: [String: String] = [:]
    var datasheetURL: String?
    
    override var description: String { return partDescription }
}

class OctoPartWindow: NSWindow, NSTableViewDataSource
{
    @IBOutlet var drawingView: SchematicView!
    @IBOutlet var partTable: NSTableView!
    @IBOutlet var partType: NSComboBox!
    @IBOutlet var footprint: NSComboBox!
    @IBOutlet var keywords: NSTextField!
    @IBOutlet var startField: NSTextField!
    @IBOutlet var limitField: NSTextField!
    
    var searchQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)
    
    var partInfo: [OctopartInfo] = []
    
    var component: Component?
    
    func searchPart(query: String, start: Int = 0, limit: Int = 20) -> [OctopartInfo] {
        var infos: [OctopartInfo] = []
        if let  q = query.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLPathAllowedCharacterSet()),
            let url = NSURL(string: "https://octopart.com/api/v3/parts/search?apikey=\(API_KEY)&q=\(q)&start=\(start)&limit=\(limit)&pretty_print=true&include[]=specs&include[]=datasheets&include[]=descriptions")
         {
            if let response = try? NSString(contentsOfURL: url, encoding: NSUTF8StringEncoding) {
                let json = JSON.parse(response as String)
                //let hits = json["hits"].intValue
                //Swift.print("\(hits) hits")
                for result in json["results"].arrayValue {
                    let info = OctopartInfo()
                    let part = result["item"]
                    info.partNumber = part["mpn"].stringValue
                    info.manufacturer = part["brand"]["name"].stringValue
                    let specs = part["specs"]
                    info.partDescription = part["descriptions", 0, "value"].stringValue
                    info.datasheetURL = part["datasheets", 0, "url"].stringValue
                    for (k, v) in specs {
                        let dv = v["display_value"].stringValue
                        if k.containsString("tolerance") {
                            info.specs["tolerance"] = dv
                        } else if k.containsString("package") {
                            info.specs["package"] = dv
                        } else if k == "resistance" || k == "capacitance" || k == "inductance" {
                            info.value = dv
                        } else {
                            info.specs[k] = dv
                        }
                    }
                    infos.append(info)
                }
            }
        }
        return infos
    }
    
    func runQuery() {
        let query = "\(partType.stringValue) \(footprint.stringValue) \(keywords.stringValue)"
        let limit = Int(limitField.stringValue) ?? 20
        let start = Int(startField.stringValue) ?? 0
        partInfo = searchPart(query, start: start, limit: limit)
        dispatch_async(dispatch_get_main_queue()) { 
            self.partTable.reloadData()
        }
    }
    
    func prepopulateWithComponent(component: Component) {
        partType.stringValue = component.partNumber
        footprint.stringValue = component.package?.footprint ?? "SMT"
        keywords.stringValue = ""
        self.component = component
    }
    
    @IBAction func search(sender: AnyObject) {
        dispatch_async(searchQueue) {
            self.runQuery()
        }
    }
    
    @IBAction func cancel(sender: AnyObject) {
        self.component = nil
        self.orderOut(self)
    }
    
    @IBAction func populateComponent(sender: AnyObject) {
        let row = partTable.selectedRow
        if row < 0 {
            return
        }
        let info = partInfo[row]
        var specs = info.specs
        if let component = component {
            component.package?.manufacturer = info.manufacturer
            component.package?.partNumber = info.partNumber
            component.value = info.value ?? info.description
            specs["description"] = info.description
            if let footprint = specs["package"] {
                component.package?.footprint = footprint
            } else {
                component.package?.footprint = "?"
            }
            for (k, v) in specs {
                component.package?.setAttribute(v, name: k)
            }
        }
        drawingView.needsDisplay = true
        orderOut(self)
    }
    
    // Data Source
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        return partInfo.count
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        let info = partInfo[row]
        
        if let tableColumn = tableColumn {
            switch tableColumn.title {
            case "Manufacturer": return info.manufacturer
            case "Part Number": return info.partNumber
            case "Description": return info.description
            case "Package": return info.specs["package"]
            case "Power": return info.specs["power_rating"]
            case "Value": return info.value
            case "Tolerance": return info.specs["tolerance"]
            case "Datasheet":   return info.datasheetURL
            default: return "---"
            }
        }
        return "???"
    }
}
