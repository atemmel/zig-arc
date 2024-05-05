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
                if (t.isFinal()) {
                    const my_table = value.asTable();
                    defer my_table.deinit();
                    var it = my_table.iterator();
                    while (it.next()) |entry| {
                        entry.value_ptr.*.deinit();
                    }
                }
                t.deinit();
            },
            .list => |l| {
                // if refcount reaches 0, deinit values
                if (l.isFinal()) {
                    defer l.inner.data.deinit();
                    for (l.inner.data.items) |item| {
                        item.deinit();
                    }
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

pub fn table(ally: Allocator) !Value {
    return Value{
        .table = try Rc(Table).init(Table.init(ally), ally),
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
const expect = std.testing.expect;

test "rc gc list test" {
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

test "rc gc table test" {
    const ally = std.testing.allocator;

    var l = try table(ally);
    defer l.deinit();

    try l.asTable().put("", try string("", ally));
    try l.asTable().put("greeting", try string("hello", ally));

    const str0 = l.asTable().get("");
    try expect(str0 != null);
    try expectEqualStrings("", str0.?.asString());

    const str1 = l.asTable().get("greeting");
    try expect(str1 != null);
    try expectEqualStrings("hello", str1.?.asString());
}
