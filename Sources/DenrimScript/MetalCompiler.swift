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
    var computeStates       : [String: MTLComputePipelineState] = [:]
    var fragmentStates      : [String: MTLRenderPipelineState] = [:]

    // Only set if the source contains fragment functions
    var pipelineStateDesc   : [String: MTLRenderPipelineDescriptor] = [:]

    var dataBuffer          : MTLBuffer? = nil
    
    var compileTime         : Double = 0
    var executionTime       : Double = 0

    deinit {
        computeStates = [:]
        fragmentStates = [:]
        pipelineStateDesc = [:]
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
    
    func compile(code: String, computeFuncs: [String], fragmentFuncs: [String], asyncCompilation: Bool, errors: Errors, lineMap: [Int:Int], cb: @escaping (Shader?) -> ())
    {
        let startTime = NSDate().timeIntervalSince1970
        
        let shader = Shader()

        var source = """
        #include <metal_stdlib>
        using namespace metal;
        
        #include <simd/simd.h>

        struct __Vertex {
            float4 position [[position]];
            float2 uv;
        };

        constant float2 __quadVertices[] = {
            float2(-1, -1),
            float2(-1,  1),
            float2( 1,  1),
            float2(-1, -1),
            float2( 1,  1),
            float2( 1, -1)
        };

        vertex __Vertex __quadVertex(unsigned short vid [[vertex_id]])
        {
            float2 position = __quadVertices[vid];
            __Vertex out;
            out.position = float4(position, 0, 1);
            out.uv = position * 0.5 + 0.5;
            return out;
        }
        
        float2 makeUV(texture2d<float, access::read_write> texture, uint2 coord) {
            return float2(coord) / float2(texture.get_width(), texture.get_height());
        }
        
        uint2 makeGID(float2 uv) {
            return uint2(uv);
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
                        
                        var line : Int = 1

                        if let lineNr = Int(arr[0]) {
                            line = lineNr - lineNumbers - 1
                        }
                        
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
                                                
                for name in computeFuncs {
                    
                    if let function = library.makeFunction(name: name) {
                        do {
                            let state = try self.device.makeComputePipelineState(function: function)
                            shader.computeStates[name] = state
                        } catch {
                            print( "computePipelineState failed for '\(name)'" )
                        }
                    }
                }
                
                shader.isValid = true
                                    
                if fragmentFuncs.isEmpty == false {
                    
                    if let vertexFunction = library.makeFunction(name: "__quadVertex") {

                        for name in fragmentFuncs {

                            let pipelineStateDesc = MTLRenderPipelineDescriptor()
                            pipelineStateDesc.vertexFunction = vertexFunction
                            pipelineStateDesc.fragmentFunction = library.makeFunction(name: name)
                            pipelineStateDesc.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
                            
                            pipelineStateDesc.colorAttachments[0].isBlendingEnabled = true
                            pipelineStateDesc.colorAttachments[0].rgbBlendOperation = .add
                            pipelineStateDesc.colorAttachments[0].alphaBlendOperation = .add
                            pipelineStateDesc.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                            pipelineStateDesc.colorAttachments[0].sourceAlphaBlendFactor = .sourceAlpha
                            pipelineStateDesc.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                            pipelineStateDesc.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
                            
                            do {
                                let state = try self.device.makeRenderPipelineState(descriptor: pipelineStateDesc)
                                shader.fragmentStates[name] = state
                            } catch {
                                print( "renderPipelineState failed for '\(name)'" )
                            }
                        }
                    }
                }


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

