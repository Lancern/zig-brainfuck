//! This file implements a simple Brainfuck interpreter by AST traversal.

const ast = @import("ast.zig");

/// A simple AST-traversal Brainfuck interpreter.
pub const Interp = struct {
    prog: ast.Program,

    /// Release any resources acquired by this object.
    pub fn deinit(self: Interp) void {
        self.prog.deinit();
    }

    /// Run the Brainfuck program.
    pub fn run(self: *Interp) InterpError!void {
        // TODO: implement Interp.run
        unreachable;
    }
};

/// Error reported by the AST-traversal interpreter.
pub const InterpError = error{
    DataPtrOverflow,
};
