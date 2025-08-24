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

const Cord = struct {
    x: i32,
    y: i32,
};

fn calculate(puzzle: []const u8) !Answers {
    var puzzle_lines = std.mem.splitScalar(u8, puzzle, '\n');

    // Collect data
    var map_contents: [140][140]bool = undefined;
    var map_height: u8 = 0;
    var map_width: u8 = 0;

    const chunk_size = 16;
    const star_vector: @Vector(chunk_size, u8) = @splat(@as(u8, '#'));
    while (puzzle_lines.next()) |line| {
        if (line.len == 0) continue;

        // Process all full chunks using simd
        const full_chunks = line.len / chunk_size;
        for (0..full_chunks) |chunk_idx| {
            const start = chunk_idx * chunk_size;
            const chunk_data = line[start .. start + chunk_size];
            const chunk_vector: @Vector(chunk_size, u8) = chunk_data[0..chunk_size].*;
            const results = chunk_vector == star_vector;
            inline for (0..chunk_size) |idx| {
                map_contents[map_height][start + idx] = results[idx];
            }
        }

        // Process the remaining data with a simple loop
        const remaider_start = full_chunks * chunk_size;
        for (remaider_start..line.len) |idx| {
            map_contents[map_height][idx] = line[idx] == '#';
        }

        map_width = @truncate(line.len);
        map_height += 1;
    }

    // Detect empty rows
    var empty_spaces: u8 = 0;
    var row_extra_spaces: [140]u8 = undefined;
    for (0..map_height) |y| {
        var empty = true;
        for (0..map_width) |x| {
            if (map_contents[y][x]) {
                empty = false;
                break;
            }
        }

        if (empty) {
            empty_spaces += 1;
        }
        row_extra_spaces[y] = empty_spaces;
    }

    // Detect empty columns
    empty_spaces = 0;
    var column_extra_spaces: [140]u8 = undefined;
    for (0..map_width) |x| {
        var empty = true;
        for (0..map_height) |y| {
            if (map_contents[y][x]) {
                empty = false;
                break;
            }
        }

        if (empty) {
            empty_spaces += 1;
        }
        column_extra_spaces[x] = empty_spaces;
    }

    return .{
        calculate_single_score(1, map_height, map_width, map_contents, column_extra_spaces, row_extra_spaces),
        calculate_single_score(999_999, map_height, map_width, map_contents, column_extra_spaces, row_extra_spaces),
    };
}

fn calculate_single_score(
    empty_space_size: usize,
    map_height: usize,
    map_width: usize,
    map_contents: [140][140]bool,
    column_extra_spaces: [140]u8,
    row_extra_spaces: [140]u8,
) isize {
    // Write down all galaxies
    var x_galaxies: [500]i32 = undefined;
    var y_galaxies: [500]i32 = undefined;
    var galaxies_size: u16 = 0;
    for (0..map_height) |y| {
        for (0..map_width) |x| {
            if (map_contents[y][x]) {
                x_galaxies[galaxies_size] = @intCast(x + (column_extra_spaces[x] * empty_space_size));
                y_galaxies[galaxies_size] = @intCast(y + (row_extra_spaces[y] * empty_space_size));
                galaxies_size += 1;
            }
        }
    }

    // const buff_size = 200_000;
    // var ya: [buff_size]i32 = undefined;
    // var yb: [buff_size]i32 = undefined;
    // var xa: [buff_size]i32 = undefined;
    // var xb: [buff_size]i32 = undefined;
    // var total_entries: u32 = 0;

    var result: isize = 0;

    // 128 bits / 32
    const chunk_size = 4;
    const zeroes = @as(@Vector(chunk_size, i32), @splat(0));
    for (0..galaxies_size - 1) |a_idx| {
        const ax = x_galaxies[a_idx];
        const ay = y_galaxies[a_idx];

        const ax_chunk = @as(@Vector(chunk_size, i32), @splat(ax));
        const ay_chunk = @as(@Vector(chunk_size, i32), @splat(ay));

        const total_to_check = galaxies_size - (a_idx + 1);
        const total_full_chunks = total_to_check / chunk_size;
        for (0..total_full_chunks) |chunk_idx| {
            const start = a_idx + 1 + (chunk_idx * chunk_size);
            const end = start + chunk_size;
            const bx_data = x_galaxies[start..end];
            const by_data = y_galaxies[start..end];
            const bx_chunk: @Vector(chunk_size, i32) = bx_data[0..chunk_size].*;
            const by_chunk: @Vector(chunk_size, i32) = by_data[0..chunk_size].*;

            const y_raw = ay_chunk - by_chunk;
            const x_raw = ax_chunk - bx_chunk;

            const y_abs = @select(i32, y_raw < zeroes, -y_raw, y_raw);
            const x_abs = @select(i32, x_raw < zeroes, -x_raw, x_raw);

            const total = y_abs + x_abs;

            result += @reduce(.Add, total);
        }

        for (a_idx + 1 + (total_full_chunks * chunk_size)..galaxies_size) |b_idx| {
            const bx = x_galaxies[b_idx];
            const by = y_galaxies[b_idx];

            const y = abs(ay - by);
            const x = abs(ax - bx);
            result += @intCast(x + y);
        }
    }

    return result;
}

fn abs(a: i32) i32 {
    return if (a < 0) -a else a;
}
