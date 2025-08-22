const std = @import("std");
const Tuple = std.meta.Tuple;

pub fn main() !void {
    const start = std.time.nanoTimestamp();

    const puzzle = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, "puzzle.txt", 1024 * 16);

    const result = try calculate(puzzle);

    std.debug.print("p1: {d}, p2: {d}\n", .{ result[0], result[1] });

    const end = std.time.nanoTimestamp();
    const duration_ns = end - start;
    const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;
    std.debug.print("Function took: {} ns ({d:.2} ms)\n", .{ duration_ns, duration_ms });
}

const Answers = Tuple(&.{ usize, usize });

fn calculate(puzzle: []const u8) !Answers {
    var puzzle_lines = std.mem.splitScalar(u8, puzzle, '\n');

    while (puzzle_lines.next()) |line| {
        std.debug.print("{any}", .{line});
    }

    return .{ 0, 0 };
}
