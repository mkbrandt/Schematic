//
//  GraphicInspector.swift
//  Schematic
//
//  Created by Matt Brandt on 5/19/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class GraphicInspector: NSView, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate
{
    @IBOutlet var drawingView: SchematicView! {
        didSet {
            drawingView.addObserver(self, forKeyPath: "selection", options: .new, context: nil)
        }
    }
    
    @IBOutlet var tableViewContainer: NSScrollView!
    @IBOutlet var tableView: NSTableView!
    
    var fieldConstraints: [NSLayoutConstraint] = []
    var inspectionFields: [NSControl] = []
    var fieldBindings: [(NSControl, String)] = []
    
    var inspectee: Graphic? {
        willSet {
            removeConstraints(fieldConstraints)
            fieldConstraints = []
            for f in inspectionFields {
                f.removeFromSuperview()
            }
            inspectionFields = []
            for (f, s) in fieldBindings {
                f.unbind(s)
            }
            fieldBindings = []
        }
        didSet {
            createInspectionFields()
            tableView.reloadData()
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: AnyObject?, change: [NSKeyValueChangeKey : AnyObject]?, context: UnsafeMutablePointer<Void>?) {
        if drawingView.selection.count == 1 {
            inspectee = drawingView.selection.first
        } else {
            inspectee = nil
        }
    }
    
    @IBAction func switchValueChanged(_ sender: NSButton) {
        if let info = sender.infoForBinding("state") {
            if let key = info[NSObservedKeyPathKey] as? String, let target = info[NSObservedObjectKey] as? Graphic {
                if target.isSettable(key) {
                    target.setValue(sender.state == NSOnState, forKey: key)
                }
            }
        }
        drawingView.needsDisplay = true
    }
    
    @IBAction func stringValueChanged(_ sender: NSTextField) {
        if let info = sender.infoForBinding("stringValue") {
            if let key = info[NSObservedKeyPathKey] as? String, let target = info[NSObservedObjectKey] as? Graphic {
                if target.isSettable(key) {
                    target.setValue(sender.stringValue, forKey: key)
                }
            }
        }
        drawingView.needsDisplay = true
    }
    
    @IBAction func doubleValueChanged(_ sender: NSTextField) {
        if let info = sender.infoForBinding("doubleValue") {
            if let key = info[NSObservedKeyPathKey] as? String, let target = info[NSObservedObjectKey] as? Graphic {
                if target.isSettable(key) {
                    target.setValue(sender.doubleValue, forKey: key)
                }
            }
        }
        drawingView.needsDisplay = true
    }
    
    @IBAction func colorValueChanged(_ sender: NSColorWell) {
        if let info = sender.infoForBinding("color") {
            if let key = info[NSObservedKeyPathKey] as? String, let target = info[NSObservedObjectKey] as? Graphic {
                if target.isSettable(key) {
                    target.setValue(sender.color, forKey: key)
                }
            }
        }
        drawingView.needsDisplay = true
    }
    
    override func controlTextDidChange(_ notification: Notification) {
        if let textField = notification.object as? NSTextField {
            self.perform(textField.action, with: textField)
        }
    }
    
    func createInspectionFields() {
        var firstTextField: NSTextField?
        var lastTextField: NSTextField?
        
        fieldConstraints = []
        inspectionFields = []
        fieldBindings = []
        
        if let inspectee = inspectee {
            //Swift.print("Inspecting \(inspectee.inspectionName)")
            
            let title = NSTextField(frame: CGRect())
            title.translatesAutoresizingMaskIntoConstraints = false
            title.stringValue = inspectee.inspectionName
            title.isBordered = false
            title.isEditable = false
            addSubview(title)
            inspectionFields.append(title)
            fieldConstraints.append(NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: title, attribute: .top, multiplier: 1, constant: -8))
            fieldConstraints.append(NSLayoutConstraint(item: self, attribute: .left, relatedBy: .equal, toItem: title, attribute: .left, multiplier: 1, constant: -8))
            fieldConstraints.append(NSLayoutConstraint(item: title, attribute: .height, relatedBy: .equal, toItem: self, attribute: .height, multiplier: 0, constant: 20))
            fieldConstraints.append(NSLayoutConstraint(item: title, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1, constant: 8))
            
            var previousControl: NSControl = title
            
            for info in inspectee.inspectables {
                var control: NSControl
                
                switch info.type {
                case .bool:
                    let button = NSButton(frame: CGRect())
                    control = button
                    button.setButtonType(.switchButton)
                    button.title = ""
                    button.bind("state", to: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    button.action = #selector(switchValueChanged)
                    fieldBindings.append((button, "state"))
                    //needsName = false
                case .float, .int, .angle:
                    let textField = NSTextField(frame: CGRect())
                    control = textField
                    textField.bind("doubleValue", to: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    textField.action = #selector(doubleValueChanged)
                    fieldBindings.append((textField, "doubleValue"))
                case .string:
                    let textField = NSTextField(frame: CGRect())
                    control = textField
                    textField.bind("stringValue", to: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    textField.action = #selector(stringValueChanged)
                    fieldBindings.append((textField, "stringValue"))
               case .color:
                    let colorWell = NSColorWell(frame: CGRect())
                    control = colorWell
                    colorWell.bind("color", to: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    fieldConstraints.append(NSLayoutConstraint(item: colorWell, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 0, constant: 32))
                    colorWell.action = #selector(colorValueChanged)
                    fieldBindings.append((colorWell, "colorValue"))
                }
                control.translatesAutoresizingMaskIntoConstraints = false
                control.target = self
                if !inspectee.isSettable(info.name) {
                    control.isEnabled = false
                }
                addSubview(control)
                inspectionFields.append(control)
                
                fieldConstraints.append(NSLayoutConstraint(item: control, attribute: .top, relatedBy: .equal, toItem: previousControl, attribute: .bottom, multiplier: 1, constant: 8))
                fieldConstraints.append(NSLayoutConstraint(item: control, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1, constant: -8))
                if previousControl != title {
                    fieldConstraints.append(NSLayoutConstraint(item: previousControl, attribute: .width, relatedBy: .equal, toItem: control, attribute: .width, multiplier: 1, constant: 0))
                }
                
                let field = NSTextField(frame: CGRect())
                field.translatesAutoresizingMaskIntoConstraints = false
                field.isEditable = false
                field.isBordered = false
                field.stringValue = info.displayName
                field.alignment = .right
                addSubview(field)
                inspectionFields.append(field)
                fieldConstraints.append(NSLayoutConstraint(item: field, attribute: .lastBaseline, relatedBy: .equal, toItem: control, attribute: .lastBaseline, multiplier: 1, constant: 0))
                fieldConstraints.append(NSLayoutConstraint(item: field, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1, constant: 8))
                fieldConstraints.append(NSLayoutConstraint(item: field, attribute: .right, relatedBy: .equal, toItem: control, attribute: .left, multiplier: 1, constant: -8))

                previousControl = control
                if let textField = control as? NSTextField {
                    textField.isEditable = true
                    textField.isBordered = true
                    textField.isContinuous = true
                    textField.delegate = self
                    firstTextField = firstTextField ?? textField
                    lastTextField = textField
                    lastTextField?.nextKeyView = textField
                }
            }
            firstTextField?.nextKeyView = lastTextField
            fieldConstraints.append(NSLayoutConstraint(item: tableViewContainer, attribute: .top, relatedBy: .equal, toItem: previousControl, attribute: .bottom, multiplier: 1, constant: 8))
            tableView.isEnabled = inspectee is AttributedGraphic
            tableView.reloadData()
            addConstraints(fieldConstraints)
        }
    }
    
    // MARK: TableView Data
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        if let inspectee = inspectee as? AttributedGraphic {
            return inspectee.attributeNames.count
        }
        return 0
    }
    
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
        if let inspectee = inspectee as? AttributedGraphic {
            if let id = tableColumn?.identifier {
                switch id {
                case "Name":
                    return inspectee.attributeNames[row]
                case "Value":
                    let key = inspectee.attributeNames[row]
                    return inspectee.attributeValue(key)
                default: break
                }
            }
        }
        return nil
    }
    
    @IBAction func attributeChanged(_ sender: AnyObject) {
        let row = tableView.selectedRow
        if let g = inspectee as? AttributedGraphic where row >= 0 && row <= g.attributeNames.count {
            drawingView.setNeedsDisplay(g.bounds)
            g.setAttribute(sender.stringValue, name: g.attributeNames[row])
            drawingView.setNeedsDisplay(g.bounds)
        }
    }
        
    override func draw(_ dirtyRect: NSRect) {
        NSEraseRect(dirtyRect)
    }
}
