//
//  Scanner.swift
//  
//
//  Created by Markus Moenig on 3/10/2564 BE.
//

import Foundation

// https://stackoverflow.com/questions/24092884/get-nth-character-of-a-string-in-swift-programming-language
extension String {
    var length: Int {
        return count
    }
    subscript (i: Int) -> String {
        return self[i ..< i + 1]
    }
    func substring(fromIndex: Int) -> String {
        return self[min(fromIndex, length) ..< length]
    }
    func substring(toIndex: Int) -> String {
        return self[0 ..< max(0, toIndex)]
    }
    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[start ..< end])
    }
}

class Scanner {
    
    let source              : String
    var tokens              : [Token] = []
    
    var start               : Int = 0
    var current             : Int = 0
    
    var line                : Int = 1
    
    init(source: String) {
        self.source = source
    }
    
    public func scanTokens() -> [Token] {
        while isAtEnd() == false {
            start = current
            //scanToken()
        }
        
        tokens.append(Token(type: .EOF, lexeme: "", line: line))
        
        return tokens
    }
    
    /// Search for a token
    private func scanToken() {
        let c = advance ()
        switch ( c ) {
        case "(" : addToken ( TokenType.LEFT_PAREN ); break
        case ")" : addToken ( TokenType.RIGHT_PAREN ); break
        case "{" : addToken ( TokenType.LEFT_BRACE ); break
        case "}" : addToken ( TokenType.RIGHT_BRACE ); break
        case "," : addToken ( TokenType.COMMA ); break
        case "." : addToken ( TokenType.DOT ); break
        case "-" : addToken ( TokenType.MINUS ); break
        case "+" : addToken ( TokenType.PLUS ); break
        case ";" : addToken ( TokenType.SEMICOLON ); break
        case "*" : addToken ( TokenType.STAR ); break
        case "!" :
            addToken ( match ( "=" ) ? TokenType.BANG_EQUAL : TokenType.BANG )
        break
        case "=" :
            addToken ( match ( "=" ) ? TokenType.EQUAL_EQUAL : TokenType.EQUAL )
        break
        case "<" :
            addToken ( match ( "=" ) ? TokenType.LESS_EQUAL : TokenType.LESS )
        break
        case ">" :
            addToken ( match ( "=" ) ? TokenType.GREATER_EQUAL : TokenType.GREATER )
        break
        case "/" :
            if match ( "/" ) {
                // A comment goes until the end of the line.
                while peek() != "\n" && !isAtEnd() {
                    _ = advance()
                }
            } else {
                addToken ( TokenType.SLASH );
            }
        break
        // Ignore whitespace.
        case " ":
        break
        case "\r":
        break
        case "\t":
        break
        case "\n":
            line += 1
        break
        case "\"":
            string()
        break
        case "o":
            if match("r") {
                addToken(TokenType.OR)
            }
        break

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
        let text = source[start..<current]
        tokens.append(Token(type: type, lexeme: text, literal: literal, line: line))
    }

    /// Returns true if we reached the end of the source
    private func isAtEnd() -> Bool {
        return current >= source.count
    }
    
    /// Return current char and advance one char
    private func advance() -> String {
        let char = source[current]
        current += 1
        return char
    }
    
    /// Advance only if the next char matches the expected char
    private func match(_ expected: String) -> Bool {
        if isAtEnd() { return false }
        if source[current] != expected {
            return false
        }
        current += 1
        return true
    }
    
    /// consume
    private func peek() -> String {
        if isAtEnd() {
            return "\0"
        }
        return source[current]
    }
    
    /// Consume a string
    private func string () {
        while ( peek() != "\"" && !isAtEnd ()) {
            if peek() == "\n" { line += 1 }
            _ = advance()
            if ( isAtEnd ()) {
                //Lox . error ( line , "Unterminated string."
                return
            }
        }
        
        // The closing ".
        _ = advance()
        
        // Trim the surrounding quotes.
        let value = source[start + 1..<current - 1]
        addToken(TokenType.STRING, value)
    }
    
    /// Tests if the string is a digit
    func isDigit(_ string: String) -> Bool {
        let c = Character(string)
        if c.isASCII && c.isNumber { return true }
        return false
    }
    
    /// Tests if the string is alpha
    func isAlpha(_ string: String) -> Bool {
        let c = Character(string)
        if c.isASCII && c.isLetter { return true }
        if string == "_" { return true }
        return false
    }
    
    /// Tests if the string is alphanumeric
    func isAlphaNumeric(_ string: String) -> Bool {
        if isDigit(string) || isAlpha(string) { return true }
        return false
    }
    
    /// Consume a number
    private func number () {
        while isDigit(peek()) { _ = advance() }
        // Look for a fractional part.
        if peek() == "." && isDigit(peekNext()) {
            // Consume the "."
            _ = advance()
        
            while isDigit(peek()) { _ = advance() }
        }
        
        let text = source[start..<current]
        if let d = Double(text) {
            addToken(TokenType.NUMBER, d)
        } else {
            // error invalid number
        }
    }
    
    /// Double look ahead
    private func peekNext() -> String {
        if current + 1 >= source.count {
            return "\0"
        }
        return source[current + 1]
    }
    
    /// Consume an identifier
    private func identifier() {
        while isAlphaNumeric(peek()) {
            _ = advance()
        }
        
        let keywords : [String: TokenType] = [
            "and" : TokenType.AND,
            "class" : TokenType.CLASS,
            "else" : TokenType.ELSE,
            "false" : TokenType.FALSE,
            "for" : TokenType.FOR,
            "function" : TokenType.FUN,
            "if" : TokenType.IF,
            "nil" : TokenType.NIL,
            "or" : TokenType.OR,
            "print" : TokenType.PRINT,
            "return" : TokenType.RETURN,
            "super" : TokenType.SUPER,
            "this" : TokenType.THIS,
            "true" : TokenType.TRUE,
            "var" : TokenType.VAR,
            "while" : TokenType.WHILE
        ]
        
        let text = source[start..<current]
        
        if let token = keywords[text] {
            addToken(token)
        } else {
            addToken(TokenType.IDENTIFIER)
        }
    }
}
