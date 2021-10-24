//
//  Token.swift
//  
//
//  Created by Markus Moenig on 3/10/2564 BE.
//

import Foundation

enum TokenType {
    
    // Single-character tokens.
    case leftParen , rightParen
    case leftBrace , rightBrace
    case comma
    case dot
    case minus
    case plus
    case semicolon
    case slash
    case star
    case colon
        
    // One or two character tokens.
    case bang, bangEqual
    case equal, equalEqual
    case greater, greaterEqual
    case less, lessEqual
        
    // Literals.
    case identifier
    case string
    case number
    case type
    
    // Keywords.
    case and
    case Class
    case Else
    case False
    case fn
    case sh
    case shentry
    case For
    case If
    case Nil
    case or
    case print
    case Return
    case Super
    case this
    case True
    case Var
    case While
    
    // Types.
    case n2
    case n3
    case n4
    case tex2d
    case tex3d

    case Break
    
    case error
    case eof
}

final class Token {
    
    let type            : TokenType
    let lexeme          : String
    let line            : Int
    
    init(type: TokenType, text: String, line: Int) {
        self.type = type
        self.lexeme = text
        self.line = line
    }
    
    func toString() {
        print(type, lexeme, line)
    }
}
