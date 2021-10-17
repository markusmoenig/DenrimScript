//
//  File.swift
//  
//
//  Created by Markus Moenig on 6/10/2564 BE.
//

import Darwin

class VM {
    
    class CallFrame {
        var function        : ObjectFunction!
        var ip              : UnsafePointer<OpCodeType>!
        var slots           : UnsafeMutablePointer<Object>!
        
        init() {
        }
    }
    
    enum InterpretResult {
        case Ok
        case CompileError
        case RuntimeError
    }
        
    var stack           : UnsafeMutablePointer<Object>
    var stackTop        : UnsafeMutablePointer<Object>
    
    var frames          : UnsafeMutablePointer<CallFrame>
    var frameCount      : Int = 0
    
    var frame           : CallFrame!
    
    var globals         : [String: Object] = [:]

    let framesMax       = 64
    let stackMax        = 64 * Int(UInt8.max)
    
    init() {

        stack = UnsafeMutablePointer<Object>.allocate(capacity: stackMax)
        stack.initialize(repeating: Object.number(0), count: stackMax)
        stackTop = stack
        
        frames = UnsafeMutablePointer<CallFrame>.allocate(capacity: framesMax)
        frames.initialize(repeating: CallFrame(), count: framesMax)

        print("sizeof", MemoryLayout<Object>.size)
    }
    
    deinit {
        frames.deallocate()
        stack.deallocate()
    }
    
    /// Interpret the given chunk
    func interpret(source: String, errors: Errors) -> InterpretResult {
        
        let compiler = Compiler()
            
        var rc : InterpretResult = .Ok

        if let function = compiler.compile(source: source, errors: errors) {
            
            _ = call(function, 0)
            rc = run()

            /*
            function.chunk.code.withUnsafeBufferPointer { arrayPtr in
                if let ptr = arrayPtr.baseAddress {
                    
                    frame = frames[0]
                    frame.function = function
                    frame.ip = ptr
                    frame.slots = stack

                    frameCount += 1

                    rc = run()
                }
            }*/
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
                push(Object.Nil(0))
                
            case OpCode.False.rawValue:
                push(Object.bool(false))
            case OpCode.True.rawValue:
                push(Object.bool(true))
                     
            case OpCode.Equal.rawValue:
                let b = pop()
                let a = pop()
                push(Object.bool(b.isEqualTo(a)))
                
            case OpCode.Greater.rawValue:
                let b = pop()
                let a = pop()
                push(Object.bool(a.greaterAs(b)))
                
            case OpCode.Less.rawValue:
                let b = pop()
                let a = pop()
                push(Object.bool(a.lessAs(b)))
                
            case OpCode.Add.rawValue:
                let b = pop(); let a = pop()
                if let value = a.add(b) { push(value) }
                else { runtimeError("Operands don't match."); return .RuntimeError }
            case OpCode.Subtract.rawValue:
                let b = pop(); let a = pop()
                if b.type() == a.type() && b.isNumber() {
                    push(Object.number(a.asNumber()! - b.asNumber()!))
                } else { runtimeError("Operand must be a number."); return .RuntimeError }
            case OpCode.Multiply.rawValue:
                let b = pop(); let a = pop()
                if b.type() == a.type() && b.isNumber() {
                    push(Object.number(a.asNumber()! * b.asNumber()!))
                } else { runtimeError("Operand must be a number."); return .RuntimeError }
            case OpCode.Divide.rawValue:
                let b = pop(); let a = pop()
                if b.type() == a.type() && b.isNumber() {
                    push(Object.number(a.asNumber()! / b.asNumber()!))
                } else { runtimeError("Operand must be a number."); return .RuntimeError }
                
            case OpCode.Not.rawValue:
                let v = pop()
                push(Object.bool(v.isFalsey()))
                
            case OpCode.Negate.rawValue:
                if peek(0).isNumber() {
                    push(Object.number(-pop().asNumber()!))
                } else { runtimeError("Operand must be a number."); return .RuntimeError }
                
            case OpCode.Print.rawValue:
                print(pop())
                
            case OpCode.Pop.rawValue:
                _ = pop()
                
            case OpCode.Return.rawValue:
                
                let result = pop()
                frameCount -= 1
                if frameCount == 0 {
                    _ = pop()
                    return .Ok
                }
                stackTop = frame.slots
                push(result)
                frame = frames[frameCount - 1]
                
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
                push(frame.slots[slot])

            case OpCode.SetLocal.rawValue:
                let slot = Int(read())
                frame.slots[slot] = peek(0)

            // Control flow
            case OpCode.JumpIfFalse.rawValue:
                let offset = readShort()
                if peek(0).isFalsey() {
                    frame.ip = frame.ip.advanced(by: offset)
                }
                
            case OpCode.Jump.rawValue:
                let offset = readShort()
                frame.ip = frame.ip.advanced(by: offset)
                
            case OpCode.Loop.rawValue:
                let offset = readShort()
                frame.ip = frame.ip.advanced(by: -offset)

            case OpCode.Call.rawValue:
                let argCount = read()
                if !callValue(peek(Int(argCount)), Int(argCount)) {
                    return .RuntimeError
                }
                frame = frames[frameCount - 1]

            default: print("Unreachable")
            }
        }
    }
    
    /// Read an opcode and advance
    func read() -> OpCodeType {
        let op = frame.ip.pointee
        frame.ip = frame.ip.advanced(by: 1)
        return op
    }
    
    /// Read an opcode and advance
    func readShort() -> Int {
        let byte1 = Int(frame.ip.pointee)
        frame.ip = frame.ip.advanced(by: 1)
        let byte2 = Int(frame.ip.pointee)
        frame.ip = frame.ip.advanced(by: 1)
        return byte1 << 8 | byte2
    }
    
    /// Reads a constant
    func readConstant() -> Object {
        let index = Int(read())
        return frame.function.chunk.constants.objects[index]
    }
    
    /// Resets the stack
    func resetStack() {
        stackTop = stack
        frameCount = 1
    }
    
    /// Push a value to the stack
    func push(_ value: Object) {
        stackTop.pointee = value
        stackTop = stackTop.advanced(by: 1)
    }
    
    /// Pop a value from the stack
    func pop() -> Object {
        stackTop = stackTop.advanced(by: -1)
        return stackTop.pointee
    }
    
    /// Peek into the stack at the distance from the top
    func peek(_ distance: Int) -> Object {
        return stackTop.advanced(by: -1 - distance).pointee
    }
    
    ///
    func callValue(_ callee: Object,_ argCount: Int) -> Bool {
        if callee.isFunction() {
            if let function = callee.asFunction() {
                return call(function, argCount)
            }
        } else {
            runtimeError("Can only call functions and classes.")
        }
        return false
    }
    
    func call(_ function: ObjectFunction,_ argCount: Int) -> Bool {
        
        if argCount != function.arity {
            runtimeError("Expected \(function.arity) arguments but got \(argCount).")
            return false
        }
        
        if (frameCount == framesMax ) {
            runtimeError("Stack overflow.")
            return false
        }

        frame = frames[frameCount]
        frameCount += 1
        frame.function = function
        frame.slots = stackTop.advanced(by: -argCount - 1)
        
        function.chunk.code.withUnsafeBufferPointer { arrayPtr in
            if let ptr = arrayPtr.baseAddress {
                frame.ip = ptr
            }
        }
        
        return true
    }
    
    ///
    func runtimeError(_ message: String) {
        print(message)
    }
    
    /// todo
    func printStack() {
    }
}
