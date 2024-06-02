const std = @import("std");
const Allocator = std.mem.Allocator;

const Place = struct { lat: f32, long: f32 };

pub const Kv = struct {
    allocator: Allocator,
    store: std.StringArrayHashMap([]const u8),

    /// Initialize the kv store
    pub fn init(allocator: Allocator) Kv {
        return .{ .allocator = allocator, .store = std.StringArrayHashMap([]const u8).init(allocator) };
    }

    /// Deinitialize the kv store
    pub fn deinit(self: *Kv) void {
        var iterator = self.store.iterator();
        while (iterator.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.store.deinit();
    }

    /// Get a value from the store
    pub fn get(self: *Kv, key: []const u8) ?[]const u8 {
        return self.store.get(key);
    }

    /// Put a key-value pair into the store
    pub fn put(self: *Kv, key: []const u8, value: []const u8) !void {
        // Free the old value and key if it exists
        if (self.store.fetchOrderedRemove(key)) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.value);
        }

        // Copy the key and value into the allocator
        try self.store.put(try self.allocator.dupe(u8, key), try self.allocator.dupe(u8, value));
    }

    /// Save the key-value pairs to a file
    pub fn save(self: *Kv, filename: []const u8) !void {
        // Create a json.ArrayHashMap which is compatible with the std.json library and can stringify
        var value = std.json.ArrayHashMap([]const u8){};
        defer value.deinit(self.allocator);

        // Add the key-value pairs to the json.ArrayHashMap
        var iterator = self.store.iterator();
        while (iterator.next()) |entry| {
            try value.map.put(self.allocator, entry.key_ptr.*, entry.value_ptr.*);
        }

        // Create the file
        const file = try std.fs.cwd().createFile(filename, .{});
        defer file.close();

        // Create a string to write the json to
        var string = std.ArrayList(u8).init(self.allocator);
        defer string.deinit();

        // Stringify
        try std.json.stringify(value, .{}, string.writer());

        // Write the string to the file
        _ = try file.write(string.items);
    }

    /// Load the key-value pairs from a file
    pub fn load(self: *Kv, filename: []const u8) !void {
        // Open the file
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        // Create an arena allocator so we can free all the memory used for json parsing at once
        var arena = std.heap.ArenaAllocator.init(self.allocator);
        defer arena.deinit();
        const allocator = arena.allocator();

        // Read the file into a string
        const contents = try file.readToEndAlloc(allocator, std.math.maxInt(usize));

        // Parse the json into a json.ArrayHashMap
        const parsed = try std.json.parseFromSlice(std.json.ArrayHashMap([]const u8), allocator, contents, .{});

        // Iterate over the json.ArrayHashMap and put the key-value pairs into the store
        var iterator = parsed.value.map.iterator();
        while (iterator.next()) |entry| {
            try self.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    /// Print the key-value pairs in the store
    pub fn print(self: *Kv) void {
        std.debug.print("--- KV Store (size: {d}) ---\n", .{self.store.count()});

        var iterator = self.store.iterator();
        while (iterator.next()) |entry| {
            std.debug.print("{s}: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }
};

fn getRandomFilename(buffer: []u8) ![]const u8 {
    var rng = std.rand.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const format = "/tmp/kv-{}.json";

    const random_number = rng.random().int(u32);
    return try std.fmt.bufPrint(buffer, format, .{random_number});
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

test "overwrites items in the store" {
    const allocator = std.testing.allocator;
    var kv = Kv.init(allocator);
    defer kv.deinit();

    try kv.put("hello", "world");
    try kv.put("hello", "mars");

    try std.testing.expect(kv.store.count() == 1);

    try std.testing.expect(std.mem.eql(u8, kv.get("hello") orelse unreachable, "mars"));
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
