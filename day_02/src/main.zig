const std = @import("std");
const Tuple = std.meta.Tuple;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const puzzle = try std.fs.cwd().readFileAlloc(allocator, "puzzle.txt", 1024 * 1024);
    defer allocator.free(puzzle);

    const result = solve(puzzle);

    std.debug.print("Result: {}\n", .{result});
}

const Answers = Tuple(&.{ u16, u32 });

fn solve(puzzle: []const u8) Answers {
    var answer_p1: u16 = 0;
    var answer_p2: u32 = 0;

    var lines = std.mem.splitScalar(u8, puzzle, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var game_id_and_data = std.mem.splitSequence(u8, line, ": ");
        const raw_game_id = game_id_and_data.next().?;
        const game_data = game_id_and_data.next().?;

        // Get game id
        var game_id_parts = std.mem.splitBackwardsScalar(u8, raw_game_id, ' ');
        const game_id = std.fmt.parseUnsigned(u8, game_id_parts.next().?, 10) catch unreachable;

        // Get game data
        var highest_green: u16 = 0;
        var highest_red: u16 = 0;
        var highest_blue: u16 = 0;
        var game_parts = std.mem.splitScalar(u8, game_data, ' ');
        var last_number: u16 = 0;
        while (game_parts.next()) |game_part| {
            switch (game_part[0]) {
                'r' => highest_red = @max(highest_red, last_number),
                'g' => highest_green = @max(highest_green, last_number),
                'b' => highest_blue = @max(highest_blue, last_number),
                '0'...'9' => last_number = std.fmt.parseUnsigned(u16, game_part, 10) catch unreachable,
                else => unreachable,
            }
        }

        if (highest_red <= 12 and highest_green <= 13 and highest_blue <= 14) {
            answer_p1 += game_id;
        }

        answer_p2 += @as(u32, highest_red) * @as(u32, highest_green) * @as(u32, highest_blue);
    }

    return .{ answer_p1, answer_p2 };
}

test "part 1 example input to be 8" {
    const example =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    try std.testing.expect(solve(example)[0] == 8);
}

test "part 2 example input to be 2286" {
    const example =
        \\Game 1: 3 blue, 4 red; 1 red, 2 green, 6 blue; 2 green
        \\Game 2: 1 blue, 2 green; 3 green, 4 blue, 1 red; 1 green, 1 blue
        \\Game 3: 8 green, 6 blue, 20 red; 5 blue, 4 red, 13 green; 5 green, 1 red
        \\Game 4: 1 green, 3 red, 6 blue; 3 green, 6 red; 3 green, 15 blue, 14 red
        \\Game 5: 6 red, 1 blue, 3 green; 2 blue, 1 red, 2 green
    ;

    try std.testing.expect(solve(example)[1] == 2286);
}
