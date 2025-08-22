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

const Answers = Tuple(&.{ usize, usize });

const PointsAndMultiplier = struct {
    matches: usize,
    multiplier: usize,
};

fn calculate(puzzle: []const u8) Answers {
    var lines = std.mem.splitScalar(u8, puzzle, '\n');

    var points_per_card_offset: u8 = 0;
    var points_per_card: [230]?PointsAndMultiplier = std.mem.zeroes([230]?PointsAndMultiplier);
    var total_points: usize = 0;
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        const matches = card_points(line);

        points_per_card[points_per_card_offset] = PointsAndMultiplier{ .matches = matches, .multiplier = 1 };
        points_per_card_offset += 1;

        if (matches > 0) total_points += @as(usize, 1) << @truncate(matches - 1);
    }

    var total_points_p2: usize = 0;
    for (0..points_per_card_offset) |idx| {
        const card = points_per_card[idx];
        if (card == null) break;

        total_points_p2 += card.?.multiplier;
        for (idx + 1..idx + 1 + card.?.matches) |sub_idx| {
            var needle_card = points_per_card[sub_idx];
            if (needle_card == null) break;

            needle_card.?.multiplier += card.?.multiplier;

            points_per_card[sub_idx] = needle_card.?;
        }
    }

    return .{ total_points, total_points_p2 };
}

fn points_for_range(cards: *[230]?usize, start: usize, end: usize) usize {
    var total: usize = 0;
    for (start..end) |idx| {
        if (cards[idx]) |points| {
            total += points;
            if (points > 0) {
                total += points_for_range(cards, idx + 1, idx + points + 1);
            }
        } else {
            break;
        }
    }

    return total;
}

fn card_points(card: []const u8) usize {
    var parts = std.mem.splitScalar(u8, card, ':');
    _ = parts.next();
    const puzzle_data = parts.next().?;
    parts = std.mem.splitScalar(u8, puzzle_data, '|');

    const price_data = parts.next().?;
    const our_numbers_data = parts.next().?;

    var prices: [10]u8 = [10]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    var price_offset: usize = 0;
    parts = std.mem.splitScalar(u8, price_data, ' ');
    while (parts.next()) |price_str| {
        if (price_str.len == 0) continue;
        const price = std.fmt.parseUnsigned(u8, price_str, 10) catch unreachable;
        prices[price_offset] = price;
        price_offset += 1;
    }

    var our_numbers: [25]u8 = [25]u8{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
    var our_numbers_offset: usize = 0;
    parts = std.mem.splitScalar(u8, our_numbers_data, ' ');
    while (parts.next()) |number_str| {
        if (number_str.len == 0) continue;
        const our_number = std.fmt.parseUnsigned(u8, number_str, 10) catch unreachable;
        our_numbers[our_numbers_offset] = our_number;
        our_numbers_offset += 1;
    }

    var matches: usize = 0;
    for (our_numbers) |number| {
        if (number == 0) break;

        for (prices) |price| {
            if (price == 0) break;
            if (number == price) {
                matches += 1;
            }
        }
    }

    return matches;
}
