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

const Answers = Tuple(&.{ u16, usize });
const LeftRight = Tuple(&.{ [3]u8, [3]u8 });
const NodeNeedle = struct {
    id: [3]u8,
    last_match: usize,
    match_len: usize,
};

fn calculate(puzzle: []const u8) !Answers {
    var lines = std.mem.splitScalar(u8, puzzle, '\n');

    const instructions = lines.next().?;

    var network = std.AutoHashMap([3]u8, LeftRight).init(std.heap.page_allocator);
    var node_needles = std.ArrayList(NodeNeedle).init(std.heap.page_allocator);
    while (lines.next()) |line| {
        if (line.len == 0) continue;

        var id: [3]u8 = undefined;
        var left: [3]u8 = undefined;
        var right: [3]u8 = undefined;

        @memcpy(&id, line[0..3]);
        @memcpy(&left, line[7..10]);
        @memcpy(&right, line[12..15]);

        if (id[2] == 'A') {
            try node_needles.append(NodeNeedle{
                .id = id,
                .last_match = 0,
                .match_len = 0,
            });
        }

        try network.put(id, .{ left, right });
    }

    var start: [3]u8 = undefined;
    @memcpy(&start, "AAA");

    const might_start_node = network.get(start); // in the second example there is no AAA start point
    var part_1_hops: u16 = 0;
    if (might_start_node != null) {
        var node = might_start_node.?;
        var target_node: [3]u8 = undefined;
        outer: while (true) {
            for (instructions) |instruction| {
                part_1_hops += 1;
                if (instruction == 'L') {
                    target_node = node[0];
                } else {
                    target_node = node[1];
                }
                if (target_node[0] == 'Z' and target_node[1] == 'Z' and target_node[2] == 'Z') {
                    break :outer;
                }

                node = network.get(target_node).?;
            }
        }
    }

    var part_2_hops: usize = 0;
    outer: while (true) {
        for (instructions) |instruction| {
            part_2_hops += 1;
            var number_of_nodes_ending_with_z: u8 = 0;
            for (node_needles.items, 0..) |needle, index| {
                const node = network.get(needle.id).?;
                var new_node = node[0];
                if (instruction == 'R') {
                    new_node = node[1];
                }

                if (new_node[2] == 'Z') {
                    number_of_nodes_ending_with_z += 1;
                    const new_last_match = part_2_hops;
                    node_needles.items[index] = NodeNeedle{
                        .id = new_node,
                        .last_match = new_last_match,
                        .match_len = new_last_match - needle.last_match,
                    };
                } else {
                    node_needles.items[index] = NodeNeedle{
                        .id = new_node,
                        .last_match = needle.last_match,
                        .match_len = needle.match_len,
                    };
                }
            }

            if (number_of_nodes_ending_with_z == node_needles.items.len) {
                break :outer;
            } else if (number_of_nodes_ending_with_z == 0) {
                continue;
            }

            var all_have_matches = true;
            for (node_needles.items) |needle| {
                if (needle.match_len == 0) {
                    all_have_matches = false;
                    break;
                }
            }

            if (all_have_matches) {
                break :outer;
            }
        }
    }

    while (true) {
        var lowest_number = node_needles.items[0].last_match;
        var lowest_number_index: u6 = 0;
        var equal_numbers: u6 = 0;
        for (1..node_needles.items.len) |idx| {
            const needle = node_needles.items[idx];
            if (needle.last_match < lowest_number) {
                lowest_number = needle.last_match;
                lowest_number_index = @truncate(idx);
            } else if (needle.last_match == lowest_number) {
                equal_numbers += 1;
            }
        }

        if (equal_numbers == node_needles.items.len - 2) {
            part_2_hops = lowest_number;
            break;
        }

        var lowest_node = node_needles.items[lowest_number_index];
        lowest_node.last_match += lowest_node.match_len;
        node_needles.items[lowest_number_index] = lowest_node;
    }

    return .{ part_1_hops, part_2_hops };
}
