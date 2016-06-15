//
//  SetExtensions.swift
//  Schematic
//
//  Created by Matt Brandt on 5/23/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Cocoa

public func +<T>(a: Set<T>, b: Set<T>) -> Set<T> {
    return a.union(b)
}

public func +<T>(a: Set<T>, b: [T]) -> Set<T> {
    return a.union(Set(b))
}

public func +<T>(a: [T], b: Set<T>) -> Set<T> {
    return b.union(Set(a))
}

var ActionBlockKey: UInt8 = 0

// a type for our action block closure
typealias BlockButtonActionBlock = (sender: AnyObject?) -> Void

class ActionBlockWrapper : NSObject {
    var block : BlockButtonActionBlock
    init(block: BlockButtonActionBlock) {
        self.block = block
    }
}

extension NSControl {
    func block_setAction(block: BlockButtonActionBlock) {
        objc_setAssociatedObject(self, &ActionBlockKey, ActionBlockWrapper(block: block), objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        self.target = self
        self.action = #selector(block_handleAction)
    }
    
    func block_handleAction(sender: NSControl) {
        if let wrapper = objc_getAssociatedObject(self, &ActionBlockKey) as? ActionBlockWrapper {
            wrapper.block(sender: sender)
        }
    }
}
