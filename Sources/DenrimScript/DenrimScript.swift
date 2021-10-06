
// Implementation based on the excellent book of Robert Nystrom: Crafting Interpreters

public struct DenrimScript {
            
    static let vm = VM()

    public init() {
    }
    
    public func execute(source: String) -> Errors {
        let errors = Errors()
        
        /*
        let chunk = Chunk()
        chunk.write(OpCode.Constant.rawValue, line: 123)
        chunk.addConstant(1.2, line: 123)
        
        chunk.write(OpCode.Constant.rawValue, line: 123)
        chunk.addConstant(3.4, line: 123)
        
        chunk.write(OpCode.Add.rawValue, line: 123)
        
        chunk.write(OpCode.Constant.rawValue, line: 123)
        chunk.addConstant(2, line: 123)
        
        chunk.write(OpCode.Divide.rawValue, line: 123)

        chunk.write(OpCode.Negate.rawValue, line: 123)
        chunk.write(OpCode.Return.rawValue, line: 123)
        
        //print(chunk.disassemble(name: "Test"))
        */

        _ = DenrimScript.vm.interpret(source: source)

        return errors
    }
}
