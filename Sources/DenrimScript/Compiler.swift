//
//  Compiler.swift
//  
//
//  Created by Markus Moenig on 6/10/2564 BE.
//

class Compiler {
    
    struct Parser {
        var previous        : Token
        var current         : Token
        var hadError        : Bool
        var panicMode       : Bool
    }
    
    enum Precedence: Int {
        case none
        case assignment  // =
        case or          // or
        case and         // and
        case equality    // == !=
        case comparison  // < > <= >=
        case term        // + -
        case factor      // * /
        case unary       // ! - +
        case call        // . () []
        case primary
        
        var higher: Precedence {
            return Precedence(rawValue: self.rawValue + 1)!
        }
    }
    
    typealias ParseFn = () -> ()
    typealias ParseRule = (prefix: ParseFn?, infix: ParseFn?, precedence: Precedence)
    var rules: [TokenType: ParseRule] = [:]
    
    var parser              : Parser!
    var scanner             : Scanner!
    
    var compilingChunk      : Chunk!
    var currentChunk        : Chunk!

    init() {
        rules[.leftParen] = (grouping, nil, .call)
        rules[.dot] = (nil, nil, .call)
        rules[.minus] = (unary, binary, .term)
        rules[.plus] = (nil, binary, .term)
        rules[.slash] = (nil, binary, .factor)
        rules[.star] = (nil, binary, .factor)
        rules[.bang] = (unary, nil, .none)
        rules[.bangEqual] = (nil, binary, .equality)
        rules[.equalEqual] = (nil, binary, .equality)
        rules[.greater] = (nil, binary, .comparison)
        rules[.greaterEqual] = (nil, binary, .comparison)
        rules[.less] = (nil, binary, .comparison)
        rules[.lessEqual] = (nil, binary, .comparison)
        //rules[.string] = (string, nil, .none)
        rules[.number] = (number, nil, .none)
        rules[.and] = (nil, nil, .and)
        rules[.or] = (nil, nil, .or)
        rules[.True] = ({ self.emitByte(OpCode.True.rawValue) }, nil, .none)
        rules[.False] = ({ self.emitByte(OpCode.False.rawValue) }, nil, .none)
        rules[.Nil] = ({ self.emitByte(OpCode.Nil.rawValue) }, nil, .none)
    }
    
    func compile(source: String, chunk: inout Chunk) -> Bool {
        
        scanner = Scanner(source)
        
        currentChunk = chunk
        compilingChunk = chunk

        parser = Parser(
            previous: Token(type: .eof, text: String(source.prefix(upTo: source.startIndex)), line: -1),
            current: scanner.scanToken(),
            hadError: false,
            panicMode: false
        )
        
        expression()
        consume(.eof, "Expect end of expression.")
        endCompiler()
                
        guard !parser.hadError else { return false }
        
        return true
    }
    
    func getRule(_ type: TokenType) -> ParseRule {
        return rules[type] ?? (nil, nil, .none)
    }
    
    func parse(precedence: Precedence) {
        advance()
        guard let prefixRule = getRule(parser.previous.type).prefix else {
            error("Expect expression.")
            return
        }
        
        prefixRule()
        
        while precedence.rawValue <= getRule(parser.current.type).precedence.rawValue {
            advance()
            if let infixRule = getRule(parser.previous.type).infix {
                infixRule()
            }
        }
    }
    
    func expression() {
        parse(precedence: .assignment)
    }
    
    func grouping() {
        expression()
        consume(.rightParen, "Expect ')' after expression.")
    }
      
    func unary() {
        let opType = parser.previous.type
          
        // Compile the operand.
        parse(precedence: .assignment)
          
        // Emit the operator instruction.
        switch opType {
        case .minus: emitByte(OpCode.Negate.rawValue)
        case .bang: emitByte(OpCode.Not.rawValue)
        default:
            return
        }
    }
    
    func binary() {
        // Remember the operator.
        let opType = parser.previous.type
          
        // Compile the right operand.
        let rule = getRule(opType)
        parse(precedence: rule.precedence.higher)
        
        print(rule)
        
        // Emit the operator instruction.
        switch opType {
        case .bangEqual:    emitBytes(OpCode.Equal.rawValue, OpCode.Not.rawValue)
        case .equalEqual:   emitByte(OpCode.Equal.rawValue)
        case .greater:      emitByte(OpCode.Greater.rawValue)
        case .greaterEqual: emitBytes(OpCode.Less.rawValue, OpCode.Not.rawValue)
        case .less:         emitByte(OpCode.Less.rawValue)
        case .lessEqual:    emitBytes(OpCode.Greater.rawValue, OpCode.Not.rawValue)
        case .plus:         emitByte(OpCode.Add.rawValue)
        case .minus:        emitByte(OpCode.Subtract.rawValue)
        case .star:         emitByte(OpCode.Multiply.rawValue)
        case .slash:        emitByte(OpCode.Divide.rawValue)
        default:
            return
        }
    }
    
    func consume(_ type: TokenType , _ message: String) {
        guard parser.current.type == type else {
            errorAtCurrent(message)
            return
        }

        advance()
    }
    
    func advance() {
        parser.previous = parser.current
        
        while true {
            parser.current = scanner.scanToken()
            if parser.current.type != .error { break }
            
            errorAtCurrent(String(parser.current.lexeme))
        }
    }
    
    func number() {
        let v = Double(parser.previous.lexeme)!
        emitConstant(v)
    }
    
    func endCompiler() {
        emitReturn()
        #if DEBUG
        if !parser.hadError {
            print(currentChunk.disassemble(name: "code"))
        }
        #endif
    }
    
    func emitByte(_ byte: OpCodeType) {
        currentChunk.write(byte, line: parser.previous.line)
    }
    
    func emitBytes(_ b1: OpCodeType, _ b2: OpCodeType) {
        emitByte(b1)
        emitByte(b2)
    }
    
    func emitConstant(_ v: Value) {
        currentChunk.addConstant(v, line: parser.previous.line)
    }
    
    func emitReturn() {
        emitByte(OpCode.Return.rawValue)
    }
    
    func error(_ message: String) {
        errorAt(parser.previous, message)
    }
    
    func errorAtCurrent(_ message: String) {
        errorAt(parser.current, message)
    }
    
    func errorAt(_ token: Token, _ message: String) {
        guard !parser.panicMode else { return }
        parser.panicMode = true
        
        print("[line \(token.line)] Error")
    
        switch token.type {
        case .eof:
            print(" at end")
        case .error:
            // Nothing.
            break
        default:
            print(" at '\(token.lexeme)'")
        }
        
        print(": \(message)\n")
        parser.hadError = true
    }
}
