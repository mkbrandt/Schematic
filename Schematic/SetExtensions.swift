//
//  SetExtensions.swift
//  Schematic
//
//  Created by Matt Brandt on 5/23/16.
//  Copyright © 2016 Walkingdog. All rights reserved.
//

import Foundation

public func +<T>(a: Set<T>, b: Set<T>) -> Set<T> {
    return a.union(b)
}

public func +<T>(a: Set<T>, b: [T]) -> Set<T> {
    return a.union(Set(b))
}

public func +<T>(a: [T], b: Set<T>) -> Set<T> {
    return b.union(Set(a))
}
