const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Battery = struct {
    battery_charge_point: u32 = 20,
    action: *const fn (u32, u32, u32) void = undefined,
    capacity_path: []const u8,

    /// Sets the trigger actuation point and returns pointer to battery
    pub fn set_trigger_point(bat: *Battery, point: u32) !*Battery {
        //if (point > bat.capacity) return error.InvalidPoint;
        bat.battery_charge_point = point;
        return bat;
    }

    /// Sets trigger action and returns pointer to battery
    pub fn on_trigger(bat: *Battery, f: fn (u32, u32, u32) void) *Battery {
        bat.action = f;
        return bat;
    }

    /// Auto field filling.
    /// Returns Battery
    pub fn default(allocator: Allocator, io: Io) !?Battery {
        const battery_path = "/sys/class/power_supply";
        const dir = try Io.Dir.cwd().openDir(io, battery_path, .{ .iterate = true });
        defer dir.close(io);

        var power_supply_iter = dir.iterate();
        var battery: Battery = undefined;

        while (try power_supply_iter.next(io)) |entry| {
            std.debug.print("power_supply_iter {s}, {}\n", .{ entry.name, entry.inode });
            const parts = [_][]const u8{ battery_path, entry.name };
            const subdirectory_path = try Io.Dir.path.join(allocator, &parts);
            const power_supply_subdirectory = try Io.Dir.cwd().openDir(io, subdirectory_path, .{ .iterate = true });
            defer power_supply_subdirectory.close(io);

            var power_supply_subdirectory_iter = power_supply_subdirectory.iterate();
            while (try power_supply_subdirectory_iter.next(io)) |raw_model| {
                std.debug.print("power_supply_subdirectory_iter {s}\n", .{raw_model.name});
                if (raw_model.kind == .file and std.mem.eql(u8, raw_model.name, "capacity")) {
                    var buf: [128]u8 = undefined;
                    const capacity_path = try Io.Dir.path.join(allocator, &[_][]const u8{ battery_path, entry.name, "capacity" });
                    _ = try Io.Dir.cwd().readFile(io, capacity_path, &buf);
                    var tok = std.mem.tokenizeSequence(u8, &buf, "\n");
                    const capacity_raw = tok.next() orelse "0";
                    const capacity = try std.fmt.parseInt(u8, capacity_raw, 10);
                    std.debug.print("current capacity: {}", .{capacity});
                    battery = Battery{ .capacity_path = capacity_path };
                    return battery;
                }
            }
        }
        return null;
    }
};

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var allocator: Allocator = undefined;
    allocator = arena.allocator();
    const argv: []const [:0]const u8 = try init.minimal.args.toSlice(allocator);

    var battery_charge_point: u32 = 20;
    if (argv.len > 1) {
        battery_charge_point = std.fmt.parseInt(u32, argv[1], 10) catch 20;
    }
    std.debug.print("{d}\n", .{battery_charge_point});
    var battery = try Battery.default(allocator, init.io);
    if (battery) |*bat| {
        _ = try bat.set_trigger_point(battery_charge_point);
    }
}
