//
//  File.swift
//  
//
//  Created by Markus Moenig on 5/10/2564 BE.
//

import Foundation

typealias Value = Double

class ConstantArray<T> {
    var values          = [T]()

    var count           : Int {
        return values.count
    }
    
    /// Write a value
    func write(_ value: T) {
        values.append(value)
    }
}
