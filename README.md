# DenrimScript

DenrimScript is a scripting language for the Apple and Metal ecosystem and written in Swift. 

## Abstract

DenrimScript is designed to be used as a scripting language for Swift based applications, it is easy to add native Swift functions or classes to the language.

However it's main aim is to bring the CPU and GPU together in one language with future support of running functions seamlessly on the GPU / Metal and to pass data between the CPU and GPU on the fly. To make this happen shader functions like smoothstep and data types like Number4 (float4) will be natively supported inside the language.

If you have a fast language which supports both CPU and GPU features, you can create a dynamic ecosystem of language features for app and game development which is my ultimate goal.

The GPU part will be completely optional if you just need a native Swift based scripting language.
 
DenrimScript is implemented as a bytecode based virtual machine and is 100% written in Swift.

It's name comes from the fact that I want to use it in v2 of my game and app creator app [Denrim](https://github.com/markusmoenig/Denrim) which is currently utilizing text based behavior trees. It will also be used in my upcoming SDF modeling package [Signed](https://github.com/markusmoenig/Signed) and will replace Lua.

## Overview

As a scripting language DenrimScript is more or less full featured, with some features partially implemented. See the missing features list below.

Calculate the 10th Fibonacci number and print it: 

```c
fn fib(n) {
    if (n < 2) return n;
    return fib(n - 2) + fib(n - 1);
}

print fib(20);
```

Control flows

```c
// While loop
var whileLoop = 10;

while (whileLoop >= 0) {
    whileLoop = whileLoop - 1;
}

// For loop
for(var i = 0; i < 10; i = i + 1) {}
```

Classes

```c
class Dispenser {

    // Constructor
    init(beverage) {
        this.beverage = beverage;
    }
    
    getSome() {
        print "Enjoy some " + this.beverage + "!";
    }
}

var dispenser = Dispenser("Tea")
dispenser.getSome();
dispenser = nil;
```

DenrimScript is dynamically typed, but I will add support for defining types later for the GPU support.

## Usage

Add the URL of this repository to your Swift Packages in XCode.

```swift
import DenrimScript

let denrim = DenrimScript()

denrim.execute(code: "print 3 + 7")
```

Adding a native, global function:

```swift
script.registerFn(name: "nativeAdd", fn: add)

func add(_ args: [Object],_ instance: ObjectInstance?) -> Object {        
    if let instance = instance {
        // Reference to the class instance if this is a method
    }
        
    if args.count == 2 {
        if let num1 = args[0].asNumber(), let num2 = args[1].asNumber() {
            return .number(num1 + num2)
        }
    }
    return .NIL()
}
```

Which can then be used inside DenrimScript:

```c
print nativeAdd(3, 4);
```

Registering a class and a class method:

```Swift
let mathClass = script.registerClass(name: "Math"))

script.registerClassMethod(classObject: mathClass, name: "add", fn: add)
```

When you add a method named "init" it will be treated as the constructor for the class. Note that the instance object has a property called **native** (of type Any) where you can store Swift side data in the constructor and access during method calls.

## Missing Features

* No function scoping yet, coming soon.
* No class inheritance yet, coming soon.
* No arrays, would be nice to have but the whole idea is to use the GPU later for operations on arrays.
* The whole GPU support has to be implemented, this will be done via shader functions (sn) which will be transpiled to Metal during the compilation process.
* Data types for GPU support, like Number4 (N4).
* Shader functions emulation on the CPU (smoothstep etc)

## Acknowledgements

Robert Nystrom for the fantastic book [Crafting Interpreters](https://craftinginterpreters.com). DenrimScript is based on the C implementation of Lox. If you are interested in interpreters and compilers this is a must read.
