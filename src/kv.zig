const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Kv = struct {
    allocator: Allocator,
    store: std.StringHashMap([]const u8),

    pub fn init(allocator: Allocator) Kv {
        return .{ .allocator = allocator, .store = std.StringHashMap([]const u8).init(allocator) };
    }

    pub fn deinit(self: *Kv) void {
        var iterator = self.store.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.store.deinit();
    }

    pub fn get(self: *Kv, key: []const u8) ?[]const u8 {
        return self.store.get(key);
    }

    pub fn put(self: *Kv, key: []const u8, value: []const u8) !void {
        // Copy the key and value into the allocator
        try self.store.put(try self.allocator.dupe(u8, key), try self.allocator.dupe(u8, value));
    }

    pub fn load(self: *Kv, filename: []const u8) !void {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        const contents = try file.readToEndAlloc(self.allocator, std.math.maxInt(usize));
        defer self.allocator.free(contents);

        const json = try std.json.parseFromSlice(std.json.Value, self.allocator, contents, .{});
        defer json.deinit();

        // Parse all the string key-value pairs from the JSON object
        // panic if the value is not a string
        switch (json.value) {
            .object => |obj| {
                var iterator = obj.iterator();
                while (iterator.next()) |entry| {
                    const value = switch (entry.value_ptr.*) {
                        .string => |str| str,
                        else => @panic("Expected string value"),
                    };

                    // Copy value into the kv store
                    try self.put(entry.key_ptr.*, value);
                }
            },
            else => {
                @panic("Expected JSON object");
            },
        }
    }

    pub fn print(self: *Kv) void {
        std.debug.print("--- KV Store (size: {d}) ---\n", .{self.store.count()});

        var iterator = self.store.iterator();
        while (iterator.next()) |entry| {
            std.debug.print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }
};

pub fn doSomething() void {
    std.debug.print("Doing something...\n", .{});
}

test "creates a new kv store" {
    const allocator = std.testing.allocator;
    const kv = Kv.init(allocator);
    try std.testing.expect(kv.store.count() == 0);
}

test "puts and gets items into the store" {
    const allocator = std.testing.allocator;
    var kv = Kv.init(allocator);
    defer kv.deinit();

    try kv.put("hello", "world");
    try std.testing.expect(kv.store.count() == 1);

    try std.testing.expect(std.mem.eql(u8, kv.get("hello") orelse unreachable, "world"));
}

test "reads kv from a file" {
    const allocator = std.testing.allocator;
    var kv = Kv.init(allocator);
    defer kv.deinit();

    try kv.load("test.json");

    try std.testing.expect(std.mem.eql(u8, kv.get("hello") orelse unreachable, "world"));
    try std.testing.expect(std.mem.eql(u8, kv.get("one") orelse unreachable, "1"));
}
