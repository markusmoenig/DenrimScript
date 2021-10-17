
// Implementation based on the excellent book of Robert Nystrom: Crafting Interpreters

public struct DenrimScript {
            
    let vm = VM()

    public init() {
    }
    
    public func execute(source: String) -> Errors {
        let errors = Errors()

        _ = vm.interpret(source: source, errors: errors)

        return errors
    }
}
