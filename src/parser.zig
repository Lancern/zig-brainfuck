//! This file implements the Brainfuck parser.

const std = @import("std");

const ast = @import("ast.zig");

/// Parse the input Brainfuck program.
pub fn parse(input: []const u8, allocator: std.mem.Allocator) ParseError!ast.Program {
    var lexer = Lexer{
        .input = input,
    };
    const cmds = try parse_commands(&lexer, allocator);
    return ast.Program{
        .commands = cmds,
    };
}

/// Errors that may occur during parsing.
pub const ParseError = error{
    UnknownCommand,
    OpenLoop,
};

fn parse_commands(lexer: *Lexer, allocator: std.mem.Allocator) ParseError!std.ArrayList(ast.Command) {
    var commands = std.ArrayList(ast.Command).init(allocator);
    while (lexer.lex()) {
        const cmd = try parse_cmd(lexer, allocator);
        commands.append(cmd);
    }
    return commands;
}

fn parse_cmd(lexer: *Lexer, allocator: std.mem.Allocator) ParseError!ast.Command {
    const kind = switch (lexer.input[lexer.ptr]) {
        '>' => ast.CommandKind{ .inc_data_ptr = void{} },
        '<' => ast.CommandKind{ .dec_data_ptr = void{} },
        '+' => ast.CommandKind{ .inc_data = void{} },
        '-' => ast.CommandKind{ .dec_data = void{} },
        '.' => ast.CommandKind{ .output = void{} },
        ',' => ast.CommandKind{ .input = void{} },
        '[' => return parse_loop(lexer, allocator),
        else => return ParseError.UnknownCommand,
    };
    const start_loc = lexer.next_loc;
    lexer.advance();
    const end_loc = lexer.next_loc;
    const span = ast.Span{
        .start = start_loc,
        .end = end_loc,
    };

    return ast.Command{
        .span = span,
        .kind = kind,
    };
}

fn parse_loop(lexer: *Lexer, allocator: std.mem.Allocator) ParseError!ast.Command {
    std.debug.assert(lexer.input[lexer.next_loc] == '[');

    const start_loc = lexer.next_loc;

    // Consume the '[' character.
    lexer.advance();
    const body_start_ptr = lexer.ptr;
    const body_start_loc = lexer.next_loc;

    // Find the matching ']' character.
    var num_open_brackets: u16 = 0;
    while (!lexer.isEof() and (lexer.next_loc[lexer.ptr] != ']' or num_open_brackets > 0)) {
        if (lexer.next_loc[lexer.ptr] == '[') {
            num_open_brackets += 1;
        } else if (lexer.next_loc[lexer.ptr] == ']') {
            num_open_brackets -= 1;
        }
        lexer.advance();
    }
    if (lexer.isEof()) {
        return ParseError.OpenLoop;
    }

    const body_end_ptr = lexer.ptr;

    // Parse the loop body.
    var body_lexer = Lexer{
        .input = lexer.input[body_start_ptr..body_end_ptr],
        .next_loc = body_start_loc,
    };
    const body = try parse_commands(&body_lexer, allocator);

    // Consume the matching ']' character.
    lexer.advance();

    const end_loc = lexer.next_loc;
    const span = ast.Span{
        .start = start_loc,
        .end = end_loc,
    };

    return ast.Command{
        .span = span,
        .kind = ast.CommandKind{
            .loop = body,
        },
    };
}

const Lexer = struct {
    input: []const u8,
    ptr: usize = 0,
    next_loc: ast.Location = ast.Location{
        .line = 1,
        .column = 1,
    },

    fn isEof(self: Lexer) bool {
        return self.ptr >= self.input.len;
    }

    fn lex(self: *Lexer) bool {
        // Skip any whitespace characters.
        while (self.ptr < self.input.len and std.ascii.isWhitespace(self.input[self.ptr])) {
            self.advance();
        }

        return self.ptr < self.input.len;
    }

    fn advance(self: *Lexer) void {
        if (self.input[self.ptr] == '\n') {
            self.next_loc.line += 1;
            self.next_loc.column = 1;
        } else {
            self.next_loc.column += 1;
        }
        self.ptr += 1;
    }
};
