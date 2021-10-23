//
//  Types.swift
//  
//
//  Created by Markus Moenig on 23/10/2564 BE.
//

import MetalKit

/**
 * Sets up all custom type classes, like N2, N3, N4, Tex2D, Tex3D
 */

@available(macOS 10.11, *)
func setupTypes(denrim: DenrimScript) {
    
    // N4
    
    let n4Class = denrim.registerClass(name: "N4")
    
    denrim.registerClassMethod(classObject: n4Class, name: "init", fn: { args, instance in
        
        if let instance = instance {
            
            if args.count == 1, let value = args[0].asNumber() {
                instance.fields["x"] = .number(value)
                instance.fields["y"] = .number(value)
                instance.fields["z"] = .number(value)
                instance.fields["w"] = .number(value)
            } else {
                instance.fields["x"] = args.count > 0 && args[0].isNumber() ? args[0] : .number(0)
                instance.fields["y"] = args.count > 1 && args[1].isNumber() ? args[1] : .number(0)
                instance.fields["z"] = args.count > 2 && args[2].isNumber() ? args[2] : .number(0)
                instance.fields["w"] = args.count > 3 && args[3].isNumber() ? args[3] : .number(0)
            }
            
            instance.klass.role = .n4
        }
        
        return .NIL()
    })
    
    // Tex2D
    
    let tex2DClass = denrim.registerClass(name: "Tex2D")
    
    denrim.registerClassMethod(classObject: tex2DClass, name: "init", fn: { args, instance in
        
        if let instance = instance {
            
            let texture = denrim.allocateTexture2D(width: 200, height: 200)
            instance.native = texture
            instance.klass.role = .tex2d
        }
        
        return .NIL()
    })
    
    denrim.registerClassMethod(classObject: tex2DClass, name: "run", fn: { args, instance in
        
        if let instance = instance {
            //instance.klass.role = .tex2d
            
            if args.count == 1, let function = args[0].asFunction() {
                if let state = denrim.vm.shader?.states[function.name] {
                    if let texture = instance.native as? MTLTexture {
                        if let encoder = denrim.commandBuffer?.makeComputeCommandEncoder() {
                            encoder.setComputePipelineState( state )
                            denrim.calculateThreadGroups(state, encoder, texture)
                            encoder.endEncoding()
                        }
                    }
                }
            }
        }
        
        return .NIL()
    })
}
