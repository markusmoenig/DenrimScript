
// Implementation based on the excellent book of Robert Nystrom: Crafting Interpreters

public struct DenrimScript {
            
    public init() {
    }
    
    public func execute(source: String) -> Errors {
        
        let errors = Errors()
        let vm = VM()

        _ = vm.interpret(source: source, errors: errors)

        return errors
    }
}
