const std = @import("std");
const kv = @import("kv.zig");
const clap = @import("clap");

const Allocator = std.mem.Allocator;

fn getDefaultFilename(allocator: Allocator, buffer: []u8) ![]const u8 {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    const home = env_map.get("HOME") orelse unreachable;
    return try std.fmt.bufPrint(buffer, "{s}/.kv.json", .{home});
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const params = comptime clap.parseParamsComptime(
        \\-h, --help Display this help and exit.
        \\-f, --file <str> The file to read and write the key-value pairs. Defaults to ~/.kv.json.
        \\<str>... The key-value pairs to add to the file. e.g. key1 value1 key2 value2.
    );

    var diag = clap.Diagnostic{};
    var res = clap.parse(clap.Help, &params, clap.parsers.default, .{
        .diagnostic = &diag,
        .allocator = allocator,
    }) catch |err| {
        diag.report(std.io.getStdErr().writer(), err) catch {};
        return err;
    };
    defer res.deinit();

    if (res.args.help != 0 or res.positionals.len == 0) {
        std.debug.print("Save key-value pairs to a file.\n", .{});
        try clap.help(std.io.getStdErr().writer(), clap.Help, &params, .{});
        return;
    }

    var buffer: [64]u8 = undefined;
    const defaultFilename = try getDefaultFilename(allocator, &buffer);
    const filename = res.args.file orelse defaultFilename;

    var store = kv.Kv.init(allocator);
    defer store.deinit();
    store.load(filename) catch {};

    // Get a single item if only 1 positional argument is provided
    if (res.positionals.len == 1) {
        // Get a single item
        const item = store.get(res.positionals[0]);
        if (item) |v| {
            std.debug.print("{s}\n", .{v});
        } else {
            std.debug.print("Key not found.\n", .{});
        }

        return;
    }

    if (res.positionals.len % 2 != 0) {
        std.debug.print("Expected an even number of positional arguments.\n", .{});
        return;
    }

    // Load the key-value pairs into the store
    var key: ?[]const u8 = null;
    for (res.positionals) |pos| {
        if (key) |k| {
            const value = pos;
            try store.put(k, value);
            key = null;
        } else {
            key = pos;
        }
    }

    try store.save(filename);
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
