const std = @import("std");
const Tuple = std.meta.Tuple;

pub fn main() !void {
    const start = std.time.nanoTimestamp();

    const puzzle = try std.fs.cwd().readFileAlloc(std.heap.page_allocator, "puzzle.txt", 1024 * 32);

    const result = try calculate(puzzle);

    std.debug.print("p1: {d}, p2: {d}\n", .{ result[0], result[1] });
    _ = print_duration(start, "main");
}

fn print_duration(start: i128, hint: []const u8) i128 {
    const end = std.time.nanoTimestamp();
    const duration_ns = end - start;
    const duration_ms = @as(f64, @floatFromInt(duration_ns)) / 1_000_000.0;
    std.debug.print("{s} took: {} ns ({d:.2} ms)\n", .{ hint, duration_ns, duration_ms });

    return std.time.nanoTimestamp();
}

const Answers = Tuple(&.{ u16, usize });

const Direction = enum(u3) {
    up,
    right,
    down,
    left,
};

const Cursor = struct {
    point: Point,
    total_visited: u16,
    source_direction: Direction,

    fn goto(self: Cursor, to: Direction) Cursor {
        return switch (to) {
            Direction.up => Cursor{
                .point = Point{ .x = self.point.x, .y = self.point.y - 1 },
                .total_visited = self.total_visited + 1,
                .source_direction = Direction.up,
            },
            Direction.right => Cursor{
                .point = Point{ .x = self.point.x + 1, .y = self.point.y },
                .total_visited = self.total_visited + 1,
                .source_direction = Direction.right,
            },
            Direction.down => Cursor{
                .point = Point{ .x = self.point.x, .y = self.point.y + 1 },
                .total_visited = self.total_visited + 1,
                .source_direction = Direction.down,
            },
            Direction.left => Cursor{
                .point = Point{ .x = self.point.x - 1, .y = self.point.y },
                .total_visited = self.total_visited + 1,
                .source_direction = Direction.left,
            },
        };
    }

    fn next(self: Cursor, map: *Map) ?Cursor {
        // Check if the point is a valid coordinate on the map
        if (!map.valid_cord(self.point)) return null;

        const x: usize = @intCast(self.point.x);
        const y: usize = @intCast(self.point.y);
        if (map.visited[y][x]) return null;

        const tail_data = map.data[y][x];
        const next_cursor = switch (tail_data) {
            '|' => switch (self.source_direction) {
                Direction.up, Direction.down => self.goto(self.source_direction),
                else => null,
            },
            '-' => switch (self.source_direction) {
                Direction.left, Direction.right => self.goto(self.source_direction),
                else => null,
            },
            'L' => switch (self.source_direction) {
                Direction.down => self.goto(Direction.right),
                Direction.left => self.goto(Direction.up),
                else => null,
            },
            'J' => switch (self.source_direction) {
                Direction.down => self.goto(Direction.left),
                Direction.right => self.goto(Direction.up),
                else => null,
            },
            '7' => switch (self.source_direction) {
                Direction.up => self.goto(Direction.left),
                Direction.right => self.goto(Direction.down),
                else => null,
            },
            'F' => switch (self.source_direction) {
                Direction.up => self.goto(Direction.right),
                Direction.left => self.goto(Direction.down),
                else => null,
            },
            else => {
                // Not a valid position
                return null;
            },
        };

        if (next_cursor == null) return null;

        map.visited[y][x] = true;
        return next_cursor;
    }
};

const Point = struct {
    x: i9,
    y: i9,
};

const Map = struct {
    data: [140][140]u8,
    visited: [140][140]bool,
    size: Point,

    fn valid_cord(self: Map, point: Point) bool {
        if (point.x < 0 or point.y < 0) return false;
        if (point.x >= self.size.x or point.y >= self.size.y) return false;
        return true;
    }
};

fn calculate(puzzle_input: []const u8) !Answers {
    var timer = std.time.nanoTimestamp();
    var puzzle_lines = std.mem.splitScalar(u8, puzzle_input, '\n');

    var map: Map = Map{
        .data = undefined,
        .visited = std.mem.zeroes([140][140]bool),
        .size = .{ .x = 0, .y = 0 },
    };
    var start: Point = .{ .x = 0, .y = 0 };
    while (puzzle_lines.next()) |line| {
        if (line.len == 0) continue;

        for (line, 0..) |c, x| {
            if (c == 'S') {
                start.x = @intCast(x);
                start.y = @intCast(map.size.y);
            }
            map.data[@intCast(map.size.y)][x] = c;
        }

        map.size.x = @intCast(line.len);
        map.size.y += 1;
    }

    timer = print_duration(timer, "map initialization");

    // Detect all directions where we can go to
    var total_cursors: u8 = 0;
    var cursors: [4]Cursor = undefined;

    const potential_start_cursors: [4]Cursor = [4]Cursor{
        // Up
        .{
            .point = .{ .x = start.x, .y = start.y - 1 },
            .total_visited = 1,
            .source_direction = Direction.up,
        },
        // Down
        .{
            .point = .{ .x = start.x, .y = start.y + 1 },
            .total_visited = 1,
            .source_direction = Direction.down,
        },
        // Left
        .{
            .point = .{ .x = start.x - 1, .y = start.y },
            .total_visited = 1,
            .source_direction = Direction.left,
        },
        // Right
        .{
            .point = .{ .x = start.x + 1, .y = start.y },
            .total_visited = 1,
            .source_direction = Direction.right,
        },
    };
    for (potential_start_cursors) |cursor| {
        if (cursor.next(&map)) |next_cursor| {
            cursors[total_cursors] = next_cursor;
            total_cursors += 1;
        }
    }

    // Follow the pipes
    var total_distance: u16 = 1;
    var some_cursors_valid = true;
    while (some_cursors_valid) {
        some_cursors_valid = false;
        for (0..total_cursors) |idx| {
            if (cursors[idx].next(&map)) |next_cursor| {
                some_cursors_valid = true;
                cursors[idx] = next_cursor;
            }
        }
        if (some_cursors_valid) {
            total_distance += 1;
        }
    }

    timer = print_duration(timer, "following pipes");

    // Raycast for the areas
    var inside_count: usize = 0;
    for (1..@intCast(map.size.y - 1)) |y| {
        var inside = false;

        var max: usize = @intCast(map.size.x);
        const map_x: usize = @intCast(map.size.x);
        for (0..@intCast(map.size.x)) |base_x| {
            if (map.visited[y][map_x - base_x - 1]) break;
            max -= 1;
        }

        for (0..max) |x| {
            const is_visited_pipe = map.visited[y][x];
            if (is_visited_pipe) {
                switch (map.data[y][x]) {
                    '|', 'L', 'J' => {
                        inside = !inside;
                    },
                    else => {},
                }
                continue;
            }

            if (inside) {
                inside_count += 1;
            }
        }
    }

    _ = print_duration(timer, "ray casting");

    return .{ total_distance, inside_count };
}
