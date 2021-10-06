//
//  File.swift
//  
//
//  Created by Markus Moenig on 6/10/2564 BE.
//

import Darwin

class VM {
    
    enum InterpretResult {
        case Ok
        case CompileError
        case RuntimeError
    }
    
    var chunk           : Chunk!
    
    var ip              : UnsafePointer<OpCodeType>!
    
    init() {
    }
    
    deinit {
        chunk = nil
    }
    
    /// Interpret the given chunk
    func interpret(_ chunk: Chunk) -> InterpretResult {
        
        self.chunk = chunk
        var rc : InterpretResult = .Ok
        
        chunk.code.withUnsafeBufferPointer { arrayPtr in
            if let ptr = arrayPtr.baseAddress {                
                ip = ptr
                rc = run()
            }
        }
        return rc
    }
    
    /// The main loop of the interpreter
    func run() -> InterpretResult {
        while true {
            switch read() {
            
            case OpCode.Constant.rawValue:
                let constant = readConstant()
                print("Constant", constant)
            case OpCode.Return.rawValue :
                return .Ok
                            
            default: print("test")
            }
        }
    }
    
    /// Read an opcode and advance
    func read() -> UInt16 {
        let op = ip.pointee
        ip = ip.advanced(by: 1)
        return op
    }
    
    /// Reads a constant
    func readConstant() -> Value {
        let index = Int(read())
        return chunk.constants.values[index]
    }
}
