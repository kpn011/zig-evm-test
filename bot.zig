const std = @import("std");
const crypto = std.crypto;
const json = std.json;
const http = std.http;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const rpc_url = try std.process.getEnvVarOwned(allocator, "SEPOLIA_RPC_URL");
    const private_key = try std.process.getEnvVarOwned(allocator, "PRIVATE_KEY");
    const sender_address = try std.process.getEnvVarOwned(allocator, "SENDER_ADDRESS");
    
    const recipients = [_][]const u8{
        "0xAb5801a7D398351b8bE11C439e05C5B3259aeC9B",
        "0x1Db3439a222C519ab44bb1144fC28167b4Fa6EE6",
        "0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD",
    };
    
    var prng = std.rand.DefaultPrng.init(@intCast(std.time.timestamp()));
    const random_index = prng.random().intRangeLessThan(usize, 0, recipients.len);
    const recipient = recipients[random_index];
    
    const min_amount: f64 = 0.0001;
    const max_amount: f64 = 0.001;
    const amount = min_amount + prng.random().float(f64) * (max_amount - min_amount);
    const amount_wei = @as(u128, @intFromFloat(amount * 1_000_000_000_000_000_000));
    
    const balance_body = try std.fmt.allocPrint(allocator,
        \\{"jsonrpc":"2.0","method":"eth_getBalance","params":["{s}","latest"],"id":1}
    , .{sender_address});
    
    var client = http.Client{ .allocator = allocator };
    var req = try client.request(.POST, try std.Uri.parse(rpc_url), .{
        .allocator = allocator,
        .headers = .{ .content_type = "application/json" },
    }, .{});
    defer req.deinit();
    
    try req.writeAll(balance_body);
    try req.finish();
    try req.wait();
    
    var balance_resp = std.ArrayList(u8).init(allocator);
    defer balance_resp.deinit();
    try req.reader().readAllArrayList(&balance_resp, 8192);
    
    const balance_json = try json.parseFromSlice(json.Value, allocator, balance_resp.items, .{});
    const balance_hex = balance_json.value.Object.get("result").?.String;
    const balance = try std.fmt.parseInt(u128, balance_hex[2..], 16);
    
    if (balance < amount_wei) {
        return error.InsufficientBalance;
    }
    
    std.debug.print("Would send {d} wei to {s}\n", .{ amount_wei, recipient });
    std.debug.print("Need to implement signing...\n", .{});
}
