//! This module implements a simple command line argument parser.

const std = @import("std");

/// A simple command line argument parser.
pub const Parser = struct {
    const SlotList = std.SinglyLinkedList(ArgSlot);
    const Node = SlotList.Node;

    allocator: std.mem.Allocator,
    slots: SlotList,

    /// Initialize a new Parser object that uses the given memory allocator.
    pub fn init(allocator: std.mem.Allocator) Parser {
        return Parser{
            .allocator = allocator,
            .slots = SlotList{},
        };
    }

    /// Release any resources required by this object.
    pub fn deinit(self: Parser) void {
        while (self.slots.first != null) {
            const head = self.slots.popFirst() orelse unreachable;
            if (head.data.value) |head_value| {
                self.allocator.free(head_value);
            }
            self.allocator.destroy(head);
        }
    }

    /// Register an argument to the command line parser.
    pub fn addArgument(self: *Parser, slot: ArgSlot) *const ArgSlot {
        const node_ptr = self.allocator.create(Node) catch @panic("memory allocation failed");
        node_ptr.* = Node{
            .data = slot,
        };

        // Insert the new node at the back of the argument slot list.
        if (self.slots.first) |head| {
            head.findLast().insertAfter(node_ptr);
        } else {
            self.slots.first = node_ptr;
        }

        return &node_ptr.data;
    }

    /// Parse command line arguments as given in `std.os.argv`.
    ///
    /// If any error occurs during parsing, this function will exit the program.
    pub fn parseArgv(self: Parser) void {
        self.parse(std.os.argv) catch |err| {
            std.io.getStdErr().writer().print("invalid command line arguments: {s}", .{err});
            std.os.exit(1);
        };
    }

    /// Parse the given command line arguments.
    pub fn parse(self: Parser, argv: [][*:0]const u8) ParseError!void {
        if (argv.len >= 1) {
            // Skip the first element in the argv slice as it is the name of the program.
            argv = argv[1..];
        }

        var next_pos_arg = find_next_positional(self.slots.first);

        var current_option: ?*Node = null;
        for (argv) |item| {
            const item_span = std.mem.span(item);
            if (std.mem.startsWith(u8, item_span, "-")) {
                if (current_option != null) {
                    return ParseError.NoArgument;
                }

                if (std.mem.startsWith(u8, item_span, "--")) {
                    // This is a long option.
                    current_option = self.find_option_long(item_span[2..]);
                } else {
                    // This is a short option.
                    current_option = self.find_option_short(item_span[1..]);
                }

                if (current_option == null) {
                    return ParseError.UnknownOption;
                }
            } else {
                if (current_option) |option| {
                    option.data.value = item_span;
                    current_option = null;
                } else if (next_pos_arg) |arg| {
                    arg.data.value = item_span;
                    next_pos_arg = find_next_positional(arg.next);
                } else {
                    return ParseError.UnknownPositionalArgument;
                }
            }
        }

        if (current_option == null) {
            return ParseError.NoArgument;
        }

        // Ensure that all positional arguments have values.
        var node = self.slots.first;
        while (node) |node_ptr| {
            if (node_ptr.data.isPositional() and node_ptr.data.value == null) {
                return ParseError.NoArgument;
            }
        }
    }

    fn find_option_short(self: Parser, name: []const u8) ?*Node {
        var node = self.slots.first;
        while (node) |node_ptr| {
            if (std.mem.eql(u8, node_ptr.data.short, name)) {
                return node_ptr;
            }
            node = node_ptr.next;
        }
        return null;
    }

    fn find_option_long(self: Parser, name: []const u8) ?*Node {
        var node = self.slots.first;
        while (node) |node_ptr| {
            if (std.mem.eql(u8, node_ptr.data.long, name)) {
                return node_ptr;
            }
            node = node_ptr.next;
        }
        return null;
    }

    fn find_next_positional(node: ?*Node) ?*Node {
        while (node) |ptr| {
            if (ptr.data.isPositional()) {
                break;
            }
            node = ptr.next;
        }
        return node;
    }
};

/// Slot for a registered command line argument.
pub const ArgSlot = struct {
    short: ?[]const u8 = null,
    long: ?[]const u8 = null,
    value: ?[]const u8 = null,

    pub fn isPositional(self: ArgSlot) bool {
        return self.short == null and self.long == null;
    }
};

/// Error that may occurs when parsing the command line arguments.
pub const ParseError = error{
    UnknownOption,
    UnknownPositionalArgument,
    NoArgument,
};
