
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
    @discardableResult public func registerFn(name: String, fn: @escaping NativeFunction) -> Object {
        let f : Object = .nativeFunction(ObjectNativeFunction(fn))
        g.globals[name] = f
        return f
    }
    
    /// Registers a new class
    public func registerClass(name: String, instantiationCB: @escaping ClassInstantiationCB) -> Object {
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
}
