//
//  File.swift
//  
//
//  Created by Markus Moenig on 4/10/2564 BE.
//

import Foundation

public final class Error {
    
    public enum ErrorType {
        case warning
        case error
    }
    
    enum Failures: Swift.Error {
        case parseFailure
    }
    
    public let type            : ErrorType
    public let line            : Int
    public let message         : String
    
    private let token          : Token?
    
    public init(type: ErrorType = .error, line: Int, message: String) {
        self.type = type
        self.line = line
        self.message = message
        token = nil
    }

    init(type: ErrorType = .error, token: Token, message: String) {
        self.type = type
        self.token = token
        self.line = token.line
        self.message = message
    }
}

public final class Errors {    
    public var errors : [Error] = []
    
    public init() {
        
    }
    
    public func add(type: Error.ErrorType = .error, line: Int, message: String) {
        errors.append(Error(type: type, line: line, message: message))
    }
    
    func add(type: Error.ErrorType = .error, token: Token, message: String) {
        errors.append(Error(type: type, token: token, message: message))
    }
}
