//! This file defines the abstract syntax tree for Brainfuck.

const std = @import("std");

const Allocator = std.mem.Allocator;

/// Tag enum for command kind.
pub const CommandKindTag = enum {
    inc_data_ptr,
    dec_data_ptr,
    inc_data,
    dec_data,
    output,
    input,
    loop,
};

/// Provide information specific to each type of Brainfuck command.
pub const CommandKind = union(CommandKindTag) {
    inc_data_ptr: void,
    dec_data_ptr: void,
    inc_data: void,
    dec_data: void,
    output: void,
    input: void,
    loop: std.ArrayList(Command),

    /// Release any resources acquired by this object.
    pub fn deinit(self: CommandKind) void {
        switch (self) {
            .loop => |commands| deinitCommandList(commands),
            else => {},
        }
    }
};

/// A parsed Brainfuck command together with its source location information.
pub const Command = struct {
    span: Span,
    kind: CommandKind,

    /// Release any resources acquired by this object.
    pub fn deinit(self: Command) void {
        self.kind.deinit();
    }
};

/// A parsed Brainfuck program.
pub const Program = struct {
    commands: std.ArrayList(Command),

    /// Release any resources acquired by this object.
    pub fn deinit(self: Program) void {
        deinitCommandList(self.commands);
    }
};

/// A source location.
pub const Location = struct {
    line: u32,
    column: u32,
};

/// A range of source location.
pub const Span = struct {
    start: Location,
    end: Location,
};

fn deinitCommandList(list: std.ArrayList(Command)) void {
    for (list.items) |cmd| {
        cmd.deinit();
    }
    list.deinit();
}
