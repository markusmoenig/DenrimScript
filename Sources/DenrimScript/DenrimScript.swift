
import MetalKit

public enum InternalClasses : Hashable {

    case None
    case N2
    case N3
    case N4
    case Tex2D
    
}

@available(macOS 10.11, *)
public class DenrimScript {
    
    class Globals {
        var globals         : [String: Object] = [:]
    }
    
    let g                   = Globals()
    let vm                  : VM
    
    let view                : MTKView?
    let device              : MTLDevice?
    
    var commandQueue        : MTLCommandQueue!
    var commandBuffer       : MTLCommandBuffer!
    
    var assetCB             : AssetCB? = nil

    var gameLoopFn          : ObjectFunction? = nil
    
    var internalClasses     : [InternalClasses:ObjectClass] = [:]
    
    public var viewTextures : [ObjectInstance] = []
    
    public var resultTexture: ObjectInstance? = nil
    
    public var printOutput  : String = ""
    
    public var isRunning    : Bool = false
    
    public init(_ view: MTKView? = nil) {
        self.view = view
        
        if let view = view {
            device = view.device
        } else {
            device = nil
        }
        
        vm = VM(g, device)
        setupEnvironment(denrim: self)
        vm.denrim = self
    }
    
    deinit {
        clean()
    }
    
    public func clean() {
        g.globals = [:]
        vm.clean()
        //if let tex = resultTexture {
            //tex.setPurgeableState(.empty)
        //}
        resultTexture = nil
    }
        
    /// Set the asset callback
    public func setAssetCB(_ cb: @escaping AssetCB) {
        self.assetCB = cb
    }
    
    /// Execute the given code
    public func compile(source: String) -> Errors {
        let errors = Errors()

        vm.interpret(source: source, errors: errors)

        return errors
    }
    
    /// Execute the given code
    public func execute() {
        
        printOutput = ""

        resultTexture = nil
        startDrawing()
        _ = vm.execute()
        stopDrawing()
        
        if gameLoopFn == nil {
            updateViewOnce()
        }
        
        isRunning = true
    }
    
    /// Sets up the user requested game loop
    func setGameLoop(gameLoopFn: ObjectFunction, fps: Int) {
        self.gameLoopFn = gameLoopFn
        
        if let view = view {
            
            print("Setup game loop", gameLoopFn, fps)
                        
            view.enableSetNeedsDisplay = false
            view.isPaused = false
            view.preferredFramesPerSecond = fps
        }
    }
    
    /// Called from the metal view
    public func tick() {
        if !isRunning { return }
        
        // Check if textures locked to view resolution need to be resized because the view was resized
        for instance in  viewTextures {
            if instance.klass.internalType == .Tex2D, let texture = instance.native as? MTLTexture {
                if let view = view {
                    if Int(view.bounds.width) != texture.width || Int(view.bounds.height) != texture.height {
                     
                        texture.setPurgeableState(.volatile)
                        instance.native = nil
                        
                        instance.native = allocateTexture2D(width: Int(view.bounds.width), height: Int(view.bounds.height))
                    }
                }
            }
        }
        
        printOutput = ""
        if let gameLoopFn = gameLoopFn {
            
            //let start = NSDate().timeIntervalSince1970
            
            //startDrawing()
            _ = vm.callFromNative(function: gameLoopFn, args: [])
            //stopDrawing()
            
            //let stop = NSDate().timeIntervalSince1970
            //print((stop - start) * 1000, "ms needed for game loop")
        }
    }
    
    /// Called from the metal view
    public func mouseDown(_ pos: float2) {
        if !isRunning { return }

        printOutput = ""
        if let mouseDownFn = g.globals["mouseDown"]?.asFunction() {
            _ = vm.callFromNative(function: mouseDownFn, args: [.number2(pos)])
        }
    }
    
    /// Called from the metal view
    public func mouseDragged(_ pos: float2) {
        if !isRunning { return }

        printOutput = ""
        if let mouseDraggedFn = g.globals["mouseDragged"]?.asFunction() {
            _ = vm.callFromNative(function: mouseDraggedFn, args: [.number2(pos)])
        }
    }
    
    /// Called from the metal view
    public func mouseUp(_ pos: float2) {
        if !isRunning { return }

        printOutput = ""
        if let mouseUpFn = g.globals["mouseUp"]?.asFunction() {
            _ = vm.callFromNative(function: mouseUpFn, args: [.number2(pos)])
        }
    }
    
    /// Registers a native function to the VM
    @discardableResult public func registerFn(name: String, fn: @escaping NativeFunction) -> Object {
        let f : Object = .nativeFunction(ObjectNativeFunction(fn))
        g.globals[name] = f
        return f
    }
    
