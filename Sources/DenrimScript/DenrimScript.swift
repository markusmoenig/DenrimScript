
// Implementation based on the excellent book of Robert Nystrom: Crafting Interpreters

public struct DenrimScript {
            
    static let vm = VM()

    public init() {
    }
    
    public func execute(source: String) -> Errors {
        let errors = Errors()
        
        let chunk = Chunk()
        chunk.write(OpCode.Constant.rawValue, line: 123)
        chunk.addConstant(1.2, line: 123)
        chunk.write(OpCode.Return.rawValue, line: 123)
        
        print(chunk.disassemble(name: "Test"))

        DenrimScript.vm.interpret(chunk)

        /*
        let scanner = Scanner(source: source)
        let tokens = scanner.scanTokens(errors)
                
        let parser = Parser(tokens: tokens)
        let statements = parser.parse(errors)
        
        print(statements)
        for t in tokens {
            t.toString()
        }
        */
        return errors
    }
}
