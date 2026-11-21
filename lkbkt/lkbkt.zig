// Zig binding for lkbkt (single file, safe wrapper + self-test).
//
// Build via `make zig-check`, which does roughly:
//   zig build-exe lkbkt.zig -lc -OReleaseSafe \
//       -femit-bin=build/zig/lkbkt \
//       -cflags -std=c11 -I. -- leakybucket.c
//   zig test lkbkt.zig -lc -cflags -std=c11 -I. -- leakybucket.c
//
// The file doubles as a library: import it with `@import("lkbkt.zig")`
// (the `main` function is ignored when imported).

const std = @import("std");

extern fn lkbkt_new(rate: c_uint, burst: c_uint, delay: c_uint, max_keys: usize) ?*anyopaque;
extern fn lkbkt_free(handle: ?*anyopaque) void;
extern fn lkbkt_check(handle: ?*anyopaque, key: [*c]const u8, keylen: usize, now_ms: u64, delay_ms: *u32) c_int;
extern fn lkbkt_expire(handle: ?*anyopaque, now_ms: u64) usize;
extern fn lkbkt_size(handle: ?*const anyopaque) usize;

pub const NODELAY: c_uint = 0xFFFF_FFFF;

pub const Result = enum(c_int) {
    pass = 0,
    delay = 1,
    reject = 2,
    err = 3,
};

pub const Decision = struct {
    result: Result,
    delay_ms: u32,
};

pub const Bucket = struct {
    handle: ?*anyopaque = null,

    pub fn init(rate: c_uint, burst: c_uint, delay: c_uint, max_keys: usize) !Bucket {
        if (rate == 0 or max_keys == 0) return error.InvalidArgument;
        const handle = lkbkt_new(rate, burst, delay, max_keys) orelse
            return error.OutOfMemory;
        return .{ .handle = handle };
    }

    pub fn deinit(self: *Bucket) void {
        if (self.handle) |h| {
            lkbkt_free(h);
            self.handle = null;
        }
    }

    pub fn check(self: *Bucket, key: []const u8, now_ms: u64) Decision {
        const handle = self.handle orelse
            return .{ .result = .err, .delay_ms = 0 };
        var delay_ms: u32 = 0;
        const kp: [*c]const u8 = if (key.len == 0) @ptrCast("") else key.ptr;
        const r = lkbkt_check(handle, kp, key.len, now_ms, &delay_ms);
        return .{ .result = @enumFromInt(r), .delay_ms = delay_ms };
    }

    pub fn expire(self: *Bucket, now_ms: u64) usize {
        const handle = self.handle orelse return 0;
        return lkbkt_expire(handle, now_ms);
    }

    pub fn size(self: *const Bucket) usize {
        const handle = self.handle orelse return 0;
        return lkbkt_size(handle);
    }
};

pub fn nowMs() u64 {
    return @intCast(std.time.milliTimestamp());
}

pub fn main() !void {
    var b = try Bucket.init(10, 5, 0, 1024);
    defer b.deinit();

    var d = b.check("192.0.2.1", 1000);
    std.debug.assert(d.result == .pass);
    std.debug.assert(d.delay_ms == 0);

    d = b.check("192.0.2.1", 1000);
    std.debug.assert(d.result == .delay);
    std.debug.assert(d.delay_ms == 100);

    d = b.check("192.0.2.1", 1000);
    std.debug.assert(d.delay_ms == 200);

    var i: usize = 0;
    while (i < 3) : (i += 1) _ = b.check("192.0.2.1", 1000);

    std.debug.assert(b.check("192.0.2.1", 1000).result == .reject);
    std.debug.assert(b.check("192.0.2.1", 2000).result == .pass);

    std.debug.assert(b.expire(62000) == 1);
    std.debug.assert(b.size() == 0);

    std.debug.print("zig: all checks passed\n", .{});
}

test "nodelay burst then reject" {
    var b = try Bucket.init(10, 5, NODELAY, 128);
    defer b.deinit();

    var passed: usize = 0;
    var rejected: usize = 0;
    var i: usize = 0;
    while (i < 8) : (i += 1) {
        switch (b.check("k", 1000).result) {
            .pass => passed += 1,
            .reject => rejected += 1,
            else => {},
        }
    }

    try std.testing.expectEqual(@as(usize, 6), passed);
    try std.testing.expectEqual(@as(usize, 2), rejected);
    try std.testing.expect(b.check("k", 2000).result == .pass);
}

test "empty key is valid" {
    var b = try Bucket.init(1, 0, NODELAY, 8);
    defer b.deinit();

    try std.testing.expect(b.check("", 0).result == .pass);
    try std.testing.expect(b.check("", 0).result == .reject);
}
