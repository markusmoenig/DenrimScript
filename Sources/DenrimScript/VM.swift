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
    
    var globals         : [String: Value] = [:]

    init() {
        let stackMax = 256
        stack = UnsafeMutablePointer<Value>.allocate(capacity: stackMax)
        stack.initialize(repeating: Value.number(0), count: stackMax)
        stackTop = stack
        
        print("sizeof", MemoryLayout<Value>.size)
    }
    
    deinit {
        chunk = nil
        stack.deallocate()
    }
    
    /// Interpret the given chunk
    func interpret(source: String, errors: Errors) -> InterpretResult {
        
        chunk = Chunk()
        let compiler = Compiler()
        
        _ = compiler.compile(source: source, chunk: &chunk, errors: errors)
        
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
            
            //let offset = start.distance(to: ip)
            //print(chunk.disassemble(offset: offset).0)
            
            switch read() {
            
            case OpCode.Constant.rawValue:
                let constant = readConstant()
                push(constant)
                
            case OpCode.Nil.rawValue:
                push(Value.Nil(0))
                
            case OpCode.False.rawValue:
                push(Value.bool(false))
            case OpCode.True.rawValue:
                push(Value.bool(true))
                     
            case OpCode.Equal.rawValue:
                let b = pop()
                let a = pop()
                push(Value.bool(b.isEqualTo(a)))
                
            case OpCode.Greater.rawValue:
                let b = pop()
                let a = pop()
                push(Value.bool(a.greaterAs(b)))
                
            case OpCode.Less.rawValue:
                let b = pop()
                let a = pop()
                push(Value.bool(a.lessAs(b)))
                
            case OpCode.Add.rawValue:
                let b = pop(); let a = pop()
                if let value = a.add(b) { push(value) }
                else { runtimeError("Operands don't match."); return .RuntimeError }
            case OpCode.Subtract.rawValue:
                let b = pop(); let a = pop()
                if b.type() == a.type() && b.isNumber() {
                    push(Value.number(a.asNumber()! - b.asNumber()!))
                } else { runtimeError("Operand must be a number."); return .RuntimeError }
            case OpCode.Multiply.rawValue:
                let b = pop(); let a = pop()
                if b.type() == a.type() && b.isNumber() {
                    push(Value.number(a.asNumber()! * b.asNumber()!))
                } else { runtimeError("Operand must be a number."); return .RuntimeError }
            case OpCode.Divide.rawValue:
                let b = pop(); let a = pop()
                if b.type() == a.type() && b.isNumber() {
                    push(Value.number(a.asNumber()! / b.asNumber()!))
                } else { runtimeError("Operand must be a number."); return .RuntimeError }
                
            case OpCode.Not.rawValue:
                let v = pop()
                push(Value.bool(v.isFalsey()))
                
            case OpCode.Negate.rawValue:
                if peek(0).isNumber() {
                    push(Value.number(-pop().asNumber()!))
                } else { runtimeError("Operand must be a number."); return .RuntimeError }
                
            case OpCode.Print.rawValue:
                print(pop())
                
            case OpCode.Pop.rawValue:
                _ = pop()
                
            case OpCode.Return.rawValue:
                return .Ok
                
                
            // Global Variables
            case OpCode.GetGlobal.rawValue:
                let name = readConstant().toString()
                if let global = globals[name] {
                    push(global)
                } else {
                    runtimeError("Undefined variable '\(name)'.")
                    return .RuntimeError
                }
                
            case OpCode.DefineGlobal.rawValue:
                let global = readConstant().toString()
                globals[global] = pop()
                
            case OpCode.SetGlobal.rawValue:
                let name = readConstant().toString()
                if globals[name] != nil {
                    globals[name] = peek(0)
                } else {
                    runtimeError("Undefined variable '\(name)'.")
                    return .RuntimeError
                }
                
            // Local Variables
            case OpCode.GetLocal.rawValue:
                let slot = Int(read())
                push(stack[slot])

            case OpCode.SetLocal.rawValue:
                let slot = Int(read())
                stack[slot] = peek(0)

            // Control flow
            case OpCode.JumpIfFalse.rawValue:
                let offset = readShort()
                if peek(0).isFalsey() {
                    ip = ip.advanced(by: offset)
                }
                
            case OpCode.Jump.rawValue:
                let offset = readShort()
                ip = ip.advanced(by: offset)

            default: print("Unreachable")
            }
        }
    }
    
    /// Read an opcode and advance
    func read() -> OpCodeType {
        let op = ip.pointee
        ip = ip.advanced(by: 1)
        return op
    }
    
    /// Read an opcode and advance
    func readShort() -> Int {
        let byte1 = Int(ip.pointee)
        ip = ip.advanced(by: 1)
        let byte2 = Int(ip.pointee)
        ip = ip.advanced(by: 1)
        return byte1 << 8 | byte2
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
    
    /// Peek into the stack at the distance from the top
    func peek(_ distance: Int) -> Value {
        return stackTop.advanced(by: -1 - distance).pointee
    }
    
    func runtimeError(_ message: String) {
        print(message)
    }
    
    /// todo
    func printStack() {
    }
}
