const std = @import("std");

const pebble_sdk = @import("pebble_sdk");

pub fn build(b: *std.Build) !void {
    pebble_sdk.addPebbleApplication(b, .{
        .name = "heartburn",
        .pebble = .{
            .displayName = "Heartburn Watchface",
            .author = "vsergeev",
            .uuid = "250e6787-7f0e-44ea-ab01-eab66036d278",
            .version = .{ .major = 1, .minor = 0 },
            .targetPlatforms = &.{.emery},
            .watchapp = .{
                .watchface = true,
            },
            .resources = .{
                .media = &.{
                    .{ .font = .{ .name = "FONT_ICONS_18", .file = "heartburn-icons.ttf" } },
                },
            },
            .messageKeys = &.{
                .{ .key = "REQUEST_WEATHER", .value = 10001 },
                .{ .key = "WEATHER_ERROR", .value = 10010 },
                .{ .key = "WEATHER_CONDITIONS", .value = 10011 },
                .{ .key = "WEATHER_TEMPERATURE", .value = 10012 },
                .{ .key = "WEATHER_SUNRISE", .value = 10013 },
                .{ .key = "WEATHER_SUNSET", .value = 10014 },
            },
            .capabilities = &.{ .health, .location, .configurable },
        },
        .root_source_file = b.path("src/main.zig"),
        .pebblekit_js_file = b.path("js/bundle.js"),
        .optimize = .ReleaseFast,
    });
}
