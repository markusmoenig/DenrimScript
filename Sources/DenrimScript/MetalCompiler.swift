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
    
    var library             : MTLLibrary? = nil
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
    
    func compile(code: String, entryFuncs: [String], asyncCompilation: Bool, errors: Errors, lineMap: [Int:Int], cb: @escaping (Shader?) -> ())
    {
        let startTime = NSDate().timeIntervalSince1970
        
        let shader = Shader()

        var source = """
        #include <metal_stdlib>
        using namespace metal;
        
        float2 makeUV(texture2d<float, access::read_write> texture, uint2 coord) {
            return float2(coord) / float2(texture.get_width(), texture.get_height());
        }
        
        """
        
        var lineNumbers  : Int = 0
        
        let ns = source as NSString
        ns.enumerateLines { (source, _) in
            lineNumbers += 1
        }
        
        func extractErrors(_ str: String) {
            let arr = str.components(separatedBy: "program_source:")
            for str in arr {
                if str.starts(with: "Compilation failed:") == false && (str.contains("error:") || str.contains("warning:")) {
                    let arr = str.split(separator: ":")
                    let errorArr = String(arr[3].trimmingCharacters(in: .whitespaces)).split(separator: "\n")
                    var errorText = ""
                    if errorArr.count > 0 {
                        errorText = String(errorArr[0])
                    }
                    if arr.count >= 4 {
                        
                        let line : Int = Int(arr[0])! - lineNumbers - 1
                        
                        if line >= 0 {
                            if let mappedLine = lineMap[line] {
                                errors.add(line: mappedLine, message: errorText)
                            } else {
                                errors.add(line: 1, message: errorText)
                            }
                        }
                    }
                }
            }
        }
        
        source += code
        
        let compiledCB : MTLNewLibraryCompletionHandler = { (library, error) in
                        
            shader.compileTime = (NSDate().timeIntervalSince1970 - startTime) * 1000
            shader.library = library
                        
            if let error = error, library == nil {
                extractErrors(error.localizedDescription)
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
            device.makeLibrary(source: source, options: nil, completionHandler: compiledCB)
        } else {
            do {
                let library = try device.makeLibrary(source: source, options: nil)
                shader.library = library
                compiledCB(library, nil)
            } catch {
                //print(error)
                //cb(nil)
                extractErrors(error.localizedDescription)
            }
        }
    }
}

