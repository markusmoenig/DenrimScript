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
    
    struct Local {
        var name            : String
        var depth           : Int
    }
    
    struct Locals {
        var locals          : [Local] = []
        var scopeDepth      : Int = 0
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

    var current             = Locals()
    
    var errors              : Errors!
    
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
        rules[.and] = (nil, and_, .and)
        rules[.or] = (nil, or_, .or)
        rules[.True] = (literal, nil, .none)
        rules[.False] = (literal, nil, .none)
        rules[.Nil] = (literal, nil, .none)
        rules[.print] = (nil, nil, .none)
        rules[.identifier] = (variable, nil, .none)
    }
    
    func compile(source: String, chunk: inout Chunk, errors: Errors) -> Bool {
        
        self.errors = errors
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
        declareVariable()
        /// Only continue when the variable is a global one (i.e. scopeDepth of 0)
        if current.scopeDepth > 0 { return 0 }
        return currentChunk.addConstant(.string(parser.previous.lexeme), writeOffset: false, line: parser.previous.line)
    }
    
    /// Adds a constant name to the chunk and return the offset
    func identifierConstant(_ name: String) -> OpCodeType {
        return currentChunk.addConstant(.string(name), writeOffset: false, line: parser.previous.line)
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
        let global = parseVariable("Expect variable name.")
        
        if match(.equal) {
            expression()
        } else {
            emitByte(OpCode.Nil.rawValue)
        }
        
        consume(.semicolon, "Expect ';' after variable declaration.")
        defineVariable(global)
    }
    
    func statement() {
        if match(.print) {
            printStatement()
        } else
        if match(.For) {
            forStatement()
        } else
        if match(.If) {
            ifStatement()
        } else
        if match(.While) {
            whileStatement()
        } else
        if match(.leftBrace) {
            beginScope()
            block()
            endScope()
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
    
    func block() {
        while !check(.rightBrace) && !check(.eof) {
            declaration()
        }
        
        consume(.rightBrace, "Expect '}' after block.")
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
    
    func beginScope() {
        current.scopeDepth += 1
    }
    
    func endScope() {
        current.scopeDepth -= 1
        // Remove local variables of this scope
        while current.locals.count > 0 && current.locals.last!.depth > current.scopeDepth {
            emitByte(OpCode.Pop.rawValue)
            current.locals.removeLast()
        }
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
        
        /*
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
        */
        errors.add(token: token, message: message)
        
        parser.hadError = true
    }
}

/// Everything variable related.
extension Compiler {
    
    /// The main entry point after encounting a var instruction
    func namedVariable(_ token: Token,_ canAssign: Bool) {
        
        var getOp : OpCodeType
        var setOp : OpCodeType

        var off : OpCodeType
        
        let arg = resolveLocal(locals: current, token.lexeme)
        if arg != -1 {
            getOp = OpCode.GetLocal.rawValue
            setOp = OpCode.SetLocal.rawValue
            off = OpCodeType(arg)
        } else {
            off = currentChunk.addConstant(.string(token.lexeme), writeOffset: false, line: parser.previous.line)
            getOp = OpCode.GetGlobal.rawValue
            setOp = OpCode.SetGlobal.rawValue
        }
        
        if canAssign && match(.equal) {
            expression()
            emitBytes(setOp, off)
        } else {
            emitBytes(getOp, off)
        }
    }
    
    /// Add a local variable if scopeDepth > 0
    func declareVariable() {
        if current.scopeDepth == 0 { return }
        let name = parser.previous.lexeme
                
        // Check if another variable with the same name exists in the current scope
        var i = current.locals.count - 1
        while i >= 0 {
            let local = current.locals[i]
            if local.depth != -1 && local.depth < current.scopeDepth {
                break
            }
            if name == local.name {
                error("Already a variable with this name in this scope.")
            }
            i -= 1
        }
        addLocal(name)
    }

    
    func defineVariable(_ global: OpCodeType) {
        if current.scopeDepth > 0 {
            markInitialized()
            return
        }
        emitBytes(OpCode.DefineGlobal.rawValue, global)
    }
    
    func markInitialized() {
        current.locals[current.locals.count - 1].depth = current.scopeDepth
    }
    
    /// Get the offset of the local variable
    func resolveLocal(locals: Locals,_ name: String) -> Int {
        var i = current.locals.count - 1
        while i >= 0 {
            let local = current.locals[i]
            if name == local.name {
                if local.depth == -1 {
                    error("Can't resolve local variable in its own initializer.")
                }
                return i
            }
            i -= 1
        }
        return -1
    }
    
    /// Add it
    func addLocal(_ name: String) {
        current.locals.append(Local(name: name, depth: -1))
    }
}

/// Everything control flow related
extension Compiler {
    
    /// Entry point for if statements
    func ifStatement() {
        consume(.leftParen, "Expect '(' after if.")
        expression()
        consume(.rightParen, "Expect ')' after condition.")
        
        let thenJump = emitJump(.JumpIfFalse)
        emitByte(OpCode.Pop.rawValue)
        statement()
        
        let elseJump = emitJump(.Jump)
        patchJump(thenJump)
        emitByte(OpCode.Pop.rawValue)

        if match(.Else) {
            statement()
        }
        patchJump(elseJump)
    }
    
    /// Entry point for while statement
    func whileStatement() {
        let loopStart = currentChunk.count
        
        consume(.leftParen, "Expect '(' after while.")
        expression()
        consume(.rightParen, "Expect ')' after condition.")
        
        let exitJump = emitJump(.JumpIfFalse)
        emitByte(OpCode.Pop.rawValue)
        statement()
        
        emitLoop(loopStart)
        
        patchJump(exitJump)
        emitByte(OpCode.Pop.rawValue)
    }
    
    /// Entry point for a for statement
    func forStatement() {
        beginScope()
        consume(.leftParen, "Expect '(' after for.")
        
        // Initializer
        if match(.semicolon) {
            // No initializer.
        } else
        if match(.Var) {
            varDeclaration()
        } else {
            expressionStatement()
        }
                
        var loopStart = currentChunk.count
        
        // Condition
        var exitJump = -1
        if !match(.semicolon) {
            expression()
            consume(.semicolon, "Expect ';' after loop condition.")
            // Jump out of the loop if the condition is false
            exitJump = emitJump(.JumpIfFalse)
            emitByte(OpCode.Pop.rawValue)
        }
                
        // Increment
        if !match(.rightParen) {
            let bodyJump = emitJump(OpCode.Jump)
            let incrementStart = currentChunk.count
            
            expression()
            emitByte(OpCode.Pop.rawValue)
        
            consume(.rightParen, "Expect ')' after for clauses.")
            
            emitLoop(loopStart)
            loopStart = incrementStart
            patchJump(bodyJump)
        }

        statement()
        emitLoop(loopStart)
        
        if exitJump != -1 {
            patchJump(exitJump)
            emitByte(OpCode.Pop.rawValue)
        }
        
        endScope()
    }
    
    /// Insert a jump instruction with a placeholder offset
    func emitJump(_ code: OpCode) -> Int {
        emitByte(code.rawValue)
        emitByte(0xff)
        emitByte(0xff)
        
        return currentChunk.count - 2
    }
    
    /// Patches the previous jump statement for the given offset
    func patchJump(_ offset: Int) {
        let jump = currentChunk.count - offset - 2
        
        if jump > UInt16.max {
            error("Too much code to jump over.")
        }
        
        currentChunk.code[offset] = OpCodeType((jump >> 8) & 0xff)
        currentChunk.code[offset + 1] = OpCodeType(jump & 0xff)
    }
    
    func emitLoop(_ loopStart: Int) {
        emitByte(OpCode.Loop.rawValue)
        
        let offset = currentChunk.count - loopStart + 2
        
        if offset > UInt16.max {
            error("Loop body too large.")
        }
        
        emitByte(OpCodeType((offset >> 8) & 0xff))
        emitByte(OpCodeType(offset & 0xff))
    }
    
    /// Handles logical and
    func and_(_ canAssign: Bool) {
        let endJump = emitJump(.JumpIfFalse)
        
        emitByte(OpCode.Pop.rawValue)
        parse(precedence: .and)
        
        patchJump(endJump)
    }
    
    /// Handles logical or
    func or_(_ canAssign: Bool) {
        let elseJump = emitJump(.JumpIfFalse)
        let endJump = emitJump(.Jump)

        patchJump(elseJump)
        emitByte(OpCode.Pop.rawValue)
        parse(precedence: .or)
        
        patchJump(endJump)
    }
}
