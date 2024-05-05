const std = @import("std");
const Rc = @import("rc.zig").Rc;
const Allocator = std.mem.Allocator;

pub const Value = union(enum) {
    table: Rc(Table),
    list: Rc(List),
    string: Rc(String),

    pub fn asList(value: Value) *List {
        return &value.list.inner.data;
    }

    pub fn asTable(value: Value) *Table {
        return &value.table.inner.data;
    }

    pub fn asString(value: Value) []const u8 {
        return value.string.inner.data.bytes;
    }

    pub fn deinit(value: Value) void {
        switch (value) {
            .table => |t| {
                // if refcount reaches 0, deinit keys/values
                t.deinit();
            },
            .list => |l| {
                // if refcount reaches 0, deinit values
                if (l.isFinal()) {
                    for (l.inner.data.items) |item| {
                        item.deinit();
                    }
                    l.inner.data.deinit();
                }
                l.deinit();
            },
            .string => |s| {
                if (s.isFinal()) {
                    s.inner.data.deinit();
                }
                s.deinit();
            },
        }
    }
};

pub const String = struct {
    ally: Allocator,
    bytes: []const u8,

    pub fn deinit(self: *String) void {
        if (self.bytes.len > 0) {
            self.ally.free(self.bytes);
        }
    }
};

pub const Table = std.StringHashMap(Value);

pub const List = std.ArrayList(Value);

pub fn list(ally: Allocator) !Value {
    return Value{
        .list = try Rc(List).init(List.init(ally), ally),
    };
}

pub fn string(str: []const u8, ally: Allocator) !Value {
    return Value{
        .string = try Rc(String).init(String{
            .ally = ally,
            .bytes = if (str.len == 0) "" else try ally.dupe(u8, str),
        }, ally),
    };
}

const expectEqualStrings = std.testing.expectEqualStrings;

test "rc gc test" {
    const ally = std.testing.allocator;

    var l = try list(ally);
    defer l.deinit();

    try l.asList().append(try string("", ally));
    try l.asList().append(try string("hello", ally));

    const str0 = l.asList().items[0].asString();
    try expectEqualStrings("", str0);

    const str1 = l.asList().items[1].asString();
    try expectEqualStrings("hello", str1);
}
