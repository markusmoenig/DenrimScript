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
    
    typealias ParseFn = (_ canAssign: Bool) -> ()
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
        rules[.string] = (string, nil, .none)
        rules[.number] = (number, nil, .none)
        rules[.and] = (nil, nil, .and)
        rules[.or] = (nil, nil, .or)
        rules[.True] = (literal, nil, .none)
        rules[.False] = (literal, nil, .none)
        rules[.Nil] = (literal, nil, .none)
        rules[.print] = (nil, nil, .none)
        rules[.identifier] = (variable, nil, .none)
    }
    
    func compile(source: String, chunk: inout Chunk) -> Bool {
        
        scanner = Scanner(source)
        
        currentChunk = chunk
        compilingChunk = chunk

        parser = Parser(
            previous: Token(type: .eof, text: "", line: -1),
            current: Token(type: .eof, text: "", line: -1),
            hadError: false,
            panicMode: false
        )

        advance()
        while match(.eof) == false {
            declaration()
        }
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
        
        let canAssign = precedence.rawValue <= Precedence.assignment.rawValue
        prefixRule(canAssign)
        
        while precedence.rawValue <= getRule(parser.current.type).precedence.rawValue {
            advance()
            if let infixRule = getRule(parser.previous.type).infix {
                infixRule(canAssign)
            }
            if canAssign && match(.equal) {
                error("Invalid assignment target.")
            }
        }
    }
    
    func parseVariable(_ errorMessage: String = "Expect variable name.") -> OpCodeType {
        consume(.identifier, errorMessage)
        return currentChunk.addConstant(.string(parser.previous.lexeme), writeOffset: false, line: parser.previous.line)
    }
    
    func defineVariable(_ string: String) {
        emitByte(OpCode.DefineGlobal.rawValue)
    }
    
    func declaration() {
        if match(.Var) {
            varDeclaration()
        } else {
            statement()
        }
        if parser.panicMode {
            syncronize()
        }
    }
    
    func varDeclaration() {
        let global = parseVariable()
        
        if match(.equal) {
            expression()
        } else {
            emitByte(OpCode.Nil.rawValue)
        }
        
        consume(.semicolon, "Expect ';' after variable declaration.")
        emitBytes(OpCode.DefineGlobal.rawValue, global)
    }
    
    func statement() {
        if match(.print) {
            printStatement()
        } else {
            expressionStatement()
        }
    }
    
    func printStatement() {
        expression()
        consume(.semicolon, "Expect ';' after value.")
        emitByte(OpCode.Print.rawValue)
    }
    
    func expressionStatement() {
        expression()
        consume(.semicolon, "Expect ';' after value.")
        emitByte(OpCode.Pop.rawValue)
    }
    
    func expression() {
        parse(precedence: .assignment)
    }
    
    func grouping(_ canAssign: Bool) {
        expression()
        consume(.rightParen, "Expect ')' after expression.")
    }
    
    func literal(_ canAssign: Bool) {
        switch parser.previous.type {
        case .False: emitByte(OpCode.False.rawValue)
        case .Nil: emitByte(OpCode.Nil.rawValue)
        case .True: emitByte(OpCode.True.rawValue)
        default:
            return
        }
    }
      
    func unary(_ canAssign: Bool) {
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
    
    func binary(_ canAssign: Bool) {
        // Remember the operator.
        let opType = parser.previous.type
          
        // Compile the right operand.
        let rule = getRule(opType)
        parse(precedence: rule.precedence.higher)
                
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
    
    func match(_ type: TokenType) -> Bool {
        if check(type) == false { return false }
        advance()
        return true
    }
    
    func check(_ type: TokenType) -> Bool {
        return parser.current.type == type
    }
    
    func number(_ canAssign: Bool) {
        let v = Value.number(Double(parser.previous.lexeme)!)
        emitConstant(v)
    }
    
    func string(_ canAssign: Bool) {
        let str = String(parser.previous.lexeme.dropFirst().dropLast())
        emitConstant(.string(str))
    }
    
    func variable(_ canAssign: Bool) {
        namedVariable(parser.previous, canAssign)
    }
    
    func namedVariable(_ token: Token,_ canAssign: Bool) {
        let off = currentChunk.addConstant(.string(token.lexeme), writeOffset: false, line: parser.previous.line)
        
        if canAssign && match(.equal) {
            expression()
            emitBytes(OpCode.SetGlobal.rawValue, off)
        } else {
            emitBytes(OpCode.GetGlobal.rawValue, off)
        }
    }
    
    /// Sync to the next statement
    func syncronize() {
        parser.panicMode = false
        
        while parser.current.type != .eof {
            if parser.previous.type == .semicolon { return }
            
            switch parser.current.type {
            case .Class: return
            case .fn: return
            case .Var: return
            case .For: return
            case .If: return
            case .While: return
            case .print: return
            case .Return: return
                
            default: break
            }
            
            advance()
        }
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
        emitByte(OpCode.Constant.rawValue)
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
