
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

    public init(_ view: MTKView? = nil) {
        self.view = view
        
        if let view = view {
            device = view.device
        } else {
            device = nil
        }
        
        vm = VM(g, device)
        setupTypes(denrim: self)
    }
    
    /// Execute the given code
    public func compile(source: String) -> Errors {
        let errors = Errors()

        vm.interpret(source: source, errors: errors)

        return errors
    }
    
    /// Execute the given code
    public func execute() {
        startCompute()
        _ = vm.execute()
        stopCompute()
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
    
    /// Called from the outside if the view needs an update
    public func updateView(_ view: MTKView) {
        print("update")
    }
    
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
