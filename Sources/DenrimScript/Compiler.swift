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
    
    class Function {
        
        /// The enclosing function
        var enclosing       : Function? = nil
        
        /// The function object itself
        var function        : ObjectFunction
        
        /// Type
        var type            : ObjectFunction.ObjectFunctionType
        
        /// Variable stack
        var locals          : [Local] = []
        var scopeDepth      : Int = 0
        
        init(_ name: String = "",_ type: ObjectFunction.ObjectFunctionType = .script) {
            self.type = type
            function = ObjectFunction(name)
        }
    }
    
    class ClassCompiler {
        var enclosing   : ClassCompiler!
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
    
    var current             : Function! = nil
    var currentClass        : ClassCompiler! = nil
    
    var errors              : Errors!
    
    /// We are inside a metal shader function
    var insideMetalSh       : Bool = false
    
    /// We are inside a metal entry shader function
    var insideMetalShEntry  : Bool = false

    /// We are inside a metal compute shader function
    var insideMetalCompute  : Bool = false

    /// We are inside a metal fragment shader function
    var insideMetalFragment : Bool = false

    /// The metal code output
    var metalCode           = ""
    var metalLineNumber     = 0
    var metalIndent         = ""
    
    /// Compute functions
    var computeFunctions    : [String] = []
    
    /// Fragment functions
    var fragmentFunctions   : [String] = []
    
    /// Maps metal line nr to the incoming token line number
    var metalLineMap        : [Int: Int] = [:]
    
    init() {

        rules[.leftParen] = (grouping, call, .call)
        rules[.dot] = (nil, dot, .call)
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
        rules[.this] = (this, nil, .none)
    }
    
    deinit {
        clean()
    }
    
    func clean() {
        scanner = nil
        parser = nil
        current = nil
        currentClass = nil
    }
    
    func currentChunk() -> Chunk {
        return current.function.chunk
    }
    
    func compile(source: String, errors: Errors) -> ObjectFunction? {
        
        self.errors = errors
                
        scanner = Scanner(source)
        initFunction(.script)
        
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
        
        let function = endFunction()
        
        print(metalCode)
        
        if parser.hadError {
            return nil
        } else {
            return function
        }
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
    
    func parseVariable(_ errorMessage: String = "Expect variable name.", insideFnHeader: Bool = false, printType: Bool = false, headerArgOffset: Int = -1) -> OpCodeType {
        
        let name = parser.current.lexeme
        consume(.identifier, errorMessage)
        
        var metalTypeName = "float"
        let previous = parser.previous
        
        if match(.colon) {
            // Typed
            if match(.identifier) {
                if parser.previous.lexeme == "Tex2D" {
                    if insideMetalShEntry && insideFnHeader {
                        
                        var textureDesc = ""
                        
                        if insideMetalCompute {
                            textureDesc = "texture2d<float, access::read_write>"
                        } else
                        if insideMetalFragment {
                            textureDesc = "texture2d<float>"
                        }
                        
                        pushMetalCode("\(textureDesc) \(name) [[texture(\(String(headerArgOffset)))]], ", parser.current)
                    } else
                    if insideMetalSh {
                        pushMetalCode("texture2d<float, access::read_write> \(name), ", parser.current)
                    }
                } else
                if parser.previous.lexeme == "Number" {
                    if insideMetalShEntry && insideFnHeader {
                        pushMetalCode("constant float &\(name) [[buffer(\(String(headerArgOffset)))]], ", parser.current)
                    } else
                    if insideMetalSh && insideFnHeader {
                        pushMetalCode("float \(name)", parser.current)
                    }
                } else
                if parser.previous.lexeme == "N2" {
                    if insideMetalShEntry && insideFnHeader {
                        pushMetalCode("constant float2 &\(name) [[buffer(\(String(headerArgOffset)))]], ", parser.current)
                    } else
                    if insideMetalSh {
                        if insideFnHeader {
                            pushMetalCode("float2 \(name), ", parser.current)
                        }
                        metalTypeName = "float2"
                    }
                } else
                if parser.previous.lexeme == "N3" {
                    if insideMetalShEntry && insideFnHeader {
                        pushMetalCode("constant float3 &\(name) [[buffer(\(String(headerArgOffset)))]], ", parser.current)
                    } else
                    if insideMetalSh {
                        if insideFnHeader {
                            pushMetalCode("float3 \(name), ", parser.current)
                        }
                        metalTypeName = "float3"
                    }
                } else
                if parser.previous.lexeme == "N4" {
                    if insideMetalShEntry && insideFnHeader {
                        pushMetalCode("constant float4 &\(name) [[buffer(\(String(headerArgOffset)))]], ", parser.current)
                    } else
                    if insideMetalSh {
                        if insideFnHeader {
                            pushMetalCode("float4 \(name), ", parser.current)
                        }
                        metalTypeName = "float4"
                    }
                }
            }
        } else {
            if insideMetalShEntry && insideFnHeader {
                pushMetalCode("constant float &\(name) [[buffer(\(String(headerArgOffset)))]], ", parser.current)
            } else
            if insideMetalSh && insideFnHeader {
                pushMetalCode("float \(name), ", parser.current)
            }
        }
        
        if insideMetalSh && insideFnHeader == false {
            if printType {
                pushMetalCode(metalTypeName + " ", parser.current)
                pushMetalCode(name)
            }
        }
        
        parser.previous = previous
        declareVariable()
        /// Only continue when the variable is a global one (i.e. scopeDepth of 0)
        if current.scopeDepth > 0 { return 0 }
        return currentChunk().addConstant(.string(parser.previous.lexeme), writeOffset: false, line: parser.previous.line)
    }
    
    /// Adds a constant name to the chunk and return the offset
    func identifierConstant(_ name: String) -> OpCodeType {
        if insideMetalSh {
            pushMetalCode(name, parser.previous)
        }
        return currentChunk().addConstant(.string(name), writeOffset: false, line: parser.previous.line)
    }
    
    func declaration() {
        if match(.Class) {
            classDeclaration()
        } else
        if match(.fn) {
            fnDeclaration()
        } else
        if match(.sh) {
            insideMetalSh = true
            insideMetalShEntry = false
            fnDeclaration()
            insideMetalSh = false
            insideMetalShEntry = false
        } else
        if match(.compute) {
            insideMetalSh = true
            insideMetalShEntry = true
            insideMetalCompute = true
            fnDeclaration()
            insideMetalSh = false
            insideMetalShEntry = false
            insideMetalCompute = false
        } else
        if match(.fragment) {
            insideMetalSh = true
            insideMetalShEntry = true
            insideMetalFragment = true
            fnDeclaration()
            insideMetalSh = false
            insideMetalShEntry = false
            insideMetalFragment = false
        } else
        if match(.Var) {
            varDeclaration()
        } else {
            statement()
        }
        if parser.panicMode {
            syncronize()
        }
    }
    
    func fnDeclaration() {
        let global = parseVariable("Expect function name.")
        
        if insideMetalCompute {
            pushMetalCode("kernel void ")
        } else
        if insideMetalFragment {
            pushMetalCode("fragment float4 ")
        } else
        if insideMetalSh {
            pushMetalCode("_RC_PH_ ")
        }
        
        markInitialized()
        function(.function)
        defineVariable(global)
    }
    
    func varDeclaration() {
        let global = parseVariable("Expect variable name.", printType: true)
        
        if match(.equal) {
            if insideMetalSh {
                pushMetalCode(" = ", parser.previous)
            }
            expression()
        } else {
            emitByte(OpCode.Nil.rawValue)
        }
        
        consume(.semicolon, "Expect ';' after variable declaration.")
        if insideMetalSh {
            pushMetalCode(";\n", parser.previous, lineFeed: 1)
        }
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
        if match(.Return) {
            returnStatement()
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
        if insideMetalSh {
            pushMetalCode(";\n", parser.previous, lineFeed: 1)
        }
    }
    
    func expression() {
        parse(precedence: .assignment)
    }
    
    func block(metalInit: String = "") {
        if insideMetalSh {
            pushMetalCode("{\(metalInit)\n", parser.previous, lineFeed: 1)
            metalIndent += "    "
        }
        while !check(.rightBrace) && !check(.eof) {
            declaration()
        }
        
        consume(.rightBrace, "Expect '}' after block.")
        if insideMetalSh {
            pushMetalCode("}\n\n", parser.previous, lineFeed: 2)
            metalIndent = String(metalIndent.dropLast(4))
        }
    }
    
    func grouping(_ canAssign: Bool) {
        if insideMetalSh {
            pushMetalCode("( ", parser.previous)
        }
        expression()
        if insideMetalSh {
            pushMetalCode(" )", parser.previous)
        }
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
          
        if insideMetalSh {
            if opType == .minus {
                pushMetalCode("-", parser.previous)
            } else
            if opType == .bang {
                pushMetalCode("!", parser.previous)
            }
        }
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
        
        if insideMetalSh {
            pushMetalCode(" " + parser.previous.lexeme + " ", parser.previous)
        }
          
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
    
    /// Consume the token if it is of the right value and advance, otherwise error out
    func consume(_ type: TokenType , _ message: String) {
        guard parser.current.type == type else {
            errorAtCurrent(message)
            return
        }

        advance()
    }
    
    /// Advance one token
    func advance() {
        parser.previous = parser.current
        
        while true {
            parser.current = scanner.scanToken()
            if parser.current.type != .error { break }
            
            errorAtCurrent(String(parser.current.lexeme))
        }
    }
    
    /// Advance if match
    func match(_ type: TokenType) -> Bool {
        if check(type) == false { return false }
        advance()
        return true
    }
    
    /// Check current token type
    func check(_ type: TokenType) -> Bool {
        return parser.current.type == type
    }
    
    func number(_ canAssign: Bool) {
        let v = Object.number(Double(parser.previous.lexeme)!)
        if insideMetalSh {
            pushMetalCode(parser.previous.lexeme, parser.previous)
        }
        emitConstant(v)
    }
    
    func string(_ canAssign: Bool) {
        let str = String(parser.previous.lexeme.dropFirst().dropLast())
        emitConstant(.string(str))
    }
    
    func variable(_ canAssign: Bool) {
        if insideMetalSh {
            
            // Map types to metal types
            var metalName = parser.previous.lexeme
            if metalName == "N4" { metalName = "float4" }
            else
            if metalName == "N3" { metalName = "float3" }
            else
            if metalName == "N2" { metalName = "float2" }
            else
            if metalName == "Number" { metalName = "float" }
            pushMetalCode(metalName, parser.previous)
        }
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
        currentChunk().write(byte, line: parser.previous.line)
    }
    
    func emitBytes(_ b1: OpCodeType, _ b2: OpCodeType) {
        emitByte(b1)
        emitByte(b2)
    }
    
    func emitConstant(_ v: Object) {
        emitByte(OpCode.Constant.rawValue)
        currentChunk().addConstant(v, line: parser.previous.line)
    }
    
    func emitReturn() {
        
        if current.type == .initializer {
            emitBytes(OpCode.GetLocal.rawValue, 0)
        } else {
            emitByte(OpCode.Nil.rawValue)
        }
  
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

        errors.add(token: token, message: message)
        
        parser.hadError = true
    }
    
    /// Push metal code
    func pushMetalCode(_ code: String,_ token: Token? = nil, lineFeed: Int = 0) {
        metalCode += code
        if let token = token {
            metalLineMap[metalLineNumber] = token.line
        }
        metalLineNumber += lineFeed
        if lineFeed > 0 {
            metalCode += metalIndent
        }
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
            off = currentChunk().addConstant(.string(token.lexeme), writeOffset: false, line: parser.previous.line)
            getOp = OpCode.GetGlobal.rawValue
            setOp = OpCode.SetGlobal.rawValue
        }
        
        if canAssign && match(.equal) {
            if insideMetalSh {
                pushMetalCode(" = ", token)
            }
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
        if current.scopeDepth == 0 { return }
        current.locals[current.locals.count - 1].depth = current.scopeDepth
    }
    
    /// Get the offset of the local variable
    func resolveLocal(locals: Function,_ name: String) -> Int {
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
        if insideMetalSh {
            pushMetalCode("if (")
        }
        expression()
        consume(.rightParen, "Expect ')' after condition.")
        if insideMetalSh {
            pushMetalCode(")")
        }
        
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
        let loopStart = currentChunk().count
        
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
                
        var loopStart = currentChunk().count
        
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
            let incrementStart = currentChunk().count
            
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
        
        return currentChunk().count - 2
    }
    
    /// Patches the previous jump statement for the given offset
    func patchJump(_ offset: Int) {
        let jump = currentChunk().count - offset - 2
        
        if jump > UInt16.max {
            error("Too much code to jump over.")
        }
        
        currentChunk().code[offset] = OpCodeType((jump >> 8) & 0xff)
        currentChunk().code[offset + 1] = OpCodeType(jump & 0xff)
    }
    
    func emitLoop(_ loopStart: Int) {
        emitByte(OpCode.Loop.rawValue)
        
        let offset = currentChunk().count - loopStart + 2
        
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

/// Everything function related
extension Compiler {
    
    func function(_ type: ObjectFunction.ObjectFunctionType) {
        
        initFunction(type)
        
        beginScope()
        consume(.leftParen, "Expect '(' after function name.")
        if insideMetalSh {
            pushMetalCode("(")
        }
        
        if insideMetalFragment {
            pushMetalCode("__Vertex in [[stage_in]],")
        }
        
        var headerArgOffset : Int = 0
        if !check(.rightParen) {
            repeat {
                current.function.arity += 1
                if current.function.arity > 255 {
                    errorAtCurrent("Can't have more than 255 parameters.")
                }
                let constant = parseVariable( "Expect parameter name.", insideFnHeader: true, headerArgOffset: headerArgOffset)
                defineVariable(constant)
                headerArgOffset += 1
            } while match(.comma)
        }
        
        consume(.rightParen, "Expect ')' after parameters.")
        
        if match(.colon) {
            // Typed
            if match(.identifier) {
                if parser.previous.lexeme == "Tex2D" {
                } else
                if parser.previous.lexeme == "Number" {
                    metalCode = metalCode.replacingOccurrences(of: "_RC_PH_", with: "float")
                } else
                if parser.previous.lexeme == "N2" {
                    metalCode = metalCode.replacingOccurrences(of: "_RC_PH_", with: "float2")
                } else
                if parser.previous.lexeme == "N3" {
                    metalCode = metalCode.replacingOccurrences(of: "_RC_PH_", with: "float3")
                } else
                if parser.previous.lexeme == "N4" {
                    metalCode = metalCode.replacingOccurrences(of: "_RC_PH_", with: "float4")
                }
            }
        } else {
            metalCode = metalCode.replacingOccurrences(of: "_RC_PH_", with: "void")
        }
        
        consume(.leftBrace, "Expect '{' before function body.")
        
        var metalInit = ""
        
        if insideMetalCompute {
            pushMetalCode("uint2 gid [[thread_position_in_grid]])")
        } else
        if insideMetalFragment {
            metalCode = String(metalCode.dropLast(2))
            pushMetalCode(")")
            metalInit = "float2 uv = in.uv; constexpr sampler linearSampler (mag_filter::linear, min_filter::linear);"
        } else
        if insideMetalSh {
            metalCode = String(metalCode.dropLast(2))
            pushMetalCode(")")
        }
        
        block(metalInit: metalInit)
        
        let function = endFunction()
        emitByte(OpCode.Constant.rawValue)
        currentChunk().addConstant(.function(function), line: parser.previous.line)
    }
    
    /// Initialize a new function
    func initFunction(_ type: ObjectFunction.ObjectFunctionType) {
        
        var name = ""
        if type != .script {
            name = parser.previous.lexeme
        }
        
        if insideMetalSh {
            pushMetalCode(name, parser.previous)
            if insideMetalCompute {
                computeFunctions.append(name)
            } else
            if insideMetalFragment {
                fragmentFunctions.append(name)
            }
        }
        
        let function = Function(name, type)
        function.enclosing = current
        
        /// If we are inside an sh entry definition mark the function
        if insideMetalShEntry {
            function.function.isShEntry = true
        }
        
        current = function
        
        let local = Local(name: type != .function ? "this" : "", depth: 0)
        current.locals.append(local)
    }
    
    /// End the current function
    func endFunction() -> ObjectFunction {
        emitReturn()
        
        let function = current.function
        #if DEBUG
        if !parser.hadError {
            //print(currentChunk().disassemble(name: "code"), function.name == "" ? "<script>" : function.name)
        }
        #endif
        
        current = current.enclosing
        return function
    }
    
    /// Function call
    func call(_ canAssign: Bool) {
        
        if insideMetalSh {
            pushMetalCode("(")
        }
        
        let argCount = argumentList()
        emitBytes(OpCode.Call.rawValue, argCount)
        
        if insideMetalSh {
            pushMetalCode(")")
        }
    }
    
    /// Scan the argument list of a function
    func argumentList() -> OpCodeType {
        var argCount : OpCodeType = 0
    
        if !check(.rightParen) {
            var firstArg = true
            repeat {
                if !firstArg && insideMetalSh {
                    pushMetalCode(", ")
                }
                expression()
                if argCount == 255 {
                    error ( "Can't have more than 255 arguments." )
                }
                argCount += 1
                firstArg = false
            } while match(.comma)
        }
        consume(.rightParen , "Expect ')' after arguments." )
        return argCount
    }
    
    /// Return statement
    func returnStatement() {
        if current.type == .script {
            error("Can't return from top-level code.")
        }

        if match(.semicolon) {
            emitReturn()
            if insideMetalSh {
                pushMetalCode("return;")
            }
        } else {
            
            if insideMetalSh {
                pushMetalCode("return ")
            }
            
            if current.type == .initializer {
                error("Can't return a value from an initializer.")
            }
            
            expression()
            pushMetalCode(";\n", lineFeed: 1)
            consume(.semicolon, "Expect ';' after return value.")
            emitByte(OpCode.Return.rawValue)
        }
    }
}

/// Everything class related
extension Compiler {
    
    func classDeclaration() {
        consume(.identifier, "Expect class name." )
        let className = parser.previous
        let nameConstant = identifierConstant(parser.previous.lexeme)
        
        declareVariable()
        emitBytes(OpCode.Class.rawValue, nameConstant)
        defineVariable(nameConstant)
        
        // Init the currentClass variable so that we can track the outermost class
        let classCompiler = ClassCompiler()
        classCompiler.enclosing = currentClass
        currentClass = classCompiler
        
        namedVariable(className, false)
        
        consume(.leftBrace, "Expect '{' before class body." )
        
        while !check(.rightBrace) && !check(.eof) {
            method()
        }
        
        consume(.rightBrace, "Expect '}' after class body." )
        emitByte(OpCode.Pop.rawValue)
        
        currentClass = currentClass.enclosing
    }
    
    func method() {
        consume(.identifier, "Expect method name.")
        let constant = identifierConstant(parser.previous.lexeme)
                
        var type : ObjectFunction.ObjectFunctionType = .method
        
        if parser.previous.lexeme == "init" {
            type = .initializer
        }
        
        function(type)
        emitBytes(OpCode.Method.rawValue, constant)
    }
    
    func dot(_ canAssign: Bool) {
        consume(.identifier, "Expect property name after '.'." )
        
        if insideMetalSh {
            pushMetalCode(".")
        }
        
        let name = identifierConstant(parser.previous.lexeme)
        
        if canAssign && match(.equal) {
            if insideMetalSh {
                pushMetalCode(" = ", parser.previous)
            }
            expression()
            emitBytes(OpCode.SetProperty.rawValue, name)
        } else {
            emitBytes(OpCode.GetProperty.rawValue, name)
        }
    }
    
    func this(_ canAssign: Bool) {
        
        if currentClass == nil {
            error("Can't use 'this' outside of a class.")
            return
        }

        variable(false)
    }
}
