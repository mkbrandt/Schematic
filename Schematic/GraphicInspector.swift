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
            drawingView.addObserver(self, forKeyPath: "selection", options: .New, context: nil)
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
        }
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if drawingView.selection.count == 1 {
            inspectee = drawingView.selection.first
        } else {
            inspectee = nil
        }
    }
    
    @IBAction func switchValueChanged(sender: NSButton) {
        if let info = sender.infoForBinding("state") {
            if let key = info[NSObservedKeyPathKey] as? String, let target = info[NSObservedObjectKey] as? Graphic {
                if target.isSettable(key) {
                    target.setValue(sender.state == NSOnState, forKey: key)
                }
            }
        }
        drawingView.needsDisplay = true
    }
    
    @IBAction func stringValueChanged(sender: NSTextField) {
        if let info = sender.infoForBinding("stringValue") {
            if let key = info[NSObservedKeyPathKey] as? String, let target = info[NSObservedObjectKey] as? Graphic {
                if target.isSettable(key) {
                    target.setValue(sender.stringValue, forKey: key)
                }
            }
        }
        drawingView.needsDisplay = true
    }
    
    @IBAction func doubleValueChanged(sender: NSTextField) {
        if let info = sender.infoForBinding("doubleValue") {
            if let key = info[NSObservedKeyPathKey] as? String, let target = info[NSObservedObjectKey] as? Graphic {
                if target.isSettable(key) {
                    target.setValue(sender.doubleValue, forKey: key)
                }
            }
        }
        drawingView.needsDisplay = true
    }
    
    @IBAction func colorValueChanged(sender: NSColorWell) {
        if let info = sender.infoForBinding("color") {
            if let key = info[NSObservedKeyPathKey] as? String, let target = info[NSObservedObjectKey] as? Graphic {
                if target.isSettable(key) {
                    target.setValue(sender.color, forKey: key)
                }
            }
        }
        drawingView.needsDisplay = true
    }
    
    override func controlTextDidChange(notification: NSNotification) {
        if let textField = notification.object as? NSTextField {
            self.performSelector(textField.action, withObject: textField)
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
            title.bordered = false
            title.editable = false
            addSubview(title)
            inspectionFields.append(title)
            fieldConstraints.append(NSLayoutConstraint(item: self, attribute: .Top, relatedBy: .Equal, toItem: title, attribute: .Top, multiplier: 1, constant: -8))
            fieldConstraints.append(NSLayoutConstraint(item: self, attribute: .Left, relatedBy: .Equal, toItem: title, attribute: .Left, multiplier: 1, constant: -8))
            fieldConstraints.append(NSLayoutConstraint(item: title, attribute: .Height, relatedBy: .Equal, toItem: self, attribute: .Height, multiplier: 0, constant: 20))
            fieldConstraints.append(NSLayoutConstraint(item: title, attribute: .Right, relatedBy: .Equal, toItem: self, attribute: .Right, multiplier: 1, constant: 8))
            
            var previousControl: NSControl = title
            
            for info in inspectee.inspectables {
                var control: NSControl
                
                switch info.type {
                case .Bool:
                    let button = NSButton(frame: CGRect())
                    control = button
                    button.setButtonType(.SwitchButton)
                    button.title = ""
                    button.bind("state", toObject: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    button.action = #selector(switchValueChanged)
                    fieldBindings.append((button, "state"))
                    //needsName = false
                case .Float, .Int, .Angle:
                    let textField = NSTextField(frame: CGRect())
                    control = textField
                    textField.bind("doubleValue", toObject: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    textField.action = #selector(doubleValueChanged)
                    fieldBindings.append((textField, "doubleValue"))
                case .String:
                    let textField = NSTextField(frame: CGRect())
                    control = textField
                    textField.bind("stringValue", toObject: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    textField.action = #selector(stringValueChanged)
                    fieldBindings.append((textField, "stringValue"))
               case .Color:
                    let colorWell = NSColorWell(frame: CGRect())
                    control = colorWell
                    colorWell.bind("color", toObject: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    fieldConstraints.append(NSLayoutConstraint(item: colorWell, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .Height, multiplier: 0, constant: 32))
                    colorWell.action = #selector(colorValueChanged)
                    fieldBindings.append((colorWell, "colorValue"))
                }
                control.translatesAutoresizingMaskIntoConstraints = false
                control.target = self
                if !inspectee.isSettable(info.name) {
                    control.enabled = false
                }
                addSubview(control)
                inspectionFields.append(control)
                
                fieldConstraints.append(NSLayoutConstraint(item: control, attribute: .Top, relatedBy: .Equal, toItem: previousControl, attribute: .Bottom, multiplier: 1, constant: 8))
                fieldConstraints.append(NSLayoutConstraint(item: control, attribute: .Right, relatedBy: .Equal, toItem: self, attribute: .Right, multiplier: 1, constant: -8))
                if previousControl != title {
                    fieldConstraints.append(NSLayoutConstraint(item: previousControl, attribute: .Width, relatedBy: .Equal, toItem: control, attribute: .Width, multiplier: 1, constant: 0))
                }
                
                let field = NSTextField(frame: CGRect())
                field.translatesAutoresizingMaskIntoConstraints = false
                field.editable = false
                field.bordered = false
                field.stringValue = info.displayName
                field.alignment = .Right
                addSubview(field)
                inspectionFields.append(field)
                fieldConstraints.append(NSLayoutConstraint(item: field, attribute: .Baseline, relatedBy: .Equal, toItem: control, attribute: .Baseline, multiplier: 1, constant: 0))
                fieldConstraints.append(NSLayoutConstraint(item: field, attribute: .Left, relatedBy: .Equal, toItem: self, attribute: .Left, multiplier: 1, constant: 8))
                fieldConstraints.append(NSLayoutConstraint(item: field, attribute: .Right, relatedBy: .Equal, toItem: control, attribute: .Left, multiplier: 1, constant: -8))

                previousControl = control
                if let textField = control as? NSTextField {
                    textField.editable = true
                    textField.bordered = true
                    textField.continuous = true
                    textField.delegate = self
                    firstTextField = firstTextField ?? textField
                    lastTextField = textField
                    lastTextField?.nextKeyView = textField
                }
            }
            firstTextField?.nextKeyView = lastTextField
            fieldConstraints.append(NSLayoutConstraint(item: tableViewContainer, attribute: .Top, relatedBy: .Equal, toItem: previousControl, attribute: .Bottom, multiplier: 1, constant: 8))
            tableView.enabled = inspectee is AttributedGraphic
            tableView.reloadData()
            addConstraints(fieldConstraints)
        }
    }
    
    // MARK: TableView Data
    
    func numberOfRowsInTableView(tableView: NSTableView) -> Int {
        if let inspectee = inspectee as? AttributedGraphic {
            return inspectee.attributeNames.count
        }
        return 0
    }
    
    func tableView(tableView: NSTableView, objectValueForTableColumn tableColumn: NSTableColumn?, row: Int) -> AnyObject? {
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
    
    func tableView(tableView: NSTableView, shouldEditTableColumn tableColumn: NSTableColumn?, row: Int) -> Bool {
        return true
    }
    
    override func drawRect(dirtyRect: NSRect) {
        NSEraseRect(dirtyRect)
    }
}
