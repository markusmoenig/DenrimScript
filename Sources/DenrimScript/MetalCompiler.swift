//
//  File.swift
//  
//
//  Created by Markus Moenig on 20/10/2564 BE.
//

import MetalKit

/// A shader instance
@available(macOS 10.11, *)
class Shader
{
    var isValid             : Bool = false
    var states              : [String: MTLComputePipelineState] = [:]
    
    var dataBuffer          : MTLBuffer? = nil
    
    var compileTime         : Double = 0
    var executionTime       : Double = 0

    deinit {
        states = [:]
    }
    
    init() {
    }
}

@available(macOS 10.11, *)
class ShaderCompiler
{
    let device          : MTLDevice
    
    init(_ device: MTLDevice) {
        self.device = device
    }
    
    func compile(code: String, entryFuncs: [String], asyncCompilation: Bool, cb: @escaping (Shader?) -> ())
    {
        let startTime =  NSDate().timeIntervalSince1970
        
        let shader = Shader()

        let compiledCB : MTLNewLibraryCompletionHandler = { (library, error) in
                        
            shader.compileTime = (NSDate().timeIntervalSince1970 - startTime) * 1000
                        
            if let error = error, library == nil {
                print("compile error")
                print(error.localizedDescription)
                cb(nil)
            } else
            if let library = library {
                                                
                for name in entryFuncs {
                    
                    if let function = library.makeFunction(name: name) {
                        do {
                            let state = try self.device.makeComputePipelineState(function: function)
                            shader.states[name] = state
                        } catch {
                            print( "computePipelineState failed for '\(name)'" )
                        }
                    }
                }
                
                shader.isValid = true
                /*
                shader.pipelineStateDesc = MTLRenderPipelineDescriptor()
                shader.pipelineStateDesc.vertexFunction = library.makeFunction(name: "__procVertex")
                shader.pipelineStateDesc.fragmentFunction = library.makeFunction(name: "__shaderMain")
                shader.pipelineStateDesc.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
                
                shader.pipelineStateDesc.colorAttachments[0].isBlendingEnabled = true
                shader.pipelineStateDesc.colorAttachments[0].rgbBlendOperation = .add
                shader.pipelineStateDesc.colorAttachments[0].alphaBlendOperation = .add
                shader.pipelineStateDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                shader.pipelineStateDesc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
                shader.pipelineStateDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                shader.pipelineStateDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                
                do {
                    shader.pipelineState = try self.device.makeRenderPipelineState(descriptor: shader.pipelineStateDesc)
                    shader.isValid = true
                } catch {
                    shader.isValid = false
                }
                */

                if shader.isValid == true {
                    cb(shader)
                }
            }
        }
        
        if asyncCompilation {
            device.makeLibrary(source: code, options: nil, completionHandler: compiledCB)
        } else {
            do {
                let library = try device.makeLibrary(source: code, options: nil)
                compiledCB(library, nil)
            } catch {
                cb(nil)
            }
        }
    }
}

