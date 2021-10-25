
import MetalKit

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
    
    public var resultTexture: MTLTexture? = nil
    
    public var printOutput  : String = ""

    public init(_ view: MTKView? = nil) {
        self.view = view
        
        if let view = view {
            device = view.device
        } else {
            device = nil
        }
        
        vm = VM(g, device)
        setupTypes(denrim: self)
        vm.denrim = self
    }
    
    /// Execute the given code
    public func compile(source: String) -> Errors {
        let errors = Errors()

        vm.interpret(source: source, errors: errors)

        return errors
    }
    
    /// Execute the given code
    public func execute() {
        resultTexture = nil
        startCompute()
        _ = vm.execute()
        stopCompute()
        
        if view != nil {
            updateViewOnce()
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
    
    /// Call a shader function
    func callShaderFunction(_ state: MTLComputePipelineState,_ objects: [Object]) {
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
    func startCompute()
    {
        if let device = device {
            if commandQueue == nil {
                commandQueue = device.makeCommandQueue()
            }
            commandBuffer = commandQueue.makeCommandBuffer()
        }
    }
    
    /// Stops compute operation
    func stopCompute(syncTexture: MTLTexture? = nil, waitUntilCompleted: Bool = false)
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
        
        let w = state.threadExecutionWidth//limitThreads ? 1 : state.threadExecutionWidth
        let h = state.maxTotalThreadsPerThreadgroup / w//limitThreads ? 1 : state.maxTotalThreadsPerThreadgroup / w
        let d = 1//
        let threadsPerThreadgroup = MTLSizeMake(w, h, d)
        
        let threadgroupsPerGrid = MTLSize(width: (texture.width + w - 1) / w, height: (texture.height + h - 1) / h, depth: (texture.depth + d - 1) / d)
        
        encoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
    }
    
    /// Allocate a texture of the given size
    func allocateTexture2D(width: Int, height: Int, format: MTLPixelFormat = .rgba16Float) -> MTLTexture?
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
}
