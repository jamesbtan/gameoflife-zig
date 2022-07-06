const std = @import("std");

const c = @cImport({
    @cInclude("SDL.h");
});

pub fn main() anyerror!void {
    _ = c.SDL_Init(c.SDL_INIT_VIDEO);
    defer c.SDL_Quit();

    const width = 40;
    const height = 40;

    var title_buf: [30]u8 = undefined;
    const norm_title = try std.fmt.bufPrintZ(&title_buf, "Game of Life {}x{}", .{ width, height });

    var pause_buf: [30]u8 = undefined;
    const pause_title = try std.fmt.bufPrintZ(&pause_buf, "Game of Life {}x{} (paused)", .{ width, height });

    const win = c.SDL_CreateWindow(pause_title, c.SDL_WINDOWPOS_CENTERED, c.SDL_WINDOWPOS_CENTERED, 1000, 1000, 0).?;
    defer c.SDL_DestroyWindow(win);

    const surf = c.SDL_GetWindowSurface(win).?;
    _ = surf;

    var state = GameState(width, height).init();

    var running = true;
    var paused = true;
    while (running) {
        var e: c.SDL_Event = undefined;
        while (c.SDL_PollEvent(&e) > 0) {
            switch (e.type) {
                c.SDL_QUIT => {
                    running = false;
                },
                c.SDL_KEYDOWN => {
                    switch (e.key.keysym.sym) {
                        c.SDLK_q => running = false,
                        c.SDLK_r => {
                            if (!paused) continue;
                            std.mem.set(bool, &state.board, false);
                        },
                        c.SDLK_SPACE => {
                            paused = !paused;
                            if (paused) {
                                c.SDL_SetWindowTitle(win, pause_title);
                            } else {
                                c.SDL_SetWindowTitle(win, norm_title);
                            }
                        },
                        else => {},
                    }
                },
                c.SDL_MOUSEBUTTONDOWN => {
                    if (!paused) continue;
                    const b = e.button;
                    const ix = @divTrunc(b.x * @intCast(i32, state.width), surf.*.w);
                    const iy = @divTrunc(b.y * @intCast(i32, state.height), surf.*.h);
                    const i = @intCast(usize, iy * @intCast(i32, state.width) + ix);
                    state.board[i] = !state.board[i];
                },
                else => {},
            }
        }
        _ = c.SDL_FillRect(surf, null, c.SDL_MapRGB(surf.*.format, 0, 0, 0));
        state.draw(surf);
        _ = c.SDL_UpdateWindowSurface(win);
        if (!paused) {
            state.update();
        }
        c.SDL_Delay(200);
    }
}

fn GameState(comptime w: usize, comptime h: usize) type {
    return struct {
        board: [w * h]bool,
        width: usize = w,
        height: usize = h,

        const Self = @This();

        pub fn init() Self {
            return .{ .board = .{false} ** (w * h) };
        }

        pub fn update(self: *Self) void {
            var nextboard: [w * h]bool = undefined;
            for (self.board) |a, i| {
                const n = self.count_neighbors(i);
                if (a) {
                    nextboard[i] = (n == 2 or n == 3);
                } else {
                    nextboard[i] = (n == 3);
                }
            }
            std.mem.copy(bool, &self.board, &nextboard);
        }

        pub fn count_neighbors(self: *const Self, idx: usize) u32 {
            var ct: u32 = 0;
            const iw = idx / self.width;
            const ih = idx % self.width;
            var ir = adjPM1(iw, self.width);
            var i: usize = ir.start;
            while (i <= ir.end) : (i += 1) {
                var jr = adjPM1(ih, self.height);
                var j: usize = jr.start;
                while (j <= jr.end) : (j += 1) {
                    const id = i * self.width + j;
                    if (id == idx) continue;
                    if (self.board[id]) ct += 1;
                }
            }
            return ct;
        }

        fn clamp(x: anytype, min: @TypeOf(x), max: @TypeOf(x)) @TypeOf(x) {
            return @maximum(min, @minimum(max, x));
        }

        const Range = struct { start: usize, end: usize };

        fn adjPM1(i: usize, len: usize) Range {
            return .{
                .start = clamp(i, 1, len - 1) - 1,
                .end = clamp(i, 0, len - 2) + 1,
            };
        }

        pub fn draw(self: *const Self, dst: [*c]c.SDL_Surface) void {
            var i: u32 = 0;
            while (i < self.width) : (i += 1) {
                var j: u32 = 0;
                while (j < self.height) : (j += 1) {
                    const x1 = @intCast(c_int, i * @intCast(u32, dst.*.w) / self.width);
                    const y1 = @intCast(c_int, j * @intCast(u32, dst.*.h) / self.height);
                    const x2 = @intCast(c_int, (i + 1) * @intCast(u32, dst.*.w) / self.width);
                    const y2 = @intCast(c_int, (j + 1) * @intCast(u32, dst.*.h) / self.height);
                    var rect: c.SDL_Rect = undefined;
                    rect.x = x1;
                    rect.y = y1;
                    rect.w = x2 - x1;
                    rect.h = y2 - y1;
                    _ = c.SDL_FillRect(dst, &rect, c.SDL_MapRGB(dst.*.format, 255, 255, 255));
                    if (!self.board[j * self.width + i]) {
                        _ = c.SDL_FillRect(dst, &rect, c.SDL_MapRGB(dst.*.format, 64, 64, 64));
                        rect.x += 1;
                        rect.y += 1;
                        rect.w -= 2;
                        rect.h -= 2;
                        _ = c.SDL_FillRect(dst, &rect, c.SDL_MapRGB(dst.*.format, 0, 0, 0));
                    }
                }
            }
        }
    };
}
