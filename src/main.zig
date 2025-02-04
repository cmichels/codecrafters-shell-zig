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
            .exit => builtinExit(args),
            .echo => builtinEcho(args, stdout),
            .type => builtinType(args, stdout),
            else => handleExecutable(command, args, stdout),
        };
    }
}

fn getCommand(cmd: []const u8) CommandType {
    return std.meta.stringToEnum(CommandType, cmd) orelse CommandType.unknown;
}

fn builtinExit(args: []const u8) !void {
    const exit_code = std.fmt.parseInt(u8, args, 10) catch |err| switch (err) {
        else => 0,
    };
    std.process.exit(exit_code);
}

fn builtinEcho(args: []const u8, out: anytype) !void {
    try out.print("{s}\n", .{args});
}
fn builtinType(cmd: []const u8, out: anytype) !void {
    const command_type = getCommand(cmd);
    try switch (command_type) {
        .exit => out.print("{s} is a shell builtin\n", .{cmd}),
        .echo => out.print("{s} is a shell builtin\n", .{cmd}),
        .type => out.print("{s} is a shell builtin\n", .{cmd}),
        else => handleExecutableType(cmd, out),
    };
}

fn handleExecutableType(cmd: []const u8, out: anytype) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const file_path = getExecutable(allocator, cmd) catch {
        try out.print("{s}: not found\n", .{cmd});
        return;
    };
    defer allocator.free(file_path);

    try out.print("{s} is {s}\n", .{ cmd, file_path });
}

fn handleExecutable(cmd: []const u8, args: []const u8, out: anytype) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const file_path = getExecutable(allocator, cmd) catch {
        try out.print("{s}: not found\n", .{cmd});
        return;
    };
    defer allocator.free(file_path);

    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    try argv.append(cmd);
    if (args.len > 0) {
        try argv.append(args);
    }

    var child = std.process.Child.init(argv.items, allocator);
    _ = try child.spawnAndWait();
}

fn getExecutable(allocator: std.mem.Allocator, cmd: []const u8) ![]const u8 {
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
        return allocator.dupe(u8, file_path);
    }
    return error.FileNotFound;
}
