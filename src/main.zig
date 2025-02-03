const std = @import("std");

pub fn main() !void {
    // Uncomment this block to pass the first stage
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn().reader();

    var buffer: [1024]u8 = undefined;
    while (true) {
        try stdout.print("$ ", .{});
        const user_input = try stdin.readUntilDelimiter(&buffer, '\n');

        var it = std.mem.splitScalar(u8, user_input, ' ');
        const command = it.next().?;

        try stdout.print("{s}: command not found\n", .{command});
        try stdout.print("exit 0");
        break;
    }
}
