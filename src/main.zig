const std = @import("std");

pub fn main() !void {
    // Uncomment this block to pass the first stage
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var buffer: [1024]u8 = undefined;
    while (true) {
        try stdout.print("$ ", .{});
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        var commands = std.mem.splitScalar(u8, user_input, ' ');
        const command = commands.first();

        const args = commands.rest();

        if (std.mem.eql(u8, command, "exit")) {
            try handleExit(args);
        } else if (std.mem.eql(u8, command, "echo")) {
            try handleEcho(args, stdout);
        } else if (std.mem.eql(u8, command, "type")) {
            try handleType(args, stdout);
        } else {
            try stdout.print("{s}: command not found\n", .{command});
        }
    }
}

fn handleExit(args: []const u8) !void {
    const exit_code = try std.fmt.parseInt(u8, args, 10);
    std.process.exit(exit_code);
}

fn handleEcho(args: []const u8, out: anytype) !void {
    try out.print("{s}\n", .{args});
}
fn handleType(cmd: []const u8, out: anytype) !void {
    const CommandType = enum { exit, echo, type, unknown };
    const command_type = std.meta.stringToEnum(CommandType, cmd) orelse CommandType.unknown;
    try switch (command_type) {
        .exit => out.print("{s} is a shell builtin\n", .{cmd}),
        .echo => out.print("{s} is a shell builtin\n", .{cmd}),
        .type => out.print("{s} is a shell builtin\n", .{cmd}),
        else => out.print("{s}: not found\n", .{cmd}),
    };
}
