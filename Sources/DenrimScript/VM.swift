//
//  File.swift
//  
//
//  Created by Markus Moenig on 6/10/2564 BE.
//

import Darwin
import Metal

@available(macOS 10.11, *)
class VM {
    
    class CallFrame {
        var function        : ObjectFunction!
        var ipStart         : UnsafePointer<OpCodeType>!
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
    
    var g               : DenrimScript.Globals
    
    var denrim          : DenrimScript!
        
    var stack           : UnsafeMutablePointer<Object>
    var stackTop        : UnsafeMutablePointer<Object>
    
    var frames          : [CallFrame] = []//UnsafeMutablePointer<CallFrame>
    var frameCount      : Int = 0
    
    var frame           : CallFrame!
    
    let framesMax       = 64
    let stackMax        = 64 * Int(UInt8.max)
    
    let device          : MTLDevice?
    
    var shader          : Shader? = nil
    
    var mainFunction    : ObjectFunction? = nil

    init(_ g: DenrimScript.Globals,_ device: MTLDevice? = nil) {
        self.device = device
        self.g = g
        
        stack = UnsafeMutablePointer<Object>.allocate(capacity: stackMax)
        stack.initialize(repeating: Object.number(0), count: stackMax)
        stackTop = stack
        
        //frames = UnsafeMutablePointer<CallFrame>.allocate(capacity: framesMax)
        //frames.initialize(repeating: CallFrame(), count: framesMax)
        for _ in 0..<framesMax {
            frames.append(CallFrame())
        }

        //print("sizeof", MemoryLayout<Object>.size)
    }
    
    deinit {
        clean()
    }
    
    /// Deallocate VM
    func clean() {
        if let shader = shader {
            shader.library = nil
            shader.states = [:]
        }
        shader = nil
        for f in frames {
            if let fun = f.function {
                fun.chunk.clean()
            }
        }
        frames = []
        stack.deallocate()
    }
    
    /// Interpret the given chunk
    func interpret(source: String, errors: Errors) {
        
        stackTop = stack
        frameCount = 0
        
        let compiler = Compiler()

        if let function = compiler.compile(source: source, errors: errors) {
            
            if compiler.metalCode.isEmpty == false {

                if let device = device {
                    let shaderCompiler = ShaderCompiler(device)
                    shaderCompiler.compile(code: compiler.metalCode, entryFuncs: compiler.metalEntryFunctions, asyncCompilation: false, errors: errors, lineMap: compiler.metalLineMap, cb: { shader in
                        
                        self.shader = shader
                    })
                }
            }
            
            mainFunction = function
        }
    }
    
    /// Execute the main function
    func execute() -> InterpretResult {
        var rc : InterpretResult = .Ok

        if let function = mainFunction {

            _ = call(function, 0)
            rc = run()
        }
        return rc
    }
    
