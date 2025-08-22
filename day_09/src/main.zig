const std = @import("std");
const Tuple = std.meta.Tuple;

pub fn main() !void {
    const start = std.time.nanoTimestamp();

    const puzzle = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, "puzzle.txt", 1024 * 32);

    const result = try calculate(puzzle);

    std.debug.print("p1: {d}, p2: {d}\n", .{ result[0], result[1] });

    const end = std.time.nanoTimestamp();
    const duration_ns = end - start;
    const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;
    std.debug.print("Function took: {} ns ({d:.2} ms)\n", .{ duration_ns, duration_ms });
}

const Answers = Tuple(&.{ isize, isize });

fn calculate(puzzle: []const u8) !Answers {
    var puzzle_lines = std.mem.splitScalar(u8, puzzle, '\n');

    var result_p1: isize = 0;
    var result_p2: isize = 0;
    var numbers: [30]isize = undefined;
    while (puzzle_lines.next()) |line| {
        if (line.len == 0)
            continue;

        var number_sections = std.mem.splitScalar(u8, line, ' ');
        var number_length: u8 = 0;
        while (number_sections.next()) |number_section| {
            const number = try std.fmt.parseInt(isize, number_section, 10);
            numbers[number_length] = number;
            number_length += 1;
        }
        const results = solve(&numbers, number_length);
        result_p1 += results[1];
        result_p2 += results[0];
    }

    return .{ result_p1, result_p2 };
}

fn solve(numbers: *[30]isize, len: u8) Tuple(&.{ isize, isize }) {
    const input_first_number = numbers[0];
    var all_zeros = true;
    for (0..len - 1) |idx| {
        const diff = numbers[idx + 1] - numbers[idx];
        numbers[idx] = diff;
        if (diff != 0) {
            all_zeros = false;
        }
    }

    if (all_zeros)
        return .{ input_first_number, numbers[len - 1] };

    const left_and_right_values = solve(numbers, len - 1);
    const left_solution = input_first_number - left_and_right_values[0];
    return .{ left_solution, left_and_right_values[1] + numbers[len - 1] };
}
