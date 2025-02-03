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
        const command = it.next();

        if (command) |c| {
            if (std.mem.eql(u8, c, "exit")) {
                const exit_code = try std.fmt.parseInt(u8, it.next() orelse "0", 10);
                std.process.exit(exit_code);
            } else {
                try stdout.print("{s}: command not found\n", .{c});
            }
        }
    }
}
