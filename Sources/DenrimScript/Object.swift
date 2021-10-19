//
//  Object.swift
//  
//
//  Created by Markus Moenig on 5/10/2564 BE.
//

import Foundation

public typealias float2 = SIMD2<Float>
public typealias float3 = SIMD3<Float>
public typealias float4 = SIMD4<Float>

/// The different kind of objects we support right now
public enum ObjectType {
    case NIL
    case bool
    case int
    case number
    case number2
    case number3
    case number4
    case string
    case function
    case klass
    case instance
    case boundMethod
    case nativeFunction
}

/// A function object
public class ObjectFunction {
    
    enum ObjectFunctionType {
        case function
        case initializer
        case method
        case script
    }
    
    /// Name of function
    var name            : String
    
    /// Body of function
    let chunk           : Chunk
    
    /// Number of function parameters
    var arity           : Int = 0
    
    init(_ name: String = "") {
        self.name = name
        chunk = Chunk()
    }
}

public typealias ClassInstantiationCB = (_ instance: ObjectInstance) -> Void

/// A class object
public class ObjectClass {
    
    /// Name of class
    var name            : String

    let instantiationCB : ClassInstantiationCB?
    
    /// Methods
    var methods         : [String:Object] = [:]
    
    init(name: String = "", instantiationCB: ClassInstantiationCB? = nil) {
        self.name = name
        self.instantiationCB = instantiationCB
    }
}

/// A class instance
public class ObjectInstance {
    
    /// Name of class
    var klass           : ObjectClass
    
    public var native   : Any? = nil
    
    public var fields   : [String:Object] = [:]
    
    init(_ klass: ObjectClass) {
        self.klass = klass
        
        // Call the CB
        if let cb = klass.instantiationCB {
            cb(self)
        }
    }
}

/// A bound method
public class ObjectBoundMethod {
    
    /// Receiver
    var receiver        : Object!
    
    /// Script method
    var method          : ObjectFunction!
    
    /// nativeMethod
    var nativeMethod    : ObjectNativeFunction!

    init(_ receiver: Object,_ method: ObjectFunction) {
        self.receiver = receiver
        self.method = method
    }
    
    init(_ receiver: Object,_ method: ObjectNativeFunction) {
        self.receiver = receiver
        self.nativeMethod = method
    }
}

public typealias NativeFunction = (_ args: [Object],_ classObj: ObjectInstance?) -> Object

public class ObjectNativeFunction {
    
    var function        : NativeFunction
    
    init(_ function: @escaping NativeFunction) {
        self.function = function
    }
}

/// The enum holding an object of a specific type
public enum Object {
    
    case NIL(Int = 0)
    case bool(Bool)
    case int(Int)
    case number(Double)
    case number2(float2)
    case number3(float3)
    case number4(float4)
    case string(String)
    case function(ObjectFunction)
    case klass(ObjectClass)
    case instance(ObjectInstance)
    case boundMethod(ObjectBoundMethod)
    case nativeFunction(ObjectNativeFunction)

    // Return type
    func type() -> ObjectType {
        switch self {
        case .NIL:      return .NIL
        case .bool:     return .bool
        case .int:      return .int
        case .number:   return .number
        case .number2:  return .number2
        case .number3:  return .number3
        case .number4:  return .number4
        case .string:   return .string
        case .function: return .function
        case .klass:    return .klass
        case .instance: return .instance
        case .boundMethod: return .boundMethod
        case .nativeFunction: return .nativeFunction
        }
    }
    
    // Check if this is nil
    func isNil() -> Bool {
        switch self {
        case .NIL:      return true
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
    
    // Check if this is a function
    func isFunction() -> Bool {
        switch self {
        case .function: return true
        default:        return false
        }
    }
    
    // Check if this is a class
    func isClass() -> Bool {
        switch self {
        case .klass:    return true
        default:        return false
        }
    }
    
    // Check if this value contains a false value
    func isFalsey() -> Bool {
        switch self {
        case .NIL:      return true
        case .bool(let boolValue): return !boolValue
        default: return false
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
    public func asNumber() -> Double? {
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
    
    // Return as string
    func asString() -> String? {
        switch self {
        case .string(let stringValue): return stringValue
        default: return nil
        }
    }
    
    // Return as function
    func asFunction() -> ObjectFunction? {
        switch self {
        case .function(let functionValue): return functionValue
        default: return nil
        }
    }
    
    // Return as class
    func asClass() -> ObjectClass? {
        switch self {
        case .klass(let classValue): return classValue
        default: return nil
        }
    }
    
    // Return as instance
    func asInstance() -> ObjectInstance? {
        switch self {
        case .instance(let instanceValue): return instanceValue
        default: return nil
        }
    }
    
    // Return a bound method
    func asBoundMethod() -> ObjectBoundMethod? {
        switch self {
        case .boundMethod(let boundMethodValue): return boundMethodValue
        default: return nil
        }
    }
    
    // Return a native function
    func asNativeFunction() -> ObjectNativeFunction? {
        switch self {
        case .nativeFunction(let nativeFunctionValue): return nativeFunctionValue
        default: return nil
        }
    }
    
    // equals
    func isEqualTo(_ other: Object) -> Bool {
        if type() == other.type() {
            switch self {
            case .NIL: return true
            case .bool(let boolValue): return boolValue == other.asBool()!
            case .int(let intValue): return intValue == other.asInt()!
            case .number(let doubleValue): return doubleValue == other.asNumber()!
            case .number2(let number2Value): return number2Value == other.asNumber2()!
            case .number3(let number3Value): return number3Value == other.asNumber3()!
            case .number4(let number4Value): return number4Value == other.asNumber4()!
            case .string(let stringValue): return stringValue == other.asString()!
            default: return false
            }
        }
        return false
    }
    
    // greaterAs
    func greaterAs(_ other: Object) -> Bool {
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
    func lessAs(_ other: Object) -> Bool {
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

    // add
    func add(_ onTheRight: Object) -> Object? {
        switch self {
        case .int(let value): if let r = onTheRight.asInt() { return .int(value + r) } else { return nil }
        case .number(let value): if let r = onTheRight.asNumber() { return .number(value + r) } else { return nil }
        case .string(let value): if let r = onTheRight.asString() { return .string(value + r) } else { return nil }
        //case .number2(let number2Value): return number2Value > other.asNumber2()!
        //case .number3(let number3Value): return number3Value > other.asNumber3()!
        //case .number4(let number4Value): return number4Value > other.asNumber4()!
        default:
            return nil
        }
    }
    
    // Convert Value to a string
    func toString() -> String {
        switch self {
        case .number(let value): return "<" + String(value) + ">"
        case .string(let value): return "<\"" + value + "\">"
        case .function(let value): return "<fn " + value.name + ">"
        case .klass(let value): return "<class " + value.name + ">"
        case .instance(let value): return "<instance " + value.klass.name + ">"
        case .boundMethod(let value): return "<boundMethod> \(value.method.name)"
        default: return ""
        }
    }
}

/// An array of objects
class ObjectArray<T> {
    var objects         = [T]()

    var count           : Int {
        return objects.count
    }
    
    /// Write a value
    func write(_ value: T) {
        objects.append(value)
    }
}
