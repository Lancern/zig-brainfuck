//! This file implements a simple Brainfuck interpreter by AST traversal.

const std = @import("std");

const ast = @import("ast.zig");

/// The internal state of an AST-traversal interpreter.
pub const InterpState = struct {
    alloc: std.mem.Allocator,
    memory: []u8,
    data_ptr: usize,

    /// Initialize a new interpreter state that uses the given memory allocator.
    pub fn init(allocator: std.mem.Allocator) Interp {
        const MEMORY_SIZE = 65535;
        const memory = allocator.alloc(u8, MEMORY_SIZE) catch @panic("memory allocation fails");
        @memset(memory, 0);
        return Interp{
            .alloc = allocator,
            .memory = memory,
            .data_ptr = 0,
        };
    }

    /// Release any resources acquired by this object.
    pub fn deinit(self: InterpState) void {
        self.alloc.free(self.memory);
    }
};

/// A simple AST-traversal Brainfuck interpreter.
pub const Interp = struct {
    cmds: []ast.Command,
    state: *InterpState,

    /// Initialize a new interpreter instance that executes the given program.
    pub fn init(prog: *const ast.Program, state: *InterpState) Interp {
        return Interp{
            .cmds = prog.commands.items,
            .state = state,
        };
    }

    /// Run the Brainfuck program.
    pub fn run(self: Interp) InterpError!void {
        for (self.prog.commands.items) |*cmd| {
            try self.execute_command(cmd);
        }
    }

    fn execute_command(self: *Interp, cmd: *const ast.Command) InterpError!void {
        switch (cmd.kind) {
            ast.CommandKind.inc_data_ptr => {
                self.data_ptr +%= 1;
                try self.check_data_ptr();
            },
            ast.CommandKind.dec_data_ptr => {
                self.data_ptr -%= 1;
                try self.check_data_ptr();
            },
            ast.CommandKind.inc_data => {
                self.memory[self.data_ptr] +%= 1;
            },
            ast.CommandKind.dec_data => {
                self.memory[self.data_ptr] -%= 1;
            },
            ast.CommandKind.output => {
                const data = self.memory[self.data_ptr];
                std.io.getStdOut().write([_]u8{data}) catch return InterpError.WriteOutputFailed;
            },
            ast.CommandKind.input => {
                var data = [_]u8{undefined};
                const bytes_read = std.io.getStdIn().read(data) catch return InterpError.ReadInputFailed;
                if (bytes_read != 1) {
                    return InterpError.ReadInputFailed;
                }
                self.memory[self.data_ptr] = data[0];
            },
            ast.CommandKind.loop => |loop| {
                var sub_interp = Interp{
                    .cmds = loop.items,
                    .state = self.state,
                };

                while (self.memory[self.data_ptr] != 0) {
                    try sub_interp.run();
                }
            },
        }
    }

    fn check_data_ptr(self: *Interp) InterpError!void {
        if (self.data_ptr >= self.memory.len) {
            return InterpError.DataPtrOverflow;
        }
    }
};

/// Error reported by the AST-traversal interpreter.
pub const InterpError = error{
    DataPtrOverflow,
    WriteOutputFailed,
    ReadInputFailed,
};
