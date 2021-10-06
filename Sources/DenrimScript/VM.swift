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
    
    var start           : UnsafePointer<OpCodeType>!
    var ip              : UnsafePointer<OpCodeType>!
    
    var stack           : UnsafeMutablePointer<Value>
    var stackTop        : UnsafeMutablePointer<Value>

    init() {
        let stackMax = 256
        stack = UnsafeMutablePointer<Value>.allocate(capacity: stackMax)
        stack.initialize(repeating: 0, count: stackMax)
        stackTop = stack
    }
    
    deinit {
        chunk = nil
        stack.deallocate()
    }
    
    /// Interpret the given chunk
    func interpret(source: String) -> InterpretResult {
        
        var chunk = Chunk()
        let compiler = Compiler()
        
        _ = compiler.compile(source: source, chunk: &chunk)
        
        var rc : InterpretResult = .Ok
        
        chunk.code.withUnsafeBufferPointer { arrayPtr in
            if let ptr = arrayPtr.baseAddress {                
                ip = ptr
                start = ptr
                rc = run()
            }
        }
        return rc
    }
    
    /// The main loop of the interpreter
    func run() -> InterpretResult {
        while true {
            
            let offset = start.distance(to: ip)
            print(chunk.disassemble(offset: offset).0)
            
            switch read() {
            
            case OpCode.Constant.rawValue:
                let constant = readConstant()
                push(constant)
            case OpCode.Add.rawValue:
                let b = pop(); let a = pop()
                push(a + b)
            case OpCode.Subtract.rawValue:
                let b = pop(); let a = pop()
                push(a + b)
            case OpCode.Multiply.rawValue:
                let b = pop(); let a = pop()
                push(a * b)
            case OpCode.Divide.rawValue:
                let b = pop(); let a = pop()
                push(a / b)
            case OpCode.Negate.rawValue:
                push(-pop())
            case OpCode.Return.rawValue :
                print(pop())
                return .Ok
                            
            default: print("test")
            }
        }
    }
    
    /// Read an opcode and advance
    func read() -> OpCodeType {
        let op = ip.pointee
        ip = ip.advanced(by: 1)
        return op
    }
    
    /// Reads a constant
    func readConstant() -> Value {
        let index = Int(read())
        return chunk.constants.values[index]
    }
    
    /// Resets the stack
    func resetStack() {
        stackTop = stack
    }
    
    /// Push a value to the stack
    func push(_ value: Value) {
        stackTop.pointee = value
        stackTop = stackTop.advanced(by: 1)
    }
    
    /// Pop a value from the stack
    func pop() -> Value {
        stackTop = stackTop.advanced(by: -1)
        return stackTop.pointee
    }
    
    /// todo
    func printStack() {
        
    }
}