    /// The main loop of the interpreter
    func run() -> InterpretResult {
        
        frame = frames[frameCount - 1]

        //print(printConstants())
        //print("")

        while true {
                        
            //let offset = frame.ipStart.distance(to: frame.ip)
            //print(printFunctionStack())
            //print(printStack())
            //print(frame.function.chunk.disassemble(offset: offset).0)
            //print("")
            
            switch read() {
            
            case OpCode.Constant.rawValue:
                let constant = readConstant()
                push(constant)
                
            case OpCode.Nil.rawValue:
                push(Object.NIL())
                
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
                print(pop().toString())
                
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
                let name = readConstant().asString()!
                if let global = g.globals[name] {
                    push(global)
                } else {
                    runtimeError("Undefined variable '\(name)'.")
                    return .RuntimeError
                }
                
            case OpCode.DefineGlobal.rawValue:
                let global = readConstant().asString()!
                g.globals[global] = pop()
                
            case OpCode.SetGlobal.rawValue:
                let name = readConstant().asString()!
                if g.globals[name] != nil {
                    g.globals[name] = peek(0)
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
                
            case OpCode.Class.rawValue:
                let name = readConstant()
                push(.klass(ObjectClass(name: name.asString()!)))
                
            case OpCode.GetProperty.rawValue:
                if let instance = peek(0).asInstance() {
                    let name = readConstant().asString()!

                    if let value = instance.fields[name] {
                        _ = pop()
                        push(value)
                    } else {
                        if !bindMethod(klass: instance.klass, name: name) {
                            //runtimeError("Undefined property '\(name)'.")
                            return .RuntimeError
                        }
                    }
                } else {
                    runtimeError("Only instances have properties.")
                    return .RuntimeError
                }

            case OpCode.SetProperty.rawValue:
                
                if let instance = peek(1).asInstance() {
                    let name = readConstant().asString()!

                    instance.fields[name] = peek(0)
                    
                    let v = pop()
                    _ = pop()
                    push(v)
                } else {
                    runtimeError("Only instances have fields.")
                    return .RuntimeError
                }
                
            case OpCode.Method.rawValue:
                let name = readConstant().asString()!
                defineMethod(name)

            default: print("Unreachable")
            }
        }
    }
    
    /// Read an opcode and advance
    @inlinable func read() -> OpCodeType {
        let op = frame.ip.pointee
        frame.ip = frame.ip.advanced(by: 1)
        return op
    }
    
    /// Read an opcode and advance
    @inlinable func readShort() -> Int {
        let byte1 = Int(frame.ip.pointee)
        frame.ip = frame.ip.advanced(by: 1)
        let byte2 = Int(frame.ip.pointee)
        frame.ip = frame.ip.advanced(by: 1)
        return byte1 << 8 | byte2
    }
    
    /// Reads a constant
    @inlinable func readConstant() -> Object {
        let index = Int(read())
        return frame.function.chunk.constants.objects[index]
    }
    
    /// Resets the stack
    func resetStack() {
        stackTop = stack
        frameCount = 0
    }
    
    /// Push a value to the stack
    @inlinable func push(_ value: Object) {
        stackTop.pointee = value
        stackTop = stackTop.advanced(by: 1)
    }
    
    /// Pop a value from the stack
    @inlinable func pop() -> Object {
        stackTop = stackTop.advanced(by: -1)
        return stackTop.pointee
    }
    
    /// Peek into the stack at the distance from the top
    @inlinable func peek(_ distance: Int) -> Object {
        return stackTop.advanced(by: -1 - distance).pointee
    }
    
    /// Method or function call
    func callValue(_ callee: Object,_ argCount: Int) -> Bool {
        
        /// Call a native function
        func callNative(_ nativeFn: ObjectNativeFunction,_ classInstance: ObjectInstance? = nil, isInit : Bool = false) {
            // Would prefer to use variadic functions here but as splatting is not yet inside
            // Swift use arrays for now.
            
            var objects : [Object] = []
            var ip = stackTop.advanced(by: -argCount)

            for _ in 0..<argCount {
                objects.append(ip.pointee)
                ip = ip.advanced(by: 1)
            }
                        
            let result = nativeFn.function(objects, classInstance)
            
            if isInit {
                stackTop = stackTop.advanced(by: -argCount)
            } else {
                stackTop = stackTop.advanced(by: -argCount - 1)
                push(result)
            }
        }
        
        /// Call a shader function
        func callShader(_ fn: ObjectFunction) {
            var objects : [Object] = []
            var ip = stackTop.advanced(by: -argCount)

            for _ in 0..<argCount {
                objects.append(ip.pointee)
                ip = ip.advanced(by: 1)
            }
            
            if objects.count >= 1, let tex = objects[0].asInstance() {
                if tex.klass.role == .tex2d {
                    // Success, first arg is a texture
                    if let state = shader?.states[fn.name] {
                        // Got the pipeline state
                        denrim.callShaderFunction(state, objects)
                    }
                } else {
                    runtimeError("First argument for shentry '\(fn.name)' must be a Tex2D instance.")
                }
            }  else {
                runtimeError("First argument for shentry '\(fn.name)' must be a Tex2D instance.")
            }
            
            push(.NIL())
        }
        
        if let function = callee.asFunction() {
            if function.isShEntry == false {
                return call(function, argCount)
            } else {
                callShader(function)
                return true
            }
        } else
        if let nativeFn = callee.asNativeFunction() {
            callNative(nativeFn)
            return true
        } else
        if let klass = callee.asClass() {
            
            let ip = stackTop.advanced(by: -argCount - 1)
            
            let instance = ObjectInstance(klass)
            ip.pointee = .instance(instance)
            
            // Call init if available on a new class instance
            
            if let fn = klass.methods["init"]?.asFunction() {
                _ = call(fn, argCount)
            } else
            if let nativeFn = klass.methods["init"]?.asNativeFunction() {
                callNative(nativeFn, instance, isInit: true)
            }
            
            return true
        } else
        if let boundMethod = callee.asBoundMethod() {
            if let nativeFn = boundMethod.nativeMethod {
                callNative(nativeFn, boundMethod.receiver.asInstance())
                return true
            } else {
                
                // Set the first local to the receiver for "this" support
                let ip = stackTop.advanced(by: -argCount - 1)
                ip.pointee = boundMethod.receiver
                
                return call(boundMethod.method, argCount)
            }
        } else {
            runtimeError("Can only call functions and classes.")
        }
        return false
    }
    
    /// Call a function
    func call(_ function: ObjectFunction,_ argCount: Int) -> Bool {
        
        if argCount != function.arity {
            runtimeError("Expected \(function.arity) arguments but got \(argCount).")
            return false
        }
        
        if (frameCount == framesMax ) {
            runtimeError("Stack overflow.")
            return false
        }

        let frame = frames[frameCount]
        frameCount += 1
        frame.function = function
        frame.slots = stackTop.advanced(by: -argCount - 1)

        function.chunk.code.withUnsafeBufferPointer { arrayPtr in
            if let ptr = arrayPtr.baseAddress {
                frame.ip = ptr
                frame.ipStart = ptr
            }
        }
        
        return true
    }

    /// Adds a method to a class
    func defineMethod(_ name: String) {
        if let klass = peek(1).asClass() {
            let method = peek(0)
            
            klass.methods[name] = method
            
            _ = pop()
        }
    }
    
    ///
    func runtimeError(_ message: String) {
        print(message)
    }
    
    /// Print the functionstack
    func printFunctionStack() -> String {
        var offset = frameCount - 1
        
        var s = "Function Stack: "
        
        while offset >= 0 {
            let frame = frames[offset]
            s += "\(frame.function.name == "" ? "<script>" : frame.function.name) "
            offset -= 1
        }
                        
        return s
    }
    
    /// Print the stack
    func printStack() -> String {
        var offset = stack.distance(to: stackTop) - 1
        
        var s = "Stack: ["
        
        while offset >= 0 {
            
            s += stack[offset].toString()
            offset -= 1
        }
        
        s += "]"
        
        return s
    }
    
    /// Print the constants
    func printConstants() -> String {
        
        let c = frame.function.chunk
        var s = "Constants: {"

        for i in 0..<c.constants.objects.count {
            s += c.constants.objects[i].toString() + " "
        }
        s += "}"
        
        return s
    }
    
    /// Bind the given method passed by name of the given class
    func bindMethod(klass: ObjectClass, name: String ) -> Bool {
        if let method = klass.methods[name] {
            if let fn = method.asFunction() {
                let bound = ObjectBoundMethod(peek(0), fn)
                _ = pop()
                push(.boundMethod(bound))
            } else
            if let fn = method.asNativeFunction() {
                let bound = ObjectBoundMethod(peek(0), fn)
                _ = pop()
                push(.boundMethod(bound))
            }
        } else {
            runtimeError("Undefined property '\(name)'.")
            return false ;
        }
        
        return true
    }
}
