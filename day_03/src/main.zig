const std = @import("std");
const Tuple = std.meta.Tuple;
const Slice = std.ArrayList(u8);

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const puzzle = try std.fs.cwd().readFileAlloc(allocator, "puzzle.txt", 1024 * 1024);
    defer allocator.free(puzzle);

    const result = solve(puzzle);

    std.debug.print("Result: {}\n", .{result});
}

const Answers = Tuple(&.{ u32, u32 });

fn solve(puzzle: []const u8) Answers {
    // Firstly lets map the puzzle input to a 2d array
    var map: [150][150]u8 = std.mem.zeroes([150][150]u8);
    var found_numbers: [150][150]u32 = std.mem.zeroes([150][150]u32);
    var line_number: usize = 0;
    var x_offset: usize = 0;
    for (puzzle, 0..) |c, idx| {
        if (c == '\n') {
            line_number += 1;
            x_offset = idx + 1;
            continue;
        }
        map[line_number][idx - x_offset] = c;
    }

    // Find part numbers in the puzzle input
    var buffer: [1000]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buffer);
    const allocator = fba.allocator();

    var last_number = Slice.init(allocator);
    defer last_number.deinit();
    var has_symbol: bool = false;
    var part_1: u32 = 0;

    for (map, 0..) |line, y| {
        if (line[0] == 0) {
            break;
        }

        for (line, 0..) |c, x| {
            if (c >= '0' and c <= '9') {
                last_number.append(c) catch unreachable;

                // Check if the tails around the number are symbols
                const found_symbol = tail_has_symbol_on_side(&map, x, y);
                if (found_symbol != null) {
                    has_symbol = true;
                }
            } else if (last_number.items.len > 0) {
                // Add the number to the list of numbers
                const number = std.fmt.parseUnsigned(u32, last_number.items, 10) catch unreachable;
                if (has_symbol) {
                    part_1 += number;
                }

                for (0..last_number.items.len) |offset| {
                    found_numbers[y][x - 1 - offset] = number;
                }

                last_number.resize(0) catch unreachable;
                has_symbol = false;
            }

            if (c == 0) {
                break;
            }
        }
    }

    var part_2: u32 = 0;
    for (map, 0..) |line, y| {
        if (line[0] == 0) {
            break;
        }

        for (line, 0..) |c, x| {
            if (c == 0) {
                break;
            }

            if (c == '*') {
                // Check if both sides have numbers
                part_2 += check_has_numbers_on_sides(&found_numbers, x, y);
            }
        }
    }

    return .{ part_1, part_2 };
}

fn is_digit(c: u8) bool {
    return c >= '0' and c <= '9';
}

fn is_special_character(symbol: u8) bool {
    return symbol != '.' and (symbol < '0' or symbol > '9') and symbol != 0;
}

const FoundSymbol = struct {
    x: usize,
    y: usize,
    is_gear: bool,
};

fn tail_has_symbol_on_side(map: *[150][150]u8, x: usize, y: usize) ?FoundSymbol {
    var symbol: u8 = 0;

    if (x > 0) {
        // Check left
        symbol = map[y][x - 1];
        if (is_special_character(symbol)) {
            return FoundSymbol{
                .x = x - 1,
                .y = y,
                .is_gear = symbol == '*',
            };
        }

        // Check left-bottom
        symbol = map[y + 1][x - 1];
        if (is_special_character(symbol)) {
            return FoundSymbol{
                .x = x - 1,
                .y = y + 1,
                .is_gear = symbol == '*',
            };
        }
    }

    // Check right
    symbol = map[y][x + 1];
    if (is_special_character(symbol)) {
        return FoundSymbol{
            .x = x + 1,
            .y = y,
            .is_gear = symbol == '*',
        };
    }

    if (y > 0) {
        // Check top
        symbol = map[y - 1][x];
        if (is_special_character(symbol)) {
            return FoundSymbol{
                .x = x,
                .y = y - 1,
                .is_gear = symbol == '*',
            };
        }

        // Check top-right
        symbol = map[y - 1][x + 1];
        if (is_special_character(symbol)) {
            return FoundSymbol{
                .x = x + 1,
                .y = y - 1,
                .is_gear = symbol == '*',
            };
        }
    }

    // Check bottom
    symbol = map[y + 1][x];
    if (is_special_character(symbol)) {
        return FoundSymbol{
            .x = x,
            .y = y + 1,
            .is_gear = symbol == '*',
        };
    }

    // Check top-left
    if (x > 0 and y > 0) {
        symbol = map[y - 1][x - 1];
        if (is_special_character(symbol)) {
            return FoundSymbol{
                .x = x - 1,
                .y = y - 1,
                .is_gear = symbol == '*',
            };
        }
    }

    // Check bottom-right
    symbol = map[y + 1][x + 1];
    if (is_special_character(symbol)) {
        return FoundSymbol{
            .x = x + 1,
            .y = y + 1,
            .is_gear = symbol == '*',
        };
    }

    return null;
}

fn check_has_numbers_on_sides(map: *[150][150]u32, x: usize, y: usize) u32 {
    var top_left: u32 = 0;
    var top: u32 = 0;
    var top_right: u32 = 0;
    var left: u32 = 0;
    var right: u32 = 0;
    var bottom_left: u32 = 0;
    var bottom: u32 = 0;
    var bottom_right: u32 = 0;

    if (y > 0 and x > 0) {
        top_left = map[y - 1][x - 1];
    }
    if (y > 0) {
        top = map[y - 1][x];
        top_right = map[y - 1][x + 1];
    }
    if (x > 0) {
        left = map[y][x - 1];
        bottom_left = map[y + 1][x - 1];
    }
    right = map[y][x + 1];
    bottom = map[y + 1][x];
    bottom_right = map[y + 1][x + 1];

    var unique_values_count: u2 = 0;
    var unique_values: [2]u32 = [2]u32{ 0, 0 };

    var horizontal_side_value = [_]u32{ top_left, top, top_right };
    var last_value: u32 = 0;
    for (horizontal_side_value) |value| {
        if (value == 0 or value == last_value) {
            continue;
        }
        if (unique_values_count == 2) {
            return 0;
        }
        last_value = value;
        unique_values[unique_values_count] = value;
        unique_values_count += 1;
    }

    horizontal_side_value = [_]u32{ bottom_left, bottom, bottom_right };
    last_value = 0;
    for (horizontal_side_value) |value| {
        if (value == 0 or value == last_value) {
            continue;
        }
        if (unique_values_count == 2) {
            return 0;
        }
        last_value = value;
        unique_values[unique_values_count] = value;
        unique_values_count += 1;
    }

    if (left > 0) {
        if (unique_values_count == 2) {
            return 0;
        }
        unique_values[unique_values_count] = left;
        unique_values_count += 1;
    }
    if (right > 0) {
        if (unique_values_count == 2) {
            return 0;
        }
        unique_values[unique_values_count] = right;
        unique_values_count += 1;
    }

    if (unique_values_count != 2) {
        return 0;
    }

    return unique_values[0] * unique_values[1];
}

test "solve on example input" {
    const example =
        \\467..114..
        \\...*......
        \\..35..633.
        \\......#...
        \\617*......
        \\.....+.58.
        \\..592.....
        \\......755.
        \\...$.*....
        \\.664.598..
    ;

    const result = solve(example);
    try std.testing.expect(result[0] == 4361);
    try std.testing.expect(result[1] == 467835);
}
