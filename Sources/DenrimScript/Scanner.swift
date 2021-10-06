//
//  Scanner.swift
//  
//
//  Created by Markus Moenig on 3/10/2564 BE.
//

struct Scanner {
    private let source: String
    private var start: String.UnicodeScalarIndex
    private var current: String.UnicodeScalarIndex
    private var line: Int
    
    init(_ source: String) {
        self.source = source
        self.start = source.startIndex
        self.current = source.startIndex
        self.line = 1
    }
    
    private var isAtEnd: Bool {
        return current >= source.unicodeScalars.endIndex
    }
    
    private var peek: UnicodeScalar {
        if isAtEnd { return "\0" }
        return source.unicodeScalars[current]
    }
    
    private var peekNext: UnicodeScalar {
        let next = source.unicodeScalars.index(after: current)
        if next >= source.unicodeScalars.endIndex {
            return "\0"
        }
        
        return source.unicodeScalars[next]
    }
    
    var text: Substring { return source[start..<current] }
    
    @discardableResult private mutating func advance() -> UnicodeScalar {
        let result = source.unicodeScalars[current]
        current = source.unicodeScalars.index(after: current)
        return result
    }
    
    private mutating func match(_ expected: UnicodeScalar) -> Bool {
        if isAtEnd { return false }
        guard source.unicodeScalars[current] == expected else { return false }
        current = source.unicodeScalars.index(after: current)
        return true
    }
    
    private mutating func skipWhitespace() {
        while true {
            switch peek {
            case " ": fallthrough
            case "\r": fallthrough
            case "\t":
                advance()
                
            case "\n":
                line += 1
                advance()
                
            case "/" where peekNext == "/":
                while peek != "\n" && !isAtEnd { advance() }
                
            default: return
            }
        }
    }
    
    mutating func scanToken() -> Token {
        skipWhitespace()
        start = current
        
        if isAtEnd { return makeToken(.eof) }
        
        let c = advance()
        
        switch c {
        case "(": return makeToken(.leftParen)
        case ")": return makeToken(.rightParen)
        case "{": return makeToken(.leftBrace)
        case "}": return makeToken(.rightBrace)
        case ";": return makeToken(.semicolon)
        case ",": return makeToken(.comma)
        case ".": return makeToken(.dot)
        case "-": return makeToken(.minus)
        case "+": return makeToken(.plus)
        case "/": return makeToken(.slash)
        case "*": return makeToken(.star)

        case "!":
            return makeToken(match("=") ? .bangEqual : .bang)
        case "=":
            return makeToken(match("=") ? .equalEqual : .equal)
        case "<":
            return makeToken(match("=") ? .lessEqual : .less)
        case ">":
            return makeToken(match("=") ? .greaterEqual : .greater)
        
        case "\"": return string()
            
        case _ where c.isAlpha: return identifier()
        case _ where c.isDigit: return number()
            
        default: break
        }
        
        return errorToken("Unexpected character")
    }
    
    private mutating func string() -> Token {
        while peek != "\"" && !isAtEnd {
            if peek == "\n" { line += 1 }
            advance()
        }
        
        if isAtEnd { return errorToken("Unterminated string.") }
        
        // The closing ".
        advance()
        return makeToken(.string)
    }
    
    private mutating func number() -> Token {
        while peek.isDigit { advance() }
        
        // Look for a fractional part.
        if peek == "." && peekNext.isDigit {
            // Consume the "."
            advance()
            
            while peek.isDigit { advance() }
        }
        
        return makeToken(.number)
    }
    
    private mutating func identifier() -> Token {
        while peek.isAlpha || peek.isDigit { advance() }

        let keywords: [String: TokenType] = [
            "and": .and,
            "class": .Class,
            "else": .Else,
            "false": .False,
            "for": .For,
            "fun": .fn,
            "if": .If,
            "nil": .Nil,
            "or": .or,
            "print": .print,
            "return": .Return,
            "super": .Super,
            "this": .this,
            "true": .True,
            "var": .Var,
            "while": .While
        ]
        
        return makeToken(keywords[String(text)] ?? .identifier)
    }
    
    private func identifierType() -> TokenType {
        
        return .identifier
    }
    
    private func makeToken(_ type: TokenType) -> Token {
        return Token(type: type, text: String(text), line: line)
    }
    
    private func errorToken(_ message: Substring) -> Token {
        return Token(type: .error, text: String(message), line: line)
    }
}

private extension UnicodeScalar {
    var isDigit: Bool {
        return self >= "0" && self <= "9"
    }
    
    var isAlpha: Bool {
        return
            (self >= "a" && self <= "z")
                || (self >= "A" && self <= "Z")
                || (self == "_")
    }
}

