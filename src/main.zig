const std = @import("std");

pub fn Rc(comptime T: type) type {
    return struct {
        const Self = @This();

        const Inner = struct {
            data: T,
            usages: u64,
        };

        inner: *Inner,
        ally: std.mem.Allocator,

        pub fn init(value: T, ally: std.mem.Allocator) !Self {
            const inner = try ally.create(Inner);
            inner.* = Inner{
                .data = value,
                .usages = 1,
            };
            return Self{
                .inner = inner,
                .ally = ally,
            };
        }

        pub fn deinit(self: Self) void {
            std.debug.assert(self.inner.usages > 0);
            self.inner.usages -= 1;
            if (self.inner.usages == 0) {
                self.ally.destroy(self.inner);
            }
        }

        pub fn isFinal(self: Self) bool {
            return self.inner.usages == 1;
        }

        pub fn ref(self: Self) Self {
            self.inner.usages += 1;
            return self;
        }
    };
}

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
    ally: std.mem.Allocator,
    bytes: []const u8,

    pub fn deinit(self: *String) void {
        if (self.bytes.len > 0) {
            self.ally.free(self.bytes);
        }
    }
};

pub const Table = std.StringHashMap(Value);

pub const List = std.ArrayList(Value);

pub fn list(ally: std.mem.Allocator) !Value {
    return Value{
        .list = try Rc(List).init(List.init(ally), ally),
    };
}

pub fn string(str: []const u8, ally: std.mem.Allocator) !Value {
    return Value{
        .string = try Rc(String).init(String{
            .ally = ally,
            .bytes = if (str.len == 0) "" else try ally.dupe(u8, str),
        }, ally),
    };
}

pub fn main() !void {}

test "rc gc test" {
    const ally = std.testing.allocator;

    var l = try list(ally);
    defer l.deinit();

    try l.asList().append(try string("", ally));
    try l.asList().append(try string("hello", ally));
}
