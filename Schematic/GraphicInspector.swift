//
//  GraphicInspector.swift
//  Schematic
//
//  Created by Matt Brandt on 5/19/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class GraphicInspector: NSView, NSTextFieldDelegate
{
    @IBOutlet var drawingView: SchematicView! {
        didSet {
            drawingView.addObserver(self, forKeyPath: "selection", options: .New, context: nil)
        }
    }
    
    var fieldConstraints: [NSLayoutConstraint] = []
    var inspectionFields: [NSControl] = []
    
    var inspectee: Graphic? {
        willSet {
            removeConstraints(fieldConstraints)
            fieldConstraints = []
            for f in inspectionFields {
                f.removeFromSuperview()
            }
            inspectionFields = []
        }
        didSet {
            createInspectionFields()
        }
    }
    
    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if drawingView.selection.count == 1 {
            inspectee = drawingView.selection[0]
        }
    }
    
    @IBAction func stringValueChanged(sender: NSTextField) {
        if let info = sender.infoForBinding("stringValue") {
            if let key = info[NSObservedKeyPathKey] as? String, let target = info[NSObservedObjectKey] as? Graphic {
                target.setValue(sender.stringValue, forKey: key)
            }
        }
        drawingView.needsDisplay = true
    }
    
    @IBAction func doubleValueChanged(sender: NSTextField) {
        if let info = sender.infoForBinding("doubleValue") {
            if let key = info[NSObservedKeyPathKey] as? String, let target = info[NSObservedObjectKey] as? Graphic {
                target.setValue(sender.doubleValue, forKey: key)
            }
        }
        drawingView.needsDisplay = true
    }
    
    @IBAction func colorValueChanged(sender: NSColorWell) {
        if let info = sender.infoForBinding("color") {
            if let key = info[NSObservedKeyPathKey] as? String, let target = info[NSObservedObjectKey] as? Graphic {
                target.setValue(sender.color, forKey: key)
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
        
        if let inspectee = inspectee {
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
                var needsName = true
                var control: NSControl
                
                switch info.type {
                case .Bool:
                    let button = NSButton(frame: CGRect())
                    control = button
                    button.setButtonType(.SwitchButton)
                    button.title = info.displayName
                    button.bind("boolValue", toObject: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    needsName = false
                case .Float, .Int, .Angle:
                    let textField = NSTextField(frame: CGRect())
                    control = textField
                    textField.bind("doubleValue", toObject: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    textField.action = #selector(doubleValueChanged)
                case .String:
                    let textField = NSTextField(frame: CGRect())
                    control = textField
                    textField.bind("stringValue", toObject: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    textField.action = #selector(stringValueChanged)
                case .Color:
                    let colorWell = NSColorWell(frame: CGRect())
                    control = colorWell
                    colorWell.bind("color", toObject: inspectee, withKeyPath: info.name, options: [NSContinuouslyUpdatesValueBindingOption: true])
                    fieldConstraints.append(NSLayoutConstraint(item: colorWell, attribute: .Height, relatedBy: .Equal, toItem: nil, attribute: .Height, multiplier: 0, constant: 32))
                    colorWell.action = #selector(colorValueChanged)
                case .Attribute:
                    let textField = NSTextField(frame: CGRect())
                    control = textField
                    textField.action = #selector(stringValueChanged)
                    if let attr = inspectee.valueForKey(info.name) {
                        textField.bind("stringValue", toObject: attr, withKeyPath: "string", options: [NSContinuouslyUpdatesValueBindingOption: true])
                    }
                }
                control.translatesAutoresizingMaskIntoConstraints = false
                control.target = self
                addSubview(control)
                inspectionFields.append(control)
                
                fieldConstraints.append(NSLayoutConstraint(item: control, attribute: .Top, relatedBy: .Equal, toItem: previousControl, attribute: .Bottom, multiplier: 1, constant: 8))
                fieldConstraints.append(NSLayoutConstraint(item: control, attribute: .Right, relatedBy: .Equal, toItem: self, attribute: .Right, multiplier: 1, constant: -8))
                if previousControl != title {
                    fieldConstraints.append(NSLayoutConstraint(item: previousControl, attribute: .Width, relatedBy: .Equal, toItem: control, attribute: .Width, multiplier: 1, constant: 0))
                }
                
                if needsName {
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
                } else {
                    fieldConstraints.append(NSLayoutConstraint(item: self, attribute: .Left, relatedBy: .Equal, toItem: control, attribute: .Left, multiplier: 1, constant: -8))
                }
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
            addConstraints(fieldConstraints)
            firstTextField?.nextKeyView = lastTextField
        }
    }
}
