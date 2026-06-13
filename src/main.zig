const std = @import("std");
const Io = std.Io;
const Allocator = std.mem.Allocator;

const Battery = struct {
    battery_charge_point: u32 = 20,
    current_capacity: u32 = undefined,
    capacity: u32 = undefined,
    action: *const fn (u32, u32, u32) void = undefined,

    /// Sets the trigger actuation point and returns pointer to battery
    pub fn set_trigger_point(bat: *Battery, point: u32) !*Battery {
        if (point > bat.capacity) return error.InvalidPoint;
        bat.battery_charge_point = point;
        return bat;
    }

    /// Sets trigger action and returns pointer to battery
    pub fn on_trigger(bat: *Battery, f: fn (u32, u32, u32) void) *Battery {
        bat.action = f;
        return bat;
    }

    /// Sets the capacity and returns pointer to battery
    pub fn set_capacity(bat: *Battery, c: u32) *Battery {
        bat.capacity = c;
        return bat;
    }

    /// Auto field filling.
    /// Returns Battery
    pub fn default(allocator: Allocator, io: Io) !void {
        const battery_path = "/sys/class/power_supply";
        const dir = try Io.Dir.cwd().openDir(io, battery_path, .{ .iterate = true });
        defer dir.close(io);

        var power_supply_iter = dir.iterate();

        while (try power_supply_iter.next(io)) |entry| {
            std.debug.print("power_supply_iter {s}, {}\n", .{ entry.name, entry.inode });
            const parts = [_][]const u8{ battery_path, entry.name };
            const subdirectory_path = try std.Io.Dir.path.join(allocator, &parts);
            const power_supply_subdirectory = try Io.Dir.cwd().openDir(io, subdirectory_path, .{ .iterate = true });
            defer power_supply_subdirectory.close(io);

            var power_supply_subdirectory_iter = power_supply_subdirectory.iterate();
            while (try power_supply_subdirectory_iter.next(io)) |raw_model| {
                std.debug.print("power_supply_subdirectory_iter {s}\n", .{raw_model.name});
                if (raw_model.kind == .file) {}
            }
        }
    }
};

pub fn main(init: std.process.Init) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var allocator: Allocator = undefined;
    allocator = arena.allocator();
    const argv: []const [:0]const u8 = try init.minimal.args.toSlice(allocator);

    const battery_charge_point: i32 = try std.fmt.parseInt(i32, argv[1], 10);
    std.debug.print("{d}\n", .{battery_charge_point});
    try Battery.default(allocator, init.io);
}
