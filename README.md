# zig-brainfuck

This is a toy project that helps me learn Zig programming language. This project
implements a [Brainfuck] interpreter with Just-In-Time (JIT) compilation.

[Brainfuck]: https://en.wikipedia.org/wiki/Brainfuck

> [!NOTE]
> This project is still in a very early development phase.

## Build

```bash
zig build
```

The executable file can be found at `zig-out/bin/zig-brainfuck` after build.

## Run

> [!NOTE]
> Currently this project only implements an AST-traversal interpreter.

```bash
zig-brainfuck input.bf
```

`input.bf` is the path to the input Brainfuck source code file.

## LICENSE

This project is open-sourced under the [MIT License](./LICENSE).
