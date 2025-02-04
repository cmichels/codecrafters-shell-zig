const std = @import("std");

const CommandType = enum { exit, echo, type, unknown };

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var buffer: [1024]u8 = undefined;
    while (true) {
        try stdout.print("$ ", .{});
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        var commands = std.mem.splitScalar(u8, user_input, ' ');
        const command = commands.first();

        const args = commands.rest();
        const command_type = getCommand(command);

        try switch (command_type) {
            .exit => handleExit(args),
            .echo => handleEcho(args, stdout),
            .type => handleType(args, stdout),
            else => stdout.print("{s}: command not found\n", .{command}),
        };
    }
}

fn getCommand(cmd: []const u8) CommandType {
    return std.meta.stringToEnum(CommandType, cmd) orelse CommandType.unknown;
}

fn handleExit(args: []const u8) !void {
    const exit_code = std.fmt.parseInt(u8, args, 10) catch |err| switch (err) {
        else => 0,
    };
    std.process.exit(exit_code);
}

fn handleEcho(args: []const u8, out: anytype) !void {
    try out.print("{s}\n", .{args});
}
fn handleType(cmd: []const u8, out: anytype) !void {
    const command_type = getCommand(cmd);
    try switch (command_type) {
        .exit => out.print("{s} is a shell builtin\n", .{cmd}),
        .echo => out.print("{s} is a shell builtin\n", .{cmd}),
        .type => out.print("{s} is a shell builtin\n", .{cmd}),
        else => handleExecutable(cmd, out),
    };
}

fn handleExecutable(cmd: []const u8, out: anytype) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const path_env = std.process.getEnvVarOwned(allocator, "PATH") catch |err| switch (err) {
        else => "",
    };
    defer allocator.free(path_env);

    var paths = std.mem.splitScalar(u8, path_env, ':');

    while (paths.next()) |path| {
        const file_path = std.fs.path.join(allocator, &[_][]const u8{ path, cmd }) catch continue;
        defer allocator.free(file_path);

        const file = std.fs.openFileAbsolute(file_path, .{ .mode = .read_only }) catch continue;
        defer file.close();

        const mode = file.mode() catch continue;

        const is_executable = mode & 0b001 != 0;
        // The last bit (0b001) represents the execute permission.
        if (!is_executable) continue;
        try out.print("{s} is {s}\n", .{ cmd, path });
        return;
    }

    try out.print("{s}: not found", .{cmd});
}
