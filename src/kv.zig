const std = @import("std");
const Allocator = std.mem.Allocator;

pub const Kv = struct {
    allocator: Allocator,
    store: std.StringHashMap([]const u8),

    pub fn init(allocator: Allocator) Kv {
        return .{ .allocator = allocator, .store = std.StringHashMap([]const u8).init(allocator) };
    }

    pub fn deinit(self: *Kv) void {
        self.store.deinit();
    }

    pub fn get(self: *Kv, key: []const u8) ?[]const u8 {
        return self.store.get(key);
    }

    pub fn put(self: *Kv, key: []const u8, value: []const u8) !void {
        try self.store.put(key, value);
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