    /// Registers a new class
    public func registerClass(name: String) -> Object {
        let c : Object = .klass(ObjectClass(name: name))
        g.globals[name] = c
        return c
    }
    
    /// Registers a class method
    @discardableResult public func registerClassMethod(classObject: Object, name: String, fn: @escaping NativeFunction) -> Object {
        if let klass = classObject.asClass() {
            let f : Object = .nativeFunction(ObjectNativeFunction(fn))
            klass.methods[name] = f
            return f
        }
        return .NIL()
    }
    
    // MARK: Metal Support
        
    /// Updates the metal view once
    func updateViewOnce() {
        if let metalView = view {
            metalView.enableSetNeedsDisplay = true
            #if os(OSX)
            let nsrect : NSRect = NSRect(x:0, y: 0, width: metalView.frame.width, height: metalView.frame.height)
            metalView.setNeedsDisplay(nsrect)
            #else
            metalView.setNeedsDisplay()
            #endif
        }
    }
    
    /// Call a script function from Swift
    public func callFunction(_ function: ObjectFunction,_ args: [Object]) -> Bool {
        return vm.callFromNative(function: function, args: args)
    }
    
    /// Call a method function from Swift
    public func callMethod(_ instance: ObjectInstance,_ function: ObjectFunction,_ args: [Object]) -> Bool {
        return vm.callFromNative(instance: instance, function: function, args: args)
    }
    
    /// Call a fragment shader function
    func callFragmentShader(_ state: MTLRenderPipelineState,_ objects: [Object]) {

        guard objects.count > 1, let texInst = objects[0].asInstance(), let texture = texInst.native as? MTLTexture else {
            return
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = texture
        renderPassDescriptor.colorAttachments[0].loadAction = .load //.clear
        //renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,0)
        
        if let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
            
            for (index, o) in objects.enumerated() {
                if let number = o.asNumber() {
                    var f = Float(number)
                    encoder.setFragmentBytes(&f, length: MemoryLayout<Float>.stride, index: index)
                } else
                if let instance = o.asInstance() {
                    if instance.klass.internalType == .Tex2D {
                        if let texture = instance.native as? MTLTexture {
                            encoder.setFragmentTexture(texture, index: index)
                        }
                    } else
                    if instance.klass.internalType == .N2 {
                        var f2 = makeFloat2(instance)
                        encoder.setFragmentBytes(&f2, length: MemoryLayout<float2>.stride, index: index)
                    } else
                    if instance.klass.internalType == .N3 {
                        var f3 = makeFloat3(instance)
                        encoder.setFragmentBytes(&f3, length: MemoryLayout<float3>.stride, index: index)
                    } else
                    if instance.klass.internalType == .N4 {
                        var f4 = makeFloat4(instance)
                        encoder.setFragmentBytes(&f4, length: MemoryLayout<float4>.stride, index: index)
                    }
                }
            }
            
            //if let scissor = texInst.native2 as? MTLScissorRect {
            //    encoder.setScissorRect(scissor)
            //}
            
            encoder.setRenderPipelineState(state)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            encoder.endEncoding()
        }

        /*
        if let instance = objects[0].asInstance() {
            if let texture = instance.native as? MTLTexture {
                if let encoder = commandBuffer?.makeComputeCommandEncoder() {
                    encoder.setComputePipelineState( state )
                    
                    for (index, o) in objects.enumerated() {
                        if let number = o.asNumber() {
                            var f = Float(number)
                            encoder.setBytes(&f, length: MemoryLayout<Float>.stride, index: index)
                        } else
                        if let instance = o.asInstance() {
                            if instance.klass.role == .tex2d {
                                if let texture = instance.native as? MTLTexture {
                                    encoder.setTexture(texture, index: index)
                                }
                            } else
                            if instance.klass.role == .n2 {
                                var f2 = makeFloat2(instance)
                                encoder.setBytes(&f2, length: MemoryLayout<float2>.stride, index: index)
                            } else
                            if instance.klass.role == .n3 {
                                var f3 = makeFloat3(instance)
                                encoder.setBytes(&f3, length: MemoryLayout<float3>.stride, index: index)
                            } else
                            if instance.klass.role == .n4 {
                                var f4 = makeFloat4(instance)
                                encoder.setBytes(&f4, length: MemoryLayout<float4>.stride, index: index)
                            }
                        }
                    }
                    
                    calculateThreadGroups(state, encoder, texture)
                    encoder.endEncoding()
                }
            }
        }
        */
    }
    
