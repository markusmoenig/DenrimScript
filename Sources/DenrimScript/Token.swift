//
//  Token.swift
//  
//
//  Created by Markus Moenig on 3/10/2564 BE.
//

import Foundation

enum TokenType {
    case
        // Single-character tokens.
        LEFT_PAREN , RIGHT_PAREN , LEFT_BRACE , RIGHT_BRACE ,
        COMMA , DOT , MINUS , PLUS , SEMICOLON , SLASH , STAR ,
        // One or two character tokens.
        BANG , BANG_EQUAL ,
        EQUAL , EQUAL_EQUAL ,
        GREATER , GREATER_EQUAL,
        LESS , LESS_EQUAL ,
        // Literals.
        IDENTIFIER , STRING , NUMBER ,
        // Keywords.
        AND , CLASS , ELSE , FALSE , FUN , FOR , IF , NIL , OR ,
        PRINT , RETURN , SUPER , THIS , TRUE , VAR , WHILE ,
        EOF
}

class Token {
    
    let type            : TokenType
    let lexeme          : String
    let literal         : Any?
    
    let line            : Int
    let column          : Int
    
    init(type: TokenType, lexeme: String, literal: Any? = nil, line: Int, column: Int = 0) {
        self.type = type
        self.lexeme = lexeme
        self.literal = literal
        self.line = line
        self.column = column
    }
    
    func debug() {
        print(type, lexeme, literal != nil ? literal! : "")
    }
}
