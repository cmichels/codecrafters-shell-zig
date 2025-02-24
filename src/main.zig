const std = @import("std");

const CommandType = enum { exit, echo, type, pwd, cd, unknown };

pub fn main() !void {
    const stdout: std.fs.File.Writer = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var buffer: [1024]u8 = undefined;
    while (true) {
        try stdout.print("$ ", .{});
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        const allocator = arena.allocator();
        const commands = try parseCommands(allocator, user_input);
        defer commands.deinit();
        const command = commands.items[0];
        const command_type = getCommand(command);
        const args = commands.items[1..];

        try switch (command_type) {
            .exit => builtinExit(args),
            .echo => builtinEcho(allocator, args, stdout),
            .type => builtinType(args[0], stdout),
            .pwd => builtinPwd(allocator, stdout),
            .cd => builtinCd(allocator, args[0], stdout),
            else => handleExecutable(allocator, command, args, stdout),
        };
    }
}

fn parseCommands(allocator: std.mem.Allocator, user_input: []const u8) !std.ArrayList([]const u8) {
    var tokens = std.mem.splitScalar(u8, user_input, ' ');
    var commands = std.ArrayList([]const u8).init(allocator);
    const remaining = tokens.rest();
    var commandBuffer = std.ArrayList(u8).init(allocator);
    defer commandBuffer.deinit();

    var in_quote = false;
    var in_double_quote = false;
    var escaped = false;
    for (remaining, 0..) |token, index| {

        // encountered a space outside of a quoted section
        // signalling the end of an arg
        if (token == ' ' and !in_quote and !in_double_quote and !escaped) {
            //buffer has args and should be flushed
            if (commandBuffer.items.len > 0) {
                // convert memory ownershipt to caller(commands)

                try commands.append(try commandBuffer.toOwnedSlice());
                // cleanup
                commandBuffer.clearRetainingCapacity();
            }
            continue;
        }

        if (token == '\'' and !in_double_quote and !escaped) {
            // check for open/close quote
            in_quote = !in_quote;
            continue;
        }
        if (token == '\"' and !escaped and !in_quote) {
            // check for open/close quote
            in_double_quote = !in_double_quote;
            continue;
        }

        if (token == '\\' and in_double_quote and !escaped) {
            if (remaining.len > index + 1) {
                const next = remaining[index + 1];
                if (next == '\\' or next == '$' or next == '"') {
                    escaped = true;
                    continue;
                } else {
                    escaped = false;
                }
            }
        } else {
            escaped = false;
        }

        if (token == '\\' and !in_double_quote and !in_quote) {
            escaped = true;
            continue;
        } else {
            escaped = false;
        }

        // add token
        try commandBuffer.append(token);
    }
    // flush any remaining args
    if (commandBuffer.items.len > 0) {
        // convert memory ownershipt to caller(commands)
        try commands.append(try commandBuffer.toOwnedSlice());
    }

    return commands;
}

fn getCommand(cmd: []const u8) CommandType {
    return std.meta.stringToEnum(CommandType, cmd) orelse CommandType.unknown;
}

fn escapeChars(allocator: std.mem.Allocator, args: []const u8) ![]const u8 {
    const output = try allocator.dupe(u8, args);
    defer allocator.free(output);

    std.mem.replaceScalar(u8, output, '\'', '"');
    return allocator.dupe(u8, output);
}

fn builtinExit(args: [][]const u8) !void {
    var exit_code: u8 = 0;
    if (args.len > 0) {
        exit_code = std.fmt.parseInt(u8, args[0], 10) catch |err| switch (err) {
            else => 0,
        };
    }
    std.process.exit(exit_code);
}
fn builtinCd(allocator: std.mem.Allocator, args: []const u8, out: anytype) !void {
    if (args.len > 0) {
        if (std.mem.eql(u8, args, "~")) {
            const cwd = try std.process.getEnvVarOwned(allocator, "HOME");

            defer allocator.free(cwd);
            std.process.changeCurDir(cwd) catch {
                try out.print("cd: {s}: No such file or directory\n", .{args});
            };
        } else {
            std.process.changeCurDir(args) catch {
                try out.print("cd: {s}: No such file or directory\n", .{args});
            };
        }
    }
}
fn builtinPwd(allocator: std.mem.Allocator, out: anytype) !void {
    const cwd = try std.fs.cwd().realpathAlloc(allocator, ".");

    defer allocator.free(cwd);
    try out.print("{s}\n", .{cwd});
}

fn builtinEcho(allocator: std.mem.Allocator, args: [][]const u8, out: anytype) !void {
    const joined = try std.mem.join(allocator, " ", args);
    defer allocator.free(joined);
    try out.print("{s}\n", .{joined});
}
fn builtinType(cmd: []const u8, out: anytype) !void {
    const command_type = getCommand(cmd);
    try switch (command_type) {
        .exit, .echo, .type, .pwd, .cd => out.print("{s} is a shell builtin\n", .{cmd}),
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

fn handleExecutable(allocator: std.mem.Allocator, cmd: []const u8, args: [][]const u8, out: anytype) !void {
    const file_path = getExecutable(allocator, cmd) catch {
        try out.print("{s}: not found\n", .{cmd});
        return;
    };
    defer allocator.free(file_path);

    var argv = std.ArrayList([]const u8).init(allocator);
    defer argv.deinit();

    try argv.append(cmd);
    if (args.len > 0) {
        for (args) |arg| {
            try argv.append(arg);
        }
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
