//
//  File.swift
//  
//
//  Created by Markus Moenig on 30/10/2564 BE.
//

import MetalKit

/// The different kind of assets we support right now
public enum AssetType {
    case image
    case audio
}

@available(macOS 10.11, *)
public typealias AssetCB = (_ name: String,_ type: AssetType) -> Asset?

@available(macOS 10.11, *)
public enum Asset {
    case texture(MTLTexture)
    
    // Return type
    func type() -> AssetType {
        switch self {
        case .texture:    return .image
        //case .audio:      return .audio
        }
    }
    
    // Return as number
    public func asTexture() -> MTLTexture? {
        switch self {
        case .texture(let value): return value
        //default: return nil
        }
    }
}
