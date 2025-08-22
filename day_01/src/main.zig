const std = @import("std");
const Tuple = std.meta.Tuple;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const puzzle = try std.fs.cwd().readFileAlloc(allocator, "puzzle.txt", 1024 * 1024);
    defer allocator.free(puzzle);

    const result = calculate(puzzle);

    std.debug.print("Result: {}\n", .{result});
}

const Answers = Tuple(&.{ u32, u32 });

fn calculate(puzzle: []const u8) Answers {
    const number_words = [_][]const u8{
        "one",
        "two",
        "three",
        "four",
        "five",
        "six",
        "seven",
        "eight",
        "nine",
    };

    var answer1: u32 = 0;
    var answer2: u32 = 0;
    var lines = std.mem.splitScalar(u8, puzzle, '\n');
    while (lines.next()) |line| {
        if (line.len == 0) {
            continue;
        }

        var setFirst = false;
        var first: u8 = 0;
        var first_location: u8 = 0;
        var last: u8 = 0;
        var last_location: u8 = 0;

        for (line, 0..) |c, index| {
            if (c >= '0' and c <= '9') {
                const digit = c - '0';
                if (!setFirst) {
                    first = digit;
                    first_location = @truncate(index);
                    setFirst = true;
                }
                last = digit;
                last_location = @truncate(index);
            }
        }

        answer1 += (first * 10) + last;

        for (number_words, 0..) |number_word, word_index| {
            const first_index = std.mem.indexOf(u8, line, number_word);
            if (first_index == null) {
                continue;
            }

            const number: u8 = @truncate(word_index + 1);
            if (first_index.? < first_location) {
                first = number;
                first_location = @truncate(first_index.?);
            }

            const last_index = std.mem.lastIndexOf(u8, line, number_word);
            if (last_index != null and last_index.? > last_location) {
                last = number;
                last_location = @truncate(last_index.?);
            }
        }

        answer2 += (first * 10) + last;
    }

    return .{ answer1, answer2 };
}

test "part 1 example input to be 142" {
    const example =
        \\1abc2
        \\pqr3stu8vwx
        \\a1b2c3d4e5f
        \\treb7uchet
    ;
    try std.testing.expect(calculate(example)[0] == 142);
}

test "part 2 example input to be 281" {
    const example =
        \\two1nine
        \\eightwothree
        \\abcone2threexyz
        \\xtwone3four
        \\4nineeightseven2
        \\zoneight234
        \\7pqrstsixteen
    ;
    try std.testing.expect(calculate(example)[1] == 281);
}