/*
final class Scanner {
    
    static let keywords : [String: TokenType] = [
        "and" : .and,
        "class" : .Class,
        "else" : .Else,
        "false" : .False,
        "for" : .For,
        "fn" : .fn,
        "if" : .If,
        "nil" : .Nil,
        "or" : .or,
        "print" : .print,
        "return" : .Return,
        "super" : .Super,
        "this" : .this,
        "true" : .True,
        "var" : .Var,
        "while" : .While
    ]
    
    private let source              : String
    private var tokens              : [Token] = []
    
    private var start               : String.Index
    private var current             : String.Index
    
    private var line                : Int = 1
    
    private var errors              : Errors!
    
    init(source: String) {
        self.source = source
        
        start = source.startIndex
        current = source.startIndex
    }
    
    public func scanTokens(_ errors: Errors) -> [Token] {
        
        self.errors = errors
        
        while isAtEnd() == false {
            start = current
            scanToken()
        }
        
        tokens.append(Token(type: .eof, lexeme: "", line: line))
        
        return tokens
    }
    
    /// Search for a token
    private func scanToken() {
        let c = advance ()
        switch c {
        case "(":
            addToken(.leftParen)
        case ")":
            addToken(.rightParen)
        case "{":
            addToken(.leftBrace)
        case "}":
            addToken(.rightBrace)
        case ",":
            addToken(.comma)
        case ".":
            addToken(.dot)
        case "-":
            addToken(.minus)
        case "+":
            addToken(.plus)
        case ";":
            addToken(.semicolon)
        case "*":
            addToken(.star)
            
        case "!" where match("="):
            addToken(.bangEqual)
        case "!":
            addToken(.bang)
            
        case "=" where match("="):
            addToken(.equalEqual)
        case "=":
            addToken(.equal)

        case "<"  where match("="):
            addToken(.lessEqual)
        case "<":
            addToken(.less)
            
        case ">"  where match("="):
            addToken(.greaterEqual)
        case ">":
            addToken(.greater)
            
        case "/" where match("/"):
            // A comment goes until the end of the line.
            while peek() != "\n" && !isAtEnd() {
                _ = advance()
            }
        case "/":
            addToken(.slash)

        // Ignore whitespace.
        case " ", "\r", "\t":
        break

        case "\n":
            line += 1
            
        case "\"":
            string()

        default:
            if isDigit(c) {
                number()
            } else
            if isAlpha(c) {
                identifier()
            } else {
                errors.add(type: .error, line: line, message: "Unexpected character: \(c)")
            }
        }
    }
    
    /// Add a token
    private func addToken(_ type: TokenType) {
        addToken(type, nil)
    }
    
    /// Add a token
    private func addToken(_ type: TokenType,_ literal: Any?) {
        let text = String(source[start..<current])
        tokens.append(Token(type: type, lexeme: text, literal: literal, line: line))
    }

    /// Returns true if we reached the end of the source
    private func isAtEnd() -> Bool {
        return current == source.endIndex
    }
    
    /// Return current char and advance one char
    private func advance() -> Character {
        let c = source[current]
        current = source.index(after: current)
        return c
    }
    
    /// Advance only if the next char matches the expected char
    private func match(_ expected: Character) -> Bool {
        if isAtEnd() { return false }
        if source[current] != expected { return false }
        
        current = source.index(after: current)
        return true
    }
    
    /// consume
    private func peek() -> Character {
        if isAtEnd() { return "\0" }
        return source[current]
    }
    
    /// Consume a string
    private func string () {
        while peek() != "\"" && !isAtEnd() {
            
            if peek() == "\n" { line += 1 }
            
            _ = advance()
        }
            
        if isAtEnd() {
            errors.add(type: .error, line: line, message: "Unterminated string.")
            return
        }
        
        // The closing ".
        _ = advance()
        
        // Trim the surrounding quotes.
        let a = source.index(after: start)
        let b = source.index(before: current)
        let value = String(source[a ..< b])
        addToken(.string, value)
    }
    
    /// Tests if the string is a digit
    func isDigit(_ c: Character) -> Bool {
        if c.isASCII && c.isNumber { return true }
        return false
    }
    
    /// Tests if the string is alpha
    func isAlpha(_ c: Character) -> Bool {
        if c.isASCII && c.isLetter { return true }
        if c == "_" { return true }
        return false
    }
    
    /// Tests if the string is alphanumeric
    func isAlphaNumeric(_ c: Character) -> Bool {
        if isDigit(c) || isAlpha(c) { return true }
        return false
    }
    
    /// Consume a number
    private func number () {
        
        while isDigit(peek()) { _ = advance() }
        
        // Look for a fractional part.
        if peek() == "." && isDigit(peekNext()) {
            // Consume the "."
            _ = advance()
        }
        
        while isDigit(peek()) { _ = advance() }
        
        let text = String(source[start..<current])
        if let d = Double(text) {
            addToken(.number, d)
        } else {
            errors.add(type: .error, line: line, message: "Invalid number.")
        }
    }
    
    /// Double look ahead
    private func peekNext() -> Character {
        if current == source.endIndex { return "\0" }
        
        let n = source.index(after: current)
        if n == source.endIndex { return "\0" }

        return source[n]
    }
    
    /// Consume an identifier
    private func identifier() {
        
        while isAlphaNumeric(peek()) {
            _ = advance()
        }
        
        let text = String(source[start..<current])
        
        if let token = Scanner.keywords[text] {
            addToken(token)
        } else {
            addToken(.identifier)
        }
    }
}
*/
