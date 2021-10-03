//
//  Scanner.swift
//  
//
//  Created by Markus Moenig on 3/10/2564 BE.
//

import Foundation

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
    
    init(source: String) {
        self.source = source
        
        start = source.startIndex
        current = source.startIndex
    }
    
    public func scanTokens() -> [Token] {
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
                print(":")
                //error ( line , "Unexpected character." );
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
            //Lox . error ( line , "Unterminated string."
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
            // error invalid number
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
