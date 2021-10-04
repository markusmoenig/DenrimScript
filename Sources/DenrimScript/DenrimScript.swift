
// Implementation based on the excellent book of Robert Nystrom: Crafting Interpreters

public struct DenrimScript {
    //public private(set) var text = "Hello, World!"
            
    public init() {
    }
    
    public func execute(source: String) -> Errors {
        let errors = Errors()

        let scanner = Scanner(source: source)
        let tokens = scanner.scanTokens(errors)
                
        let parser = Parser(tokens: tokens)
        let statements = parser.parse(errors)
        
        print(statements)
        for t in tokens {
            t.toString()
        }
        
        return errors
    }
}
