const std = @import("std");

const ast = @import("ast.zig");
const args = @import("utils/args.zig");
const interp = @import("interp.zig");
const parser = @import("parser.zig");

pub fn main() void {
    const allocator = std.heap.c_allocator;

    var cli_parser = args.Parser.init(allocator);
    defer cli_parser.deinit();

    const exec_arg = cli_parser.addArgument(.{
        .short = "e",
        .long = "exec",
    });
    const file_arg = cli_parser.addArgument(.{});
    cli_parser.parseArgv();

    const exec_name = exec_arg.value orelse {
        reportErrorAndExit("no executor specified.", .{});
    };

    const file = file_arg.value orelse {
        reportErrorAndExit("no input file specified.", .{});
    };

    const executor = createExecutor(exec_name, allocator) orelse {
        reportErrorAndExit("unknown executor name.", .{});
    };
    defer executor.deinit();

    const file_content = readFile(file, allocator) catch |err| {
        reportErrorAndExit("failed to read input file: {s}", .{@errorName(err)});
    };

    const prog = parser.parse(file_content, allocator) catch |err| {
        reportErrorAndExit("failed to parse input: {s}", .{@errorName(err)});
    };
    defer prog.deinit();

    executor.execute(&prog) catch |err| {
        reportErrorAndExit("failed to execute: {s}", .{@errorName(err)});
    };
}

fn readFile(path: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_meta = try file.metadata();
    const file_size = file_meta.size();

    const buffer = allocator.alloc(u8, file_size) catch @panic("memory allocation failed");
    errdefer allocator.free(buffer);

    _ = try file.readAll(buffer);

    return buffer;
}

const Executor = struct {
    const VTable = struct {
        execute: *const fn (*anyopaque, prog: *const ast.Program) anyerror!void,
        deinit: *const fn (*anyopaque, allocator: std.mem.Allocator) void,
    };

    allocator: std.mem.Allocator,
    ptr: *anyopaque,
    vtable: VTable,

    fn deinit(self: Executor) void {
        self.vtable.deinit(self.ptr, self.allocator);
    }

    fn execute(self: Executor, prog: *const ast.Program) anyerror!void {
        try self.vtable.execute(self.ptr, prog);
    }
};

fn reportErrorAndExit(comptime format: []const u8, fmt_args: anytype) noreturn {
    const writer = std.io.getStdErr().writer();
    writer.print("Error: ", .{}) catch {};
    writer.print(format, fmt_args) catch {};
    writer.print("\n", .{}) catch {};
    std.os.exit(1);
}

fn createExecutor(name: []const u8, allocator: std.mem.Allocator) ?Executor {
    if (std.mem.eql(u8, name, "ast")) {
        return createInterpExecutor(allocator);
    }

    // TODO: add JIT executor here.

    return null;
}

fn createInterpExecutor(allocator: std.mem.Allocator) Executor {
    const state = allocator.create(interp.InterpState) catch @panic("memory allocation failed");
    state.* = interp.InterpState.init(allocator);

    const vtable = Executor.VTable{
        .execute = interpExecutorExecute,
        .deinit = interpExecutorDeinit,
    };

    return Executor{
        .allocator = allocator,
        .ptr = state,
        .vtable = vtable,
    };
}

fn interpExecutorExecute(opaque_state: *anyopaque, prog: *const ast.Program) anyerror!void {
    var state: *interp.InterpState = @ptrCast(@alignCast(opaque_state));
    var interpreter = interp.Interp.init(prog, state);
    try interpreter.run();
}

fn interpExecutorDeinit(opaque_state: *anyopaque, allocator: std.mem.Allocator) void {
    const state: *interp.InterpState = @ptrCast(@alignCast(opaque_state));
    state.deinit();
    allocator.destroy(state);
}
