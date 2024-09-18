const std = @import("std");
const print = std.debug.print;
const Allocator = std.mem.Allocator;

const Marker = enum {
    Circle,
    Cross,

    const Self = @This();

    pub fn get_other(self: Self) Self {
        return switch (self) {
            .Circle => .Cross,
            .Cross => .Circle,
        };
    }

    pub fn as_char(self: Self) u8 {
        return switch (self) {
            .Circle => 'o',
            .Cross => 'x',
        };
    }
};

const Player = struct {
    name: []const u8,
    marker: Marker,
    allocator: Allocator,

    const Self = @This();

    pub fn new(id: u8, marker: ?Marker, allocator: Allocator) !Self {
        const stdin = std.io.getStdIn().reader();

        var list = std.ArrayList(u8).init(allocator);
        defer list.deinit();

        print("Player {}, enter your name: ", .{id});
        try stdin.streamUntilDelimiter(list.writer(), '\n', null);

        const name_trimmed = std.mem.trimRight(u8, list.items, "\r");
        const name = try allocator.dupe(u8, name_trimmed);

        const m = if (marker) |m| m else blk: {
            while (true) {
                print("{s}, choose a marker, 0 -> Circle, 1: Cross: ", .{name});

                list.clearRetainingCapacity();
                try stdin.streamUntilDelimiter(list.writer(), '\n', null);

                const m = std.fmt.parseInt(u8, std.mem.trimRight(u8, list.items, "\r"), 10) catch {
                    print("Choose either 0 or 1\n", .{});
                    continue;
                };

                if (m > 1) {
                    print("Choose either 0 or 1\n", .{});
                    continue;
                }

                const res: Marker = @enumFromInt(m);
                break :blk res;
            }
        };

        return .{ .name = name, .marker = m, .allocator = allocator };
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.name);
    }

    pub fn play(self: Self) Play {
        const row = self.pick_play("row");
        const col = self.pick_play("col");

        return .{ .row = row, .col = col, .marker = self.marker };
    }

    fn pick_play(self: Self, axis: []const u8) u8 {
        const stdin = std.io.getStdIn().reader();

        var list = std.ArrayList(u8).init(self.allocator);
        defer list.deinit();

        while (true) {
            list.clearRetainingCapacity();
            print("{s}, choose a {s} to play (0, 1 or 2): ", .{ self.name, axis });
            stdin.streamUntilDelimiter(list.writer(), '\n', null) catch unreachable;
            const play_trimmed = std.mem.trimRight(u8, list.items, "\r");

            const play_val = std.fmt.parseInt(u8, play_trimmed, 10) catch {
                print("You must choose 0, 1 or 2\n", .{});
                continue;
            };

            if (play_val > 2) {
                print("You must choose 0, 1 or 2\n", .{});
                continue;
            }

            return play_val;
        }
    }
};

const Play = struct {
    row: u8,
    col: u8,
    marker: Marker,
};

const Grid = struct {
    cells: [9]?Marker,

    const Self = @This();

    pub fn new() Self {
        return .{
            .cells = [_]?Marker{null} ** 9,
        };
    }

    pub fn display(self: Self) void {
        print(" {c} | {c} | {c}\n", .{ self.print_cell(0), self.print_cell(1), self.print_cell(2) });
        print("-----------\n", .{});
        print(" {c} | {c} | {c}\n", .{ self.print_cell(3), self.print_cell(4), self.print_cell(5) });
        print("-----------\n", .{});
        print(" {c} | {c} | {c}\n", .{ self.print_cell(6), self.print_cell(7), self.print_cell(8) });
        print("\n", .{});
    }

    fn print_cell(self: Self, cell_id: u8) u8 {
        return if (self.cells[cell_id]) |marker| marker.as_char() else ' ';
    }

    pub fn play_at(self: *Self, player: *const Player) void {
        while (true) {
            const play = player.play();
            const index = play.row * 3 + play.col;

            if (self.cells[index]) |_| {
                print("Already played here, choose another cell\n", .{});
                continue;
            } else {
                self.cells[index] = play.marker;
                break;
            }
        }
    }

    pub fn check_win(self: Self) !bool {
        var buf: [3]u8 = undefined;
        _ = try std.fmt.bufPrint(&buf, "{c}{c}{c}", .{ self.print_cell(0), self.print_cell(1), self.print_cell(2) });
        if (Grid.assert_win(&buf)) return true;

        _ = try std.fmt.bufPrint(&buf, "{c}{c}{c}", .{ self.print_cell(3), self.print_cell(4), self.print_cell(5) });
        if (Grid.assert_win(&buf)) return true;

        _ = try std.fmt.bufPrint(&buf, "{c}{c}{c}", .{ self.print_cell(6), self.print_cell(7), self.print_cell(8) });
        if (Grid.assert_win(&buf)) return true;

        _ = try std.fmt.bufPrint(&buf, "{c}{c}{c}", .{ self.print_cell(0), self.print_cell(3), self.print_cell(6) });
        if (Grid.assert_win(&buf)) return true;

        _ = try std.fmt.bufPrint(&buf, "{c}{c}{c}", .{ self.print_cell(1), self.print_cell(4), self.print_cell(7) });
        if (Grid.assert_win(&buf)) return true;

        _ = try std.fmt.bufPrint(&buf, "{c}{c}{c}", .{ self.print_cell(2), self.print_cell(5), self.print_cell(3) });
        if (Grid.assert_win(&buf)) return true;

        _ = try std.fmt.bufPrint(&buf, "{c}{c}{c}", .{ self.print_cell(0), self.print_cell(4), self.print_cell(8) });
        if (Grid.assert_win(&buf)) return true;

        _ = try std.fmt.bufPrint(&buf, "{c}{c}{c}", .{ self.print_cell(2), self.print_cell(4), self.print_cell(6) });
        if (Grid.assert_win(&buf)) return true;

        return false;
    }

    fn assert_win(input: []const u8) bool {
        return std.mem.eql(u8, input, "xxx") or std.mem.eql(u8, input, "ooo");
    }
};

pub fn main() !void {
    const alloc = std.heap.page_allocator;

    print("\x1b[2J", .{}); // erase all
    print("\x1b[H", .{}); // goto upper left

    var p1 = try Player.new(1, null, alloc);
    var p2 = try Player.new(2, p1.marker.get_other(), alloc);

    defer p1.deinit();
    defer p2.deinit();

    var grid = Grid.new();
    print("\n", .{});
    grid.display();

    const players: [2]*const Player = [_]*Player{ &p1, &p2 };

    while (true) {
        for (players) |p| {
            grid.play_at(p);
            erase_grid();
            grid.display();
            if (try grid.check_win()) {
                print("{s} wins!\n", .{p.name});
                break;
            }
        }
    }
}

fn erase_grid() void {
    print("\x1b[5;0H", .{}); // line 5, col 0
    print("\x1b[J", .{}); // erase all after
}
