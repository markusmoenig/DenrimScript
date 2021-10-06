//
//  File.swift
//  
//
//  Created by Markus Moenig on 5/10/2564 BE.
//

typealias OpCodeType = UInt16

enum OpCode : OpCodeType {
    
    case Constant
    case Add
    case Subtract
    case Multiply
    case Divide
    case Negate
    case Return
    
}
