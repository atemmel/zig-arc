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
