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
    
    denrim.registerFn(name: "rand", fn: { args, instance in
        return .number(Double.random(in: 0...1))
    })
    
    denrim.registerFn(name: "time", fn: { args, instance in
        return .number(NSDate().timeIntervalSince1970)
    })
    
    denrim.registerFn(name: "print", fn: { args, instance in
        var text = ""
        for o in args {
            text += o.toString() + " "
        }
        denrim.printOutput += text + "\n"
        return .NIL()
    })
    
    // N2
    let n2Class = denrim.registerClass(name: "N2")
    denrim.registerClassMethod(classObject: n2Class, name: "init", fn: { args, instance in
        if let instance = instance {
            if args.count == 1, let value = args[0].asNumber() {
                instance.fields["x"] = .number(value)
                instance.fields["y"] = .number(value)
            } else {
                instance.fields["x"] = args.count > 0 && args[0].isNumber() ? args[0] : .number(0)
                instance.fields["y"] = args.count > 1 && args[1].isNumber() ? args[1] : .number(0)
            }
            instance.klass.role = .n2
        }
        return .NIL()
    })
    
    // N3
    let n3Class = denrim.registerClass(name: "N3")
    denrim.registerClassMethod(classObject: n3Class, name: "init", fn: { args, instance in
        if let instance = instance {
            if args.count == 1, let value = args[0].asNumber() {
                instance.fields["x"] = .number(value)
                instance.fields["y"] = .number(value)
                instance.fields["z"] = .number(value)
            } else {
                instance.fields["x"] = args.count > 0 && args[0].isNumber() ? args[0] : .number(0)
                instance.fields["y"] = args.count > 1 && args[1].isNumber() ? args[1] : .number(0)
                instance.fields["z"] = args.count > 2 && args[2].isNumber() ? args[2] : .number(0)
            }            
            instance.klass.role = .n3
        }
        
        return .NIL()
    })
    
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
            
            var width = 100
            var height = 100
            
            if args.count == 0, let view = denrim.view {
                width = Int(view.bounds.width)
                height = Int(view.bounds.height)
            }
            
            let texture = denrim.allocateTexture2D(width: width, height: height)
            instance.native = texture
            instance.klass.role = .tex2d
        }
        
        return .NIL()
    })
    
    denrim.registerClassMethod(classObject: tex2DClass, name: "makeDefault", fn: { args, instance in
        if let instance = instance {
            if let texture = instance.native as? MTLTexture {
                denrim.resultTexture = texture
            }
        }
        return .NIL()
    })
    
    denrim.registerClassMethod(classObject: tex2DClass, name: "get_width", fn: { args, instance in
        if let instance = instance {
            if let texture = instance.native as? MTLTexture {
                return .number(Double(texture.width))
            }
        }
        return .NIL()
    })
    
    denrim.registerClassMethod(classObject: tex2DClass, name: "get_height", fn: { args, instance in
        if let instance = instance {
            if let texture = instance.native as? MTLTexture {
                return .number(Double(texture.height))
            }
        }        
        return .NIL()
    })
}