    /// Call a compute shader function
    func callComputeShader(_ state: MTLComputePipelineState,_ objects: [Object]) {
        if let encoder = commandBuffer?.makeComputeCommandEncoder() {
            encoder.setComputePipelineState( state )
            
            var mainTexture : MTLTexture? = nil
            
            for (index, o) in objects.enumerated() {
                if let number = o.asNumber() {
                    var f = Float(number)
                    encoder.setBytes(&f, length: MemoryLayout<Float>.stride, index: index)
                } else
                if let instance = o.asInstance() {
                    if instance.klass.internalType == .Tex2D {
                        if let texture = instance.native as? MTLTexture {
                            encoder.setTexture(texture, index: index)
                            if index == 0 {
                                mainTexture = texture
                            }
                        }
                    } else
                    if instance.klass.internalType == .N2 {
                        var f2 = makeFloat2(instance)
                        encoder.setBytes(&f2, length: MemoryLayout<float2>.stride, index: index)
                    } else
                    if instance.klass.internalType == .N3 {
                        var f3 = makeFloat3(instance)
                        encoder.setBytes(&f3, length: MemoryLayout<float3>.stride, index: index)
                    } else
                    if instance.klass.internalType == .N4 {
                        var f4 = makeFloat4(instance)
                        encoder.setBytes(&f4, length: MemoryLayout<float4>.stride, index: index)
                    }
                }
            }
            
            if let mainTexture = mainTexture {
                calculateThreadGroups(state, encoder, mainTexture)
            }
            encoder.endEncoding()
        }
    }
    
    /// Generate a float2 for an N2 Instance
    func makeFloat2(_ instance: ObjectInstance) -> float2 {
        var f2 = float2()
        if let x = instance.fields["x"]?.asNumber() { f2.x = Float(x) }
        if let y = instance.fields["y"]?.asNumber() { f2.y = Float(y) }
        return f2
    }
    
    /// Generate a float3 for an N3 Instance
    func makeFloat3(_ instance: ObjectInstance) -> float3 {
        var f3 = float3()
        if let x = instance.fields["x"]?.asNumber() { f3.x = Float(x) }
        if let y = instance.fields["y"]?.asNumber() { f3.y = Float(y) }
        if let z = instance.fields["z"]?.asNumber() { f3.z = Float(z) }
        return f3
    }
    
    /// Generate a float4 for an N4 Instance
    func makeFloat4(_ instance: ObjectInstance) -> float4 {
        var f4 = float4()
        if let x = instance.fields["x"]?.asNumber() { f4.x = Float(x) }
        if let y = instance.fields["y"]?.asNumber() { f4.y = Float(y) }
        if let z = instance.fields["z"]?.asNumber() { f4.z = Float(z) }
        if let w = instance.fields["w"]?.asNumber() { f4.w = Float(w) }
        return f4
    }
    
    /// Starts compute operation
    public func startDrawing()
    {
        if let device = device {
            if commandQueue == nil {
                commandQueue = device.makeCommandQueue()
            }
            commandBuffer = commandQueue.makeCommandBuffer()
        }
    }
    
    /// Stops compute operation
    public func stopDrawing(syncTexture: MTLTexture? = nil, waitUntilCompleted: Bool = false)
    {
        #if os(OSX)
        if let texture = syncTexture {
            let blitEncoder = commandBuffer!.makeBlitCommandEncoder()!
            blitEncoder.synchronize(texture: texture, slice: 0, level: 0)
            blitEncoder.endEncoding()
        }
        #endif
        commandBuffer?.commit()
        if waitUntilCompleted {
            commandBuffer?.waitUntilCompleted()
        }
        commandBuffer = nil
    }
    
    /// Compute the threads and thread groups for the given state and texture
    func calculateThreadGroups(_ state: MTLComputePipelineState, _ encoder: MTLComputeCommandEncoder,_ texture: MTLTexture)
    {
        
        let w = state.threadExecutionWidth
        let h = state.maxTotalThreadsPerThreadgroup / w
        let d = 1
        let threadsPerThreadgroup = MTLSizeMake(w, h, d)
        
        let threadgroupsPerGrid = MTLSize(width: (texture.width + w - 1) / w, height: (texture.height + h - 1) / h, depth: (texture.depth + d - 1) / d)
        
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
    }
    
    /// Allocate a texture of the given size
    func allocateTexture2D(width: Int, height: Int, format: MTLPixelFormat = .rgba16Float /*bgra8Unorm*/) -> MTLTexture?
    {
        if self.device == nil { return nil }
        
        let textureDescriptor = MTLTextureDescriptor()
        textureDescriptor.textureType = MTLTextureType.type2D
        textureDescriptor.pixelFormat = format
        textureDescriptor.width = width == 0 ? 1 : width
        textureDescriptor.height = height == 0 ? 1 : height
        
        textureDescriptor.usage = MTLTextureUsage.unknown
        return self.device!.makeTexture(descriptor: textureDescriptor)
    }

    /// Creates an instance of a specific internal class type
    public func createInternalClassInstance(_ type: InternalClasses) -> ObjectInstance {
        return ObjectInstance(internalClasses[type]!)
    }
}
