
// Implementation based on the excellent book of Robert Nystrom: Crafting Interpreters

public struct DenrimScript {
            
    class Globals {
        var globals         : [String: Object] = [:]
    }
    
    let g       = Globals()
    let vm      : VM

    public init() {
        vm = VM(g)
    }
    
    /// Execute the given code
    public func execute(source: String) -> Errors {
        let errors = Errors()

        _ = vm.interpret(source: source, errors: errors)

        return errors
    }
    
    /// Registers a native function to the VM
    public func registerNativeFn(name: String, fn: @escaping NativeFunction) {
        g.globals[name] = .nativeFunction(ObjectNativeFunction(fn))
    }
}
