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

const MapEntry = struct {
    destination: usize,
    source: usize,
    range: usize,

    pub fn is_zero(self: MapEntry) bool {
        return self.destination == 0 and self.source == 0 and self.range == 0;
    }
};

const LookupTable = [50]MapEntry;

const Range = struct {
    start: usize,
    length: usize,
};

fn calculate(puzzle: []const u8) !Answers {
    var initial_numbers_offset: u6 = 0;
    var initial_numbers: [20]usize = std.mem.zeroes([20]usize);

    var table_index: u6 = 0;
    var tables: [7]LookupTable = std.mem.zeroes([7]LookupTable);

    var lines = std.mem.splitScalar(u8, puzzle, '\n');

    // Parse the header
    const header = lines.next().?;
    var header_tokens = std.mem.splitScalar(u8, header, ' ');
    while (header_tokens.next()) |token| {
        if (token.len > 0 and token[0] >= '0' and token[0] <= '9') {
            const initial_number = parse_unsigned(token);
            initial_numbers[initial_numbers_offset] = initial_number;
            initial_numbers_offset += 1;
        }
    }

    // Parse the tables
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        if (line[0] >= 'a' and line[0] <= 'z') {
            // Start a new section
            table_index += 1;
            continue;
        }

        var tokens = std.mem.splitScalar(u8, line, ' ');
        const destination = parse_unsigned(tokens.next().?);
        const source = parse_unsigned(tokens.next().?);
        const range = parse_unsigned(tokens.next().?);

        var last_table = tables[table_index - 1];

        // Find an empty row to place the new data inside of
        for (last_table, 0..) |row, index| {
            if (row.is_zero()) {
                last_table[index] = MapEntry{
                    .destination = destination,
                    .source = source,
                    .range = range,
                };
                break;
            }
        }

        tables[table_index - 1] = last_table;
    }

    // Resolve part 1
    var part_1_numbers: [20]usize = undefined;
    std.mem.copyForwards(usize, &part_1_numbers, &initial_numbers);

    for (tables) |table| {
        for (part_1_numbers, 0..) |number, index| {
            if (number == 0) break;

            for (table) |map| {
                if (!map.is_zero() and number >= map.source and number <= map.source + map.range) {
                    part_1_numbers[index] = number + map.destination - map.source;
                    break;
                }
            }
        }
    }

    var lowest_number_p1: usize = 0;
    for (part_1_numbers) |number| {
        if (number == 0) continue;
        if (lowest_number_p1 == 0 or number < lowest_number_p1) {
            lowest_number_p1 = number;
        }
    }

    // Resolve part 2
    var part_2_ranges = std.ArrayList(Range).init(std.heap.page_allocator);
    for (0..initial_numbers_offset / 2) |i| {
        const start = initial_numbers[i * 2];
        const length = initial_numbers[i * 2 + 1];
        try part_2_ranges.append(Range{ .start = start, .length = length });
    }

    var ranges_todo = std.ArrayList(Range).init(std.heap.page_allocator);
    defer ranges_todo.deinit();

    for (tables) |table| {
        const total_ranges = part_2_ranges.items.len;
        for (0..total_ranges) |idx| {
            try ranges_todo.resize(0);
            try ranges_todo.append(part_2_ranges.items[idx]);

            outer: while (ranges_todo.pop()) |range| {
                if (range.length == 0) continue;

                const range_start: usize = range.start;
                const range_end: usize = range_start + range.length;

                for (table) |map| {
                    // Check if the map has overlap with the range
                    const map_start: usize = map.source;
                    const map_end: usize = map_start + map.range;

                    if (map_start <= range_start and map_end >= range_end) {
                        // map has full overlap with the range, this is great!
                        //   |-------|   <- range
                        // |-----------| <- map

                        try part_2_ranges.append(Range{
                            .start = range.start + map.destination - map.source,
                            .length = range.length,
                        });
                        continue :outer;
                    } else if (map_start <= range_start and map_end >= range_start) {
                        // map has overlap with the start of the range
                        //   |-------| <- range
                        // |-----|     <- map

                        const new_length = map_end - range_start;
                        if (new_length > 0) {
                            try part_2_ranges.append(Range{
                                .start = range.start + map.destination - map.source,
                                .length = new_length,
                            });
                            try ranges_todo.append(Range{
                                .start = map.source + map.range,
                                .length = range.length - new_length,
                            });
                            continue :outer;
                        }
                    } else if (map_start <= range_end and map_end >= range_end) {
                        // map has overlap with the end of the range
                        // |-------|    <- range
                        //    |-------| <- map

                        const new_length = map_start - range_start;
                        if (new_length > 0 and new_length < range.length) {
                            try ranges_todo.append(Range{
                                .start = range.start,
                                .length = new_length,
                            });
                            try part_2_ranges.append(Range{
                                .start = map.destination,
                                .length = range.length - new_length,
                            });
                            continue :outer;
                        }
                    } else if (range_start <= map_start and map_end <= range_end) {
                        // range has fully overlap with the map
                        // |-----------| <- range
                        //   |-------|   <- map

                        // Before map
                        try ranges_todo.append(Range{
                            .start = range.start,
                            .length = map_start - range.start,
                        });

                        // Coverage with map
                        try part_2_ranges.append(Range{
                            .start = map.destination,
                            .length = map.range,
                        });

                        // After map
                        try ranges_todo.append(Range{
                            .start = range.start + map.range,
                            .length = range_end - map_end,
                        });
                        continue :outer;
                    } else if (range_start <= map_end and map_start <= range_end) {
                        std.debug.print("range: {d}-{d}\n", .{ range_start, range_end });
                        std.debug.print("  map: {d}-{d}\n", .{ map_start, map_end });
                        unreachable;
                    }
                }

                // No overlap with any map
                try part_2_ranges.append(range);
            }
        }

        try part_2_ranges.replaceRange(0, total_ranges, &[_]Range{});
    }

    var lowest_number_p2: usize = 0;
    for (part_2_ranges.items) |range| {
        if (lowest_number_p2 == 0 or range.start < lowest_number_p2) {
            lowest_number_p2 = range.start;
        }
    }

    part_2_ranges.deinit();

    return .{ lowest_number_p1, lowest_number_p2 };
}

fn parse_unsigned(token: []const u8) usize {
    return std.fmt.parseUnsigned(usize, token, 10) catch unreachable;
}
