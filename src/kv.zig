const std = @import("std");
const Allocator = std.mem.Allocator;

const Place = struct { lat: f32, long: f32 };

pub const Kv = struct {
    allocator: Allocator,
    store: std.StringArrayHashMap([]const u8),

    pub fn init(allocator: Allocator) Kv {
        return .{ .allocator = allocator, .store = std.StringArrayHashMap([]const u8).init(allocator) };
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

    pub fn save(self: *Kv, filename: []const u8) !void {
        var value = std.json.ArrayHashMap([]const u8){};
        defer value.deinit(self.allocator);

        var iterator = self.store.iterator();
        while (iterator.next()) |entry| {
            try value.map.put(self.allocator, entry.key_ptr.*, entry.value_ptr.*);
        }

        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        var string = std.ArrayList(u8).init(self.allocator);
        defer string.deinit();

        try std.json.stringify(value, .{}, string.writer());
        _ = try file.write(string.items);
    }

    pub fn load(self: *Kv, filename: []const u8) !void {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        const contents = try file.readToEndAlloc(self.allocator, std.math.maxInt(usize));
        defer self.allocator.free(contents);

        const parsed = try std.json.parseFromSlice(std.json.ArrayHashMap([]const u8), self.allocator, contents, .{});
        defer parsed.deinit();

        var iterator = parsed.value.map.iterator();
        while (iterator.next()) |entry| {
            try self.put(entry.key_ptr.*, entry.value_ptr.*);
        }

        // const json = try std.json.parseFromSlice(std.json.Value, self.allocator, contents, .{});
        // defer json.deinit();

        // // Parse all the string key-value pairs from the JSON object
        // // panic if the value is not a string
        // switch (json.value) {
        //     .object => |obj| {
        //         var iterator = obj.iterator();
        //         while (iterator.next()) |entry| {
        //             const value = switch (entry.value_ptr.*) {
        //                 .string => |str| str,
        //                 else => @panic("Expected string value"),
        //             };

        //             // Copy value into the kv store
        //             try self.put(entry.key_ptr.*, value);
        //         }
        //     },
        //     else => {
        //         @panic("Expected JSON object");
        //     },
        // }
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

fn getRandomFilename(buffer: []u8) ![]const u8 {
    var rng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const format = "/tmp/kv-{}.json";

    const random_number = rng.random().int(u32);
    return try std.fmt.bufPrint(buffer, format, .{random_number});
}

test "reads and writes kv from a file" {
    const allocator = std.testing.allocator;
    var kv = Kv.init(allocator);
    defer kv.deinit();

    var buffer: [64]u8 = undefined;
    const filename = try getRandomFilename(&buffer);
    defer _ = std.fs.cwd().deleteFile(filename) catch unreachable;

    try kv.put("hello", "world");
    try kv.put("one", "1");
    try kv.save(filename);

    var kv2 = Kv.init(allocator);
    defer kv2.deinit();
    try kv2.load(filename);

    try std.testing.expect(std.mem.eql(u8, kv2.get("hello") orelse unreachable, "world"));
    try std.testing.expect(std.mem.eql(u8, kv2.get("one") orelse unreachable, "1"));
}
