const std = @import("std");
const Tuple = std.meta.Tuple;

pub fn main() !void {
    const start = std.time.nanoTimestamp();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const puzzle = try std.fs.cwd().readFileAlloc(allocator, "puzzle.txt", 1024 * 1024);
    defer allocator.free(puzzle);

    const result = try calculate(puzzle);

    std.debug.print("Result: {}\n", .{result});

    const end = std.time.nanoTimestamp();
    const duration_ns = end - start;
    const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;
    std.debug.print("Function took: {} ns ({d:.2} ms)\n", .{ duration_ns, duration_ms });
}

const Answers = Tuple(&.{ usize, usize });

const Race = struct {
    time: usize,
    distance: usize,

    pub fn calculate_wins(self: Race) usize {
        var first_win: usize = 0;
        for (0..self.time) |time| {
            const distance = time * (self.time - time);
            if (distance > self.distance) {
                first_win = time;
                break;
            }
        }

        var last_win: usize = 0;
        var time_idx: usize = self.time;
        while (time_idx > 0) {
            time_idx -= 1;
            const distance = time_idx * (self.time - time_idx);
            if (distance > self.distance) {
                last_win = time_idx;
                break;
            }
        }

        return last_win - first_win + 1;
    }
};

fn calculate(puzzle: []const u8) !Answers {
    var puzzle_lines = std.mem.splitScalar(u8, puzzle, '\n');
    var times = std.mem.splitScalar(u8, puzzle_lines.next().?[10..], ' ');
    var distances = std.mem.splitScalar(u8, puzzle_lines.next().?[10..], ' ');

    var races_offset: usize = 0;
    var races: [4]Race = std.mem.zeroes([4]Race);

    var numbers_offset: usize = 0;
    var numbers: [25]u8 = std.mem.zeroes([25]u8);

    while (times.next()) |time| {
        if (time.len > 0) {
            races[races_offset].time = try std.fmt.parseUnsigned(usize, time, 10);
            races_offset += 1;
            for (time) |char| {
                numbers[numbers_offset] = char;
                numbers_offset += 1;
            }
        }
    }

    const full_time_number = try std.fmt.parseUnsigned(usize, numbers[0..numbers_offset], 10);

    races_offset = 0;
    numbers_offset = 0;
    while (distances.next()) |distance| {
        if (distance.len > 0) {
            races[races_offset].distance = try std.fmt.parseUnsigned(usize, distance, 10);
            races_offset += 1;
            for (distance) |char| {
                numbers[numbers_offset] = char;
                numbers_offset += 1;
            }
        }
    }

    const full_distance_number = try std.fmt.parseUnsigned(usize, numbers[0..numbers_offset], 10);

    var result_p1: usize = 0;
    for (races) |race| {
        if (race.distance == 0 and race.time == 0) break;

        const wins = race.calculate_wins();
        if (result_p1 == 0) {
            result_p1 = wins;
        } else {
            result_p1 *= wins;
        }
    }

    const final_race = Race{ .time = full_time_number, .distance = full_distance_number };
    const final_wins = final_race.calculate_wins();

    return .{ result_p1, final_wins };
}
