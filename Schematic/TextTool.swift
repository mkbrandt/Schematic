//
//  TextTool.swift
//  Schematic
//
//  Created by Matt Brandt on 5/30/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

class TextTool: Tool, NSTextFieldDelegate
{
    var activeEditor: NSTextField?
    var currentAttribute: AttributeText?
    
    override var cursor: NSCursor   { return NSCursor.IBeamCursor() }
    
    func editAttribute(attribute: AttributeText, view: SchematicView) {
        clearEditing()
        currentAttribute = attribute
        let extra: NSString = "WW"
        let font = attribute.font
        var size = attribute.string.sizeWithAttributes(attribute.textAttributes)
        size.width += extra.sizeWithAttributes([NSFontAttributeName: font]).width
        let editor = NSTextField(frame: CGRect(origin: attribute.origin - CGPoint(length: 2, angle: attribute.angle), size: size))
        editor.font = font
        editor.bezeled = false
        editor.focusRingType = .None
        editor.frameRotation = attribute.angle * 180 / PI
        editor.delegate = self
        activeEditor = editor
        view.addSubview(editor)
        editor.stringValue = attribute.string as String
        editor.selectText(self)
        let menu = NSMenu()
        let mi = NSMenuItem(title: "Font", action: #selector(SchematicView.showFontPanel), keyEquivalent: "")
        mi.target = view
        menu.addItem(mi)
        let fieldEditor = view.window?.fieldEditor(true, forObject: editor)
        fieldEditor?.menu = menu
        NSFontPanel.sharedFontPanel().setPanelFont(attribute.font, isMultiple: false)
    }
    
    override func controlTextDidChange(obj: NSNotification) {
        if let editor = activeEditor {
            let extra: NSString = "WW"
            let text = editor.stringValue
            if let attr = currentAttribute {
                //attr.string = text
                var size = text.sizeWithAttributes([NSFontAttributeName: attr.font])
                size.width += extra.sizeWithAttributes([NSFontAttributeName: attr.font]).width
                var frame = editor.frame
                size.width = max(frame.size.width, size.width)
                frame.size = size
                editor.frame = frame
                if let view = editor.superview as? SchematicView {
                    view.setNeedsDisplayInRect(editor.bounds.insetBy(dx: -20, dy: -20))
                }
            }
        }
    }
    
    func control(control: NSControl, textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String] {
        if let attr = currentAttribute, let owner = attr.owner where control.stringValue.hasPrefix("=") {
            let curval = owner.stripPrefix(control.stringValue)
            let possible = owner.attributeNames.sort({ $0 < $1 }).filter { $0.hasPrefix(curval) }
            return possible
        }
        return words
    }
    
    override func controlTextDidEndEditing(obj: NSNotification?) {
        if let editor = activeEditor {
            if editor.stringValue.hasPrefix("=") {
                currentAttribute?.format = editor.stringValue
            } else {
                currentAttribute?.string = editor.stringValue
            }
            editor.delegate = nil
            if let view = editor.superview as? SchematicView {
                if editor.stringValue == "" {
                    if let currentAttribute = currentAttribute {
                        view.deleteGraphic(currentAttribute)
                    }
                    currentAttribute?.owner = nil
                }
                view.needsDisplay = true
                view.window?.makeFirstResponder(view)
            }
            editor.removeFromSuperview()
        }
        activeEditor = nil
        currentAttribute = nil
    }

    func clearEditing() {
        controlTextDidEndEditing(nil)
    }

    override func selectedTool(view: SchematicView) {
        
    }
    
    override func unselectedTool(view: SchematicView) {
        clearEditing()
    }
    
    override func mouseDown(location: CGPoint, view: SchematicView) {
        clearEditing()
        let el = view.findElementAtPoint(location)
        if let attr = el as? AttributeText {
            currentAttribute = attr
        } else if let ag = el as? AttributedGraphic {
            currentAttribute = AttributeText(origin: location, format: "Text", angle: 0, owner: ag)
        } else {
            let attr = AttributeText(origin: location, format: "Free Text", angle: 0, owner: nil)
            view.addGraphic(attr)
            currentAttribute = attr
        }
    }
    
    override func mouseDragged(location: CGPoint, view: SchematicView) {
        currentAttribute?.origin = view.snapToGrid(location)
    }
    
    override func mouseUp(location: CGPoint, view: SchematicView) {
        if let attr = currentAttribute {
            editAttribute(attr, view: view)
        }
    }
}
