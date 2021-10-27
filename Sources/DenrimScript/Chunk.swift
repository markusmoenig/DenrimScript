//
//  Chunk.swift
//  
//
//  Created by Markus Moenig on 5/10/2564 BE.
//

import Foundation

class Chunk {
    
    // We use Swift's inbuild growth strategy
    
    /// Opcodes
    var code            = [OpCodeType]()
    var count           : Int {
        return code.count
    }

    /// Constants
    var constants       = ObjectArray<Object>()

    /// Lines
    var lines           = ObjectArray<Int>()
    
    deinit {
        clean()
    }
    
    func clean() {
        code.removeAll()
        constants.clean()
    }
    
    /// Write an opcode to the chunk
    func write(_ opcode: OpCodeType, line: Int) {
        code.append(opcode)
        lines.write(line)
    }
    
    /// Add a constant and return its offset
    @discardableResult func addConstant(_ value: Object, writeOffset: Bool = true, line: Int) -> OpCodeType {
        constants.write(value)
        let offset = OpCodeType(constants.count - 1)
        if writeOffset {
            write(OpCodeType(exactly: offset)!, line: line)
        }
        return offset
    }
    
    /// Create a string representation of the bytecode
    func disassemble(name: String) -> String {
        var result = "== \(name) ==\n"
        
        var i = 0
        while i < count {
            let d = disassemble(offset: i)
            result += d.0 + "\n"
            i = d.1
        }
        return result
    }
    
    /// Create a string for an individual op
    func disassemble(offset: Int) -> (String, Int) {
        let op = code[offset]
        var outOffset = offset + 1
        
        var outString = String(format: "%04d ", offset) + "  "
        
        let line = lines.objects[offset]
        
        if offset > 0 && line == lines.objects[offset - 1] {
            outString += "   |   "
        } else {
            outString += String(format: "%4d ", line) + "  "
        }
        
        func printConstant(_ spaces: String) {
            let constantOffset = Int(exactly: code[offset + 1])!
            outString += spaces + String(constantOffset) + "  '" + constants.objects[constantOffset].toString() + "'"
            outOffset += 1
        }
        
        func printByteInstruction(_ spaces: String) {
            let constantOffset = Int(exactly: code[offset + 1])!
            outString += spaces + String(constantOffset)
            outOffset += 1
        }
        
        func printShortInstruction(_ spaces: String) {
            let b1 = Int(exactly: code[offset + 1])!
            let b2 = Int(exactly: code[offset + 2])!
            outString += spaces + String(b1 << 8 | b2)
            outOffset += 2
        }

        switch OpCode(rawValue: op)! {
        case .Constant:     outString += "OP_CONSTANT"
            printConstant("      ")
        case .Add:          outString += "OP_ADD"
        case .Subtract:     outString += "OP_SUBTRACT"
        case .Multiply:     outString += "OP_MULTIPLY"
        case .Divide:       outString += "OP_DIVIDE"
        case .Negate:       outString += "OP_NEGATE"
        case .Return:       outString += "OP_RETURN"
        case .Nil:          outString += "OP_NIL"
        case .True:         outString += "OP_TRUE"
        case .False:        outString += "OP_FALSE"
        case .Not:          outString += "OP_NOT"
        case .Equal:        outString += "OP_EQUAL"
        case .Greater:      outString += "OP_GREATER"
        case .Less:         outString += "OP_LESS"
        case .Print:        outString += "OP_PRINT"
        case .Pop:          outString += "OP_POP"
        case .GetGlobal:    outString += "OP_GETGLOBAL"
            printConstant("     ")
        case .DefineGlobal: outString += "OP_DEFINEGLOBAL"
            printConstant("  ")
        case .SetGlobal:    outString += "OP_SETGLOBAL"
            printConstant("     ")
        case .GetLocal:     outString += "OP_GETLOCAL"
            printByteInstruction("      ")
        case .SetLocal:     outString += "OP_SETLOCAL"
            printByteInstruction("      ")
            
        case .JumpIfFalse:  outString += "OP_JUMPIFFALSE"
            printShortInstruction("   ")
        case .Jump:         outString += "OP_JUMP"
            printShortInstruction("          ")
        case .Loop:         outString += "OP_LOOP"
            printShortInstruction("          ")
            
        case .Call:         outString += "OP_CALL"
            printByteInstruction("          ")
            
        case .Class:        outString += "OP_CLASS"
            printConstant("         ")
        case .GetProperty:  outString += "OP_GETPROPERTY"
            printConstant("")
        case .SetProperty:  outString += "OP_SETPROPERTY"
            printConstant("")
        case .Method:        outString += "OP_METHOD"
            printConstant("        ")
        case .NativeFunction:outString += "OP_NATIVEFUNCTION"
            //printConstant("        ")
        }

        return (outString, outOffset)
    }
    
    func debugConstants() {
        for (index, c) in constants.objects.enumerated() {
            print(index, c)
        }
    }
}
