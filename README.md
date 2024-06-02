# Zig key-value store

[![CI](https://github.com/coffee-cup/zig-kv/actions/workflows/main.yml/badge.svg)](https://github.com/coffee-cup/zig-kv/actions/workflows/main.yml)

A simple key-value store implemented in Zig. Stores can be read and written to disk.

## CLI

You can use the CLI to interact with the key-value store.

```bash
> kv --help
Save key-value pairs to a file.
    -h, --help
            Display this help and exit.

    -f, --file <str>
            The file to read and write the key-value pairs. Defaults to ~/.kv.json.

    <str>...
            The key-value pairs to add to the file. e.g. key1 value1 key2 value2.
```

### Examples

Set key-value pairs in the store:

```bash
# Sets hello=world and one=1 in the store
# Saves the store to the default location on disk (~/.kv.json)
kv hello world one 1
```

Get a single item from the store:

```bash
# Gets the value of the key hello
kv hello
```

Use a non-default file location

```bash
kv -f test.json hello world one 1
kv -f test.json hello
```

## Usage

You can use the key-value store in your Zig code.

```zig
pub fn main() !void {
  var gpa = std.heap.GeneralPurposeAllocator(.{}){};
  defer _ = gpa.deinit();

  const allocator = gpa.allocator();

  var kv = Kv.init(allocator);
  defer kv.deinit();

  // Load key-value pairs from a file
  try kv.load("test.json");

  // Set and get a few values
  try kv.put("hello", "world");
  try kv.put("one", "1");
  _ = try kv.get("hello");

  // Save the key-value pairs to a file
  try kv.save("test.json");
}
```

## Installation

_todo_
