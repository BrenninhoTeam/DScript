<div align="center">

<img src="https://img.shields.io/badge/DScript-Language-blueviolet?style=for-the-badge&logo=haxe&logoColor=white" alt="DScript"/>

# DScript

**A fast, expressive scripting language built on top of Haxe.**

[![License](https://img.shields.io/github/license/BrenninhoTeam/DScript?style=flat-square&color=orange)](LICENSE)
[![Haxe](https://img.shields.io/badge/Haxe-4.3.7-yellow?style=flat-square&logo=haxe)](https://haxe.org)
[![Build](https://img.shields.io/github/actions/workflow/status/BrenninhoTeam/DScript/ci.yml?style=flat-square&label=CI)](https://github.com/BrenninhoTeam/DScript/actions)
[![Stars](https://img.shields.io/github/stars/BrenninhoTeam/DScript?style=flat-square&color=gold)](https://github.com/BrenninhoTeam/DScript/stargazers)

[Features](#features) · [Syntax](#syntax) · [Installation](#installation) · [Embedding](#embedding-api) · [Roadmap](#roadmap)

</div>

---

## Overview

DScript is a lightweight, dynamically typed scripting language designed for extensibility and ease of embedding. Written entirely in **Haxe**, it compiles and runs across all major Haxe targets — including C++, HashLink, JavaScript, and the JVM — making it suitable for desktop applications, game engines, and web runtimes alike.

DScript was designed with a single principle in mind: **scripts should be simple to write, safe to run, and trivial to embed.**

---

## Features

- **Cross-platform** — runs anywhere Haxe runs: Windows, Linux, macOS, Android, Web
- **Embeddable** — drop the interpreter into any Haxe project with a single import
- **Dynamic typing** with optional runtime type assertions
- **First-class functions** and closures
- **Classes and inheritance** with a clean, minimal syntax
- **Standard library** covering math, strings, arrays, maps, I/O, and JSON
- **Custom built-in bindings** — expose any Haxe API to DScript with one line
- **Sandboxed execution** — control exactly what the script can access
- **Lightweight** — zero external dependencies beyond the Haxe standard library

---

## Syntax

### Variables

```ds
var name = "DScript"
var version = 1
var stable = true
var pi = 3.14159
```

### Functions

```ds
fn greet(name) {
    return "Hello, " + name + "!"
}

fn factorial(n) {
    if n <= 1 { return 1 }
    return n * factorial(n - 1)
}
```

### Control Flow

```ds
var x = 10

if x > 5 {
    println("greater")
} else if x == 5 {
    println("equal")
} else {
    println("lesser")
}

var i = 0
while i < 5 {
    println(i)
    i = i + 1
}

for item in ["a", "b", "c"] {
    println(item)
}
```

### Classes

```ds
class Animal {
    var name
    var sound

    fn init(name, sound) {
        self.name = name
        self.sound = sound
    }

    fn speak() {
        return self.name + " says " + self.sound
    }
}

class Dog extends Animal {
    fn init(name) {
        super.init(name, "woof")
    }

    fn fetch(item) {
        return self.name + " fetched the " + item
    }
}

var dog = Dog("Rex")
println(dog.speak())
println(dog.fetch("ball"))
```

### Arrays and Maps

```ds
var numbers = [1, 2, 3, 4, 5]
var doubled = numbers.map(fn(n) { return n * 2 })

var config = {
    "width": 1280,
    "height": 720,
    "fullscreen": false
}

println(config["width"])
```

### Error Handling

```ds
try {
    var result = riskyOperation()
    println(result)
} catch (err) {
    println("Error: " + err.message)
}
```

### Lambda and Closures

```ds
var add = fn(a, b) { return a + b }
var multiply = fn(a, b) { return a * b }

fn applyOp(op, x, y) {
    return op(x, y)
}

println(applyOp(add, 3, 4))
println(applyOp(multiply, 3, 4))
```

---

## Installation

### Prerequisites

- [Haxe](https://haxe.org/download/) `4.3.7` or later
- [haxelib](https://lib.haxe.org/) (bundled with Haxe)

### Install via haxelib

```bash
haxelib install dscript
```

### Build from Source

```bash
git clone https://github.com/BrenninhoTeam/DScript.git
cd DScript
haxelib dev dscript .
haxe build.hxml
```

---

## CLI Usage

Run a `.ds` script directly:

```bash
dscript run main.ds
```

Start an interactive REPL:

```bash
dscript repl
```

Compile to a standalone executable (requires HashLink or hxcpp):

```bash
dscript build main.ds --target hl --output bin/main
```

Check syntax without executing:

```bash
dscript check main.ds
```

---

## Embedding API

Integrate DScript into any Haxe project:

```haxe
import dscript.Interpreter;
import dscript.Value;

var interpreter = new Interpreter();

interpreter.bind("print", function(args:Array<Value>) {
    Sys.println(args[0].toString());
    return Value.Null;
});

interpreter.bind("getTime", function(args:Array<Value>) {
    return Value.Number(Sys.time());
});

interpreter.run("
    var t = getTime()
    print('Current time: ' + t)
");
```

### Sandboxing

Restrict what scripts can access:

```haxe
var sandbox = new Sandbox();
sandbox.allowIO(false);
sandbox.allowNet(false);
sandbox.setMemoryLimit(8 * 1024 * 1024);

var interpreter = new Interpreter(sandbox);
interpreter.run(untrustedScript);
```

### Returning Values

```haxe
var result = interpreter.eval("2 + 2 * 10");

switch result {
    case Value.Number(n): Sys.println("Result: " + n);
    case Value.String(s): Sys.println("String: " + s);
    case Value.Null: Sys.println("Null");
    default:
}
```

---

## Standard Library

| Module | Description |
|--------|-------------|
| `std.io` | `println`, `print`, `readLine`, `readFile`, `writeFile` |
| `std.math` | `floor`, `ceil`, `round`, `sqrt`, `pow`, `abs`, `sin`, `cos` |
| `std.string` | `length`, `split`, `trim`, `upper`, `lower`, `replace`, `contains` |
| `std.array` | `push`, `pop`, `shift`, `map`, `filter`, `reduce`, `sort`, `join` |
| `std.map` | `get`, `set`, `has`, `remove`, `keys`, `values` |
| `std.json` | `parse`, `stringify` |
| `std.sys` | `time`, `exit`, `env`, `args` |

---

## Project Structure

```
DScript/
├── src/
│   ├── dscript/
│   │   ├── Lexer.hx          # Tokenizer
│   │   ├── Parser.hx         # AST builder
│   │   ├── Interpreter.hx    # Tree-walk interpreter
│   │   ├── Resolver.hx       # Variable resolution pass
│   │   ├── Environment.hx    # Scope/variable storage
│   │   ├── Sandbox.hx        # Execution restrictions
│   │   ├── Value.hx          # Runtime value types
│   │   ├── Stdlib.hx         # Standard library bindings
│   │   └── Error.hx          # Error types
│   └── Main.hx               # CLI entry point
├── tests/
│   ├── LexerTest.hx
│   ├── ParserTest.hx
│   └── InterpreterTest.hx
├── examples/
│   ├── hello.ds
│   ├── fibonacci.ds
│   ├── classes.ds
│   └── embedding/
│       └── Main.hx
├── build.hxml
├── haxelib.json
└── README.md
```

---

## Roadmap

- [x] Lexer and parser
- [x] Tree-walk interpreter
- [x] First-class functions and closures
- [x] Classes with inheritance
- [x] Standard library core modules
- [x] Haxe embedding API
- [ ] Bytecode compiler
- [ ] Register-based VM
- [ ] Static type annotations (optional)
- [ ] Module and import system
- [ ] Package manager (`dspkg`)
- [ ] LSP server for editor support
- [ ] Native async/await
- [ ] Source maps for debugging

---

## Contributing

Contributions are welcome. Please open an issue before submitting a pull request for major changes.

```bash
git clone https://github.com/BrenninhoTeam/DScript.git
cd DScript
haxelib dev dscript .
haxe test.hxml
```

All PRs must pass the existing test suite and include tests for any new behavior.

---

## License

DScript is licensed under the **Apache License 2.0**. See [LICENSE](LICENSE) for details.

---

<div align="center">
  <sub>Built with Haxe · Made by <a href="https://github.com/BrenninhoTeam">BrenninhoTeam</a></sub>
</div>
