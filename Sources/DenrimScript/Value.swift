//
//  File.swift
//  
//
//  Created by Markus Moenig on 5/10/2564 BE.
//

import Foundation

typealias float2 = SIMD2<Float>
typealias float3 = SIMD3<Float>
typealias float4 = SIMD4<Float>

enum ValueType {
    case Nil
    case bool
    case int
    case number
    case number2
    case number3
    case number4
}

enum Value {
    
    case Nil(Int)
    case bool(Bool)
    case int(Int)
    case number(Double)
    case number2(float2)
    case number3(float3)
    case number4(float4)
    
    // Return type
    func type() -> ValueType {
        switch self {
        case .Nil:      return .Nil
        case .bool:     return .bool
        case .int:      return .int
        case .number:   return .number
        case .number2:  return .number2
        case .number3:  return .number3
        case .number4:  return .number4
        }
    }
    
    // Check if this is nil
    func isNil() -> Bool {
        switch self {
        case .Nil:     return true
        default:        return false
        }
    }

    // Check if this is a boolean
    func isBool() -> Bool {
        switch self {
        case .bool:     return true
        default:        return false
        }
    }
    
    // Check if this is a number
    func isNumber() -> Bool {
        switch self {
        case .number:   return true
        default:        return false
        }
    }
    
    // Check if this value contains a false value
    func isFalsey() -> Bool {
        switch self {
        case .Nil:      return true
        case .bool(let boolValue): return !boolValue
        default:        return false
        }
    }
    
    // Return as a bool
    func asBool() -> Bool? {
        switch self {
        case .bool(let boolValue): return boolValue
        default: return nil
        }
    }
    
    // Return as int
    func asInt() -> Int? {
        switch self {
        case .int(let intValue): return intValue
        default: return nil
        }
    }
    
    // Return as number
    func asNumber() -> Double? {
        switch self {
        case .number(let doubleValue): return doubleValue
        default: return nil
        }
    }
    
    // Return as number
    func asNumber2() -> float2? {
        switch self {
        case .number2(let number2Value): return number2Value
        default: return nil
        }
    }
    
    // Return as number
    func asNumber3() -> float3? {
        switch self {
        case .number3(let number3Value): return number3Value
        default: return nil
        }
    }
    
    // Return as number
    func asNumber4() -> float4? {
        switch self {
        case .number4(let number4Value): return number4Value
        default: return nil
        }
    }
    
    // equals
    func isEqualTo(_ other: Value) -> Bool {
        if type() == other.type() {
            switch self {
            case .Nil: return true
            case .bool(let boolValue): return boolValue == other.asBool()!
            case .int(let intValue): return intValue == other.asInt()!
            case .number(let doubleValue): return doubleValue == other.asNumber()!
            case .number2(let number2Value): return number2Value == other.asNumber2()!
            case .number3(let number3Value): return number3Value == other.asNumber3()!
            case .number4(let number4Value): return number4Value == other.asNumber4()!
            }
        }
        return false
    }
    
    // greaterAs
    func greaterAs(_ other: Value) -> Bool {
        if type() == other.type() {
            switch self {
            case .int(let intValue): return intValue > other.asInt()!
            case .number(let doubleValue): return doubleValue > other.asNumber()!
            //case .number2(let number2Value): return number2Value > other.asNumber2()!
            //case .number3(let number3Value): return number3Value > other.asNumber3()!
            //case .number4(let number4Value): return number4Value > other.asNumber4()!
            default:
                return false
            }
        }
        return false
    }
    
    // lessAs
    func lessAs(_ other: Value) -> Bool {
        if type() == other.type() {
            switch self {
            case .int(let intValue): return intValue < other.asInt()!
            case .number(let doubleValue): return doubleValue < other.asNumber()!
            //case .number2(let number2Value): return number2Value > other.asNumber2()!
            //case .number3(let number3Value): return number3Value > other.asNumber3()!
            //case .number4(let number4Value): return number4Value > other.asNumber4()!
            default:
                return false
            }
        }
        return false
    }

    
    // Convert Value to a string
    func toString() -> String {
        switch self {
        case .number(let doubleValue): return String(doubleValue)
        default: return ""
        }
    }
}

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
