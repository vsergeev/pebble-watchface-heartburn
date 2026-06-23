// pebble-watchface-heartburn v1.0
// https://github.com/vsergeev/pebble-watchface-heartburn

const std = @import("std");

const pebble = @import("pebble");
const pebble_appids = @import("pebble_appids");

////////////////////////////////////////////////////////////////////////////////
// Constants
////////////////////////////////////////////////////////////////////////////////

const COLOR_BACKGROUND = pebble.GColorDarkGray;
const COLOR_DATETIME = pebble.GColorPastelYellow;
const COLOR_WIDGETS = pebble.GColorWhite;
const COLOR_HEARTRATE_HISTORY = pebble.GColorWhite;
const COLOR_HEARTRATE_HISTORY_MAX = pebble.GColorMelon;
const COLOR_HEARTRATE_HISTORY_MIN = pebble.GColorPictonBlue;

const WINDOW_MARGIN_PX = 5;
const ICON_SPACING_PX = 4;
const ICON_OFFSET_Y_PX = 1;

var FONT_ICONS: pebble.GFont = null;
var FONT_WIDGETS: pebble.GFont = null;
var FONT_DATETIME_BIG: pebble.GFont = null;
var FONT_DATETIME_SMALL: pebble.GFont = null;

////////////////////////////////////////////////////////////////////////////////
// Watchface State
////////////////////////////////////////////////////////////////////////////////

var state: struct {
    window: ?*pebble.Window = null,
    weather_widget: WeatherWidget = .{},
    sunevent_widget: SunEventWidget = .{},
    battery_widget: BatteryWidget = .{},
    heartrate_widget: HeartRateWidget = .{},
    heartratehistory_widget: HeartRateHistoryWidget = .{},
    datetime_widget: DateTimeWidget = .{},
} = .{};

////////////////////////////////////////////////////////////////////////////////
// Widget Draw Helper
////////////////////////////////////////////////////////////////////////////////

fn widget_draw(ctx: ?*pebble.GContext, bounds: pebble.GRect, location: enum { TopLeft, TopCenter, TopRight, BottomLeft, BottomCenter, BottomRight }, offset: pebble.GPoint, icon_text: [:0]const u8, widget_text: [:0]const u8) void {
    const icon_size = pebble.graphics_text_layout_get_content_size(icon_text, FONT_ICONS, bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentCenter);
    const text_size = pebble.graphics_text_layout_get_content_size(widget_text, FONT_WIDGETS, bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentCenter);
    const widget_width = icon_size.w + ICON_SPACING_PX + text_size.w;

    const icon_box: pebble.GRect = switch (location) {
        .TopLeft => .{ .origin = .{ .x = offset.x + WINDOW_MARGIN_PX, .y = offset.y + WINDOW_MARGIN_PX + ICON_OFFSET_Y_PX }, .size = icon_size },
        .TopCenter => .{ .origin = .{ .x = offset.x + @divTrunc(bounds.size.w - widget_width, 2), .y = offset.y + WINDOW_MARGIN_PX + ICON_OFFSET_Y_PX }, .size = icon_size },
        .TopRight => .{ .origin = .{ .x = offset.x + bounds.size.w - WINDOW_MARGIN_PX - text_size.w - ICON_SPACING_PX - icon_size.w, .y = offset.y + WINDOW_MARGIN_PX + ICON_OFFSET_Y_PX }, .size = icon_size },
        .BottomLeft => .{ .origin = .{ .x = offset.x + WINDOW_MARGIN_PX, .y = offset.y + bounds.size.h - 2 * WINDOW_MARGIN_PX - icon_size.h + ICON_OFFSET_Y_PX }, .size = icon_size },
        .BottomCenter => .{ .origin = .{ .x = offset.x + @divTrunc(bounds.size.w - widget_width, 2), .y = offset.y + bounds.size.h - 2 * WINDOW_MARGIN_PX - icon_size.h + ICON_OFFSET_Y_PX }, .size = icon_size },
        .BottomRight => .{ .origin = .{ .x = offset.x + bounds.size.w - WINDOW_MARGIN_PX - text_size.w - ICON_SPACING_PX - icon_size.w, .y = offset.y + bounds.size.h - 2 * WINDOW_MARGIN_PX - icon_size.h + ICON_OFFSET_Y_PX }, .size = icon_size },
    };

    const text_box: pebble.GRect = switch (location) {
        .TopLeft => .{ .origin = .{ .x = offset.x + WINDOW_MARGIN_PX + icon_size.w + ICON_SPACING_PX, .y = offset.y + WINDOW_MARGIN_PX }, .size = text_size },
        .TopCenter => .{ .origin = .{ .x = offset.x + @divTrunc(bounds.size.w - widget_width, 2) + icon_size.w + ICON_SPACING_PX, .y = offset.y + WINDOW_MARGIN_PX }, .size = text_size },
        .TopRight => .{ .origin = .{ .x = offset.x + bounds.size.w - WINDOW_MARGIN_PX - text_size.w, .y = offset.y + WINDOW_MARGIN_PX }, .size = text_size },
        .BottomLeft => .{ .origin = .{ .x = offset.x + WINDOW_MARGIN_PX + icon_size.w + ICON_SPACING_PX, .y = offset.y + bounds.size.h - 2 * WINDOW_MARGIN_PX - text_size.h }, .size = text_size },
        .BottomCenter => .{ .origin = .{ .x = offset.x + @divTrunc(bounds.size.w - widget_width, 2) + icon_size.w + ICON_SPACING_PX, .y = offset.y + bounds.size.h - 2 * WINDOW_MARGIN_PX - text_size.h }, .size = text_size },
        .BottomRight => .{ .origin = .{ .x = offset.x + bounds.size.w - WINDOW_MARGIN_PX - text_size.w, .y = offset.y + bounds.size.h - 2 * WINDOW_MARGIN_PX - text_size.h }, .size = text_size },
    };

    pebble.graphics_context_set_text_color(ctx, COLOR_WIDGETS);
    pebble.graphics_draw_text(ctx, icon_text, FONT_ICONS, icon_box, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentCenter, null);
    pebble.graphics_draw_text(ctx, widget_text, FONT_WIDGETS, text_box, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentCenter, null);
}

////////////////////////////////////////////////////////////////////////////////
// Weather Widget
////////////////////////////////////////////////////////////////////////////////

const WeatherConditions = enum(u8) {
    WindyRain,
    Snow,
    HeavySnow,
    Hail,
    Clouds,
    CloudyLightning,
    Clear,
    PartlyCloudy,
    Cloudy,
    Lightning,
    Drizzle,
    Rain,
    CloudyWindy,
    Windy,
    Foggy,
    Unknown,

    pub fn mapIcon(self: WeatherConditions) u8 {
        return switch (self) {
            .WindyRain => 'a',
            .Snow => 'b',
            .HeavySnow => 'c',
            .Hail => 'd',
            .Clouds => 'e',
            .CloudyLightning => 'f',
            .Clear => 'g',
            .PartlyCloudy => 'h',
            .Cloudy => 'i',
            .Lightning => 'j',
            .Drizzle => 'k',
            .Rain => 'l',
            .CloudyWindy => 'm',
            .Windy => 'n',
            .Foggy => 'o',
            .Unknown => '9',
        };
    }
};

const WeatherWidget = struct {
    layer: ?*pebble.Layer = null,
    conditions: ?WeatherConditions = null,
    temperature_str: [8:0]u8 = ("?°" ++ [_]u8{0} ** 5).*,

    pub fn load(self: *WeatherWidget, window: ?*pebble.Window) void {
        self.layer = pebble.layer_create(pebble.layer_get_bounds(pebble.window_get_root_layer(window)));
        pebble.layer_set_update_proc(self.layer, WeatherWidget.draw);
        pebble.layer_add_child(pebble.window_get_root_layer(window), self.layer);
    }

    pub fn unload(self: *WeatherWidget, _: ?*pebble.Window) void {
        pebble.layer_destroy(self.layer);
    }

    pub fn reset(self: *WeatherWidget) void {
        self.conditions = null;
        _ = std.fmt.bufPrintZ(&self.temperature_str, "?°", .{}) catch unreachable;
        pebble.layer_mark_dirty(self.layer);
    }

    pub fn updateConditions(self: *WeatherWidget, conditions: WeatherConditions) void {
        self.conditions = conditions;
        pebble.layer_mark_dirty(self.layer);
    }

    pub fn updateTemperature(self: *WeatherWidget, temperature: i32) void {
        _ = std.fmt.bufPrintZ(&self.temperature_str, "{d}°", .{temperature}) catch unreachable;
        pebble.layer_mark_dirty(self.layer);
    }

    pub fn width(self: *WeatherWidget) i16 {
        const layer_bounds = pebble.layer_get_bounds(self.layer);

        const icon_text: [1:0]u8 = if (self.conditions) |conditions| .{conditions.mapIcon()} else "9".*;
        const widget_text = @as([:0]const u8, @ptrCast(&self.temperature_str));

        const icon_size = pebble.graphics_text_layout_get_content_size(&icon_text, FONT_ICONS, layer_bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentCenter);
        const text_size = pebble.graphics_text_layout_get_content_size(widget_text, FONT_WIDGETS, layer_bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentCenter);
        return icon_size.w + ICON_SPACING_PX + text_size.w;
    }

    pub fn draw(layer: ?*pebble.Layer, ctx: ?*pebble.GContext) callconv(.c) void {
        const self = &state.weather_widget;

        const icon_text: [1:0]u8 = if (self.conditions) |conditions| .{conditions.mapIcon()} else "9".*;

        widget_draw(ctx, pebble.layer_get_bounds(layer), .TopLeft, .{}, &icon_text, @as([:0]const u8, @ptrCast(&self.temperature_str)));
    }
};

////////////////////////////////////////////////////////////////////////////////
// Sun Event Widget
////////////////////////////////////////////////////////////////////////////////

const SunEvent = enum {
    Sunrise,
    Sunset,

    pub fn mapIcon(self: SunEvent) u8 {
        return switch (self) {
            .Sunrise => '0',
            .Sunset => '1',
        };
    }
};

fn parseISO8601(iso8601_str: []const u8) pebble.tm {
    return .{
        .tm_sec = if (iso8601_str.len >= 19) std.fmt.parseInt(c_int, iso8601_str[17..19], 10) catch 0 else 0,
        .tm_min = if (iso8601_str.len >= 16) std.fmt.parseInt(c_int, iso8601_str[14..16], 10) catch 0 else 0,
        .tm_hour = if (iso8601_str.len >= 13) std.fmt.parseInt(c_int, iso8601_str[11..13], 10) catch 0 else 0,
        .tm_mday = if (iso8601_str.len >= 10) std.fmt.parseInt(c_int, iso8601_str[8..10], 10) catch 0 else 0,
        .tm_mon = if (iso8601_str.len >= 7) (std.fmt.parseInt(c_int, iso8601_str[5..7], 10) catch 0) - 1 else 0,
        .tm_year = if (iso8601_str.len >= 4) (std.fmt.parseInt(c_int, iso8601_str[0..4], 10) catch 0) - 1900 else 0,
        .tm_wday = 0, // Ignored
        .tm_yday = 0, // Ignored
        .tm_isdst = 0,
        .tm_gmtoff = 0, // Ignored
        .tm_zone = .{ 0, 0, 0, 0, 0, 0 }, // Ignored
    };
}

const SunEventWidget = struct {
    layer: ?*pebble.Layer = null,
    sunrise_ts: ?pebble.time_t = null,
    sunset_ts: ?pebble.time_t = null,
    event: ?SunEvent = null,
    event_ts: ?pebble.time_t = null,
    time_str: [8:0]u8 = ("-:--" ++ [_]u8{0} ** 4).*,

    pub fn load(self: *SunEventWidget, window: ?*pebble.Window) void {
        self.layer = pebble.layer_create(pebble.layer_get_bounds(pebble.window_get_root_layer(window)));
        pebble.layer_set_update_proc(self.layer, SunEventWidget.draw);
        pebble.layer_add_child(pebble.window_get_root_layer(window), self.layer);
    }

    pub fn unload(self: *SunEventWidget, _: ?*pebble.Window) void {
        pebble.layer_destroy(self.layer);
    }

    pub fn reset(self: *SunEventWidget) void {
        self.sunrise_ts = null;
        self.sunset_ts = null;
        self.update();
    }

    pub fn updateSunrise(self: *SunEventWidget, iso8601_str: []const u8) void {
        var tm = parseISO8601(iso8601_str);
        self.sunrise_ts = pebble.mktime(&tm);
        self.update();
    }

    pub fn updateSunset(self: *SunEventWidget, iso8601_str: []const u8) void {
        var tm = parseISO8601(iso8601_str);
        self.sunset_ts = pebble.mktime(&tm);
        self.update();
    }

    pub fn update(self: *SunEventWidget) void {
        if (self.sunrise_ts != null and self.sunset_ts != null) {
            // Compute upcoming sun event
            const ts = pebble.time(null);
            const event: SunEvent = if (ts < self.sunrise_ts.? and self.sunrise_ts.? < self.sunset_ts.?) .Sunrise else .Sunset;
            const event_ts = if (event == .Sunrise) self.sunrise_ts.? else self.sunset_ts.?;

            // Do nothing if event is unchanged
            if (self.event == event and self.event_ts == event_ts) {
                return;
            }

            self.event = event;
            self.event_ts = event_ts;

            const event_tm = pebble.localtime(&event_ts).*;
            const tm_hour = @as(usize, @intCast(event_tm.tm_hour));
            const tm_min = @as(usize, @intCast(event_tm.tm_min));

            if (pebble.clock_is_24h_style()) {
                _ = std.fmt.bufPrintZ(&self.time_str, "{d}:{d:0>2}", .{ tm_hour, tm_min }) catch unreachable;
            } else {
                _ = std.fmt.bufPrintZ(&self.time_str, "{d}:{d:0>2}", .{ if (tm_hour % 12 == 0) 12 else (tm_hour % 12), tm_min }) catch unreachable;
            }
        } else {
            // Do nothing if event is unchanged
            if (self.event == null and self.event_ts == null) {
                return;
            }

            self.event = null;
            self.event_ts = null;

            _ = std.fmt.bufPrintZ(&self.time_str, "-:--", .{}) catch unreachable;
        }

        pebble.layer_mark_dirty(self.layer);
    }

    pub fn width(self: *SunEventWidget) i16 {
        const layer_bounds = pebble.layer_get_bounds(self.layer);

        const icon_text: [1:0]u8 = if (self.event) |event| .{event.mapIcon()} else "9".*;
        const widget_text = @as([:0]const u8, @ptrCast(&self.time_str));

        const icon_size = pebble.graphics_text_layout_get_content_size(&icon_text, FONT_ICONS, layer_bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentCenter);
        const text_size = pebble.graphics_text_layout_get_content_size(widget_text, FONT_WIDGETS, layer_bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentCenter);
        return icon_size.w + ICON_SPACING_PX + text_size.w;
    }

    pub fn draw(layer: ?*pebble.Layer, ctx: ?*pebble.GContext) callconv(.c) void {
        const self = &state.sunevent_widget;

        const icon_text: [1:0]u8 = if (self.event) |event| .{event.mapIcon()} else "9".*;

        const bounds = pebble.layer_get_bounds(layer);
        const offset = @divTrunc(WINDOW_MARGIN_PX + state.weather_widget.width() + (bounds.size.w - WINDOW_MARGIN_PX - state.battery_widget.width()) - self.width(), 2) - @divTrunc(bounds.size.w - self.width(), 2);

        widget_draw(ctx, pebble.layer_get_bounds(layer), .TopCenter, .{ .x = offset, .y = 0 }, &icon_text, @as([:0]const u8, @ptrCast(&self.time_str)));
    }
};

////////////////////////////////////////////////////////////////////////////////
// Battery Widget
////////////////////////////////////////////////////////////////////////////////

const BatteryWidget = struct {
    layer: ?*pebble.Layer = null,
    battery_level: u8 = 0,
    battery_level_str: [8:0]u8 = ("?%" ++ [_]u8{0} ** 6).*,
    charging: bool = false,

    pub fn load(self: *BatteryWidget, window: ?*pebble.Window) void {
        self.layer = pebble.layer_create(pebble.layer_get_bounds(pebble.window_get_root_layer(window)));
        pebble.layer_set_update_proc(self.layer, BatteryWidget.draw);
        pebble.layer_add_child(pebble.window_get_root_layer(window), self.layer);
    }

    pub fn unload(self: *BatteryWidget, _: ?*pebble.Window) void {
        pebble.layer_destroy(self.layer);
    }

    pub fn update(self: *BatteryWidget, charge: pebble.BatteryChargeState) void {
        self.battery_level = charge.charge_percent;
        self.charging = charge.is_charging;

        _ = std.fmt.bufPrintZ(&self.battery_level_str, "{d}%", .{self.battery_level}) catch unreachable;

        pebble.layer_mark_dirty(self.layer);
    }

    pub fn width(self: *BatteryWidget) i16 {
        const layer_bounds = pebble.layer_get_bounds(self.layer);

        const icon_text = if (self.charging) "8" else if (self.battery_level > 75) "7" else if (self.battery_level > 50) "6" else if (self.battery_level > 25) "5" else "4";
        const widget_text = @as([:0]const u8, @ptrCast(&self.battery_level_str));

        const icon_size = pebble.graphics_text_layout_get_content_size(icon_text, FONT_ICONS, layer_bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentCenter);
        const text_size = pebble.graphics_text_layout_get_content_size(widget_text, FONT_WIDGETS, layer_bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentCenter);
        return icon_size.w + ICON_SPACING_PX + text_size.w;
    }

    pub fn draw(layer: ?*pebble.Layer, ctx: ?*pebble.GContext) callconv(.c) void {
        const self = &state.battery_widget;

        const icon_text = if (self.charging) "8" else if (self.battery_level > 75) "7" else if (self.battery_level > 50) "6" else if (self.battery_level > 25) "5" else "4";

        widget_draw(ctx, pebble.layer_get_bounds(layer), .TopRight, .{}, icon_text, @as([:0]const u8, @ptrCast(&self.battery_level_str)));
    }
};

////////////////////////////////////////////////////////////////////////////////
// HeartRate Widget
////////////////////////////////////////////////////////////////////////////////

const HeartRateWidget = struct {
    layer: ?*pebble.Layer = null,
    heartrate_bpm_str: [8:0]u8 = ("--" ++ [_]u8{0} ** 6).*,

    pub fn load(self: *HeartRateWidget, window: ?*pebble.Window) void {
        self.layer = pebble.layer_create(pebble.layer_get_bounds(pebble.window_get_root_layer(window)));
        pebble.layer_set_update_proc(self.layer, HeartRateWidget.draw);
        pebble.layer_add_child(pebble.window_get_root_layer(window), self.layer);
    }

    pub fn unload(self: *HeartRateWidget, _: ?*pebble.Window) void {
        pebble.layer_destroy(self.layer);
    }

    pub fn update(self: *HeartRateWidget, heartrate_bpm: u32) void {
        if (heartrate_bpm == 0) {
            self.heartrate_bpm_str = ("--" ++ [_]u8{0} ** 6).*;
        } else {
            _ = std.fmt.bufPrintZ(&self.heartrate_bpm_str, "{d}", .{heartrate_bpm}) catch unreachable;
        }

        pebble.layer_mark_dirty(self.layer);
    }

    pub fn draw(layer: ?*pebble.Layer, ctx: ?*pebble.GContext) callconv(.c) void {
        const self = &state.heartrate_widget;

        widget_draw(ctx, pebble.layer_get_bounds(layer), .BottomLeft, .{}, "2", @as([:0]const u8, @ptrCast(&self.heartrate_bpm_str)));
    }
};

////////////////////////////////////////////////////////////////////////////////
// HeartRateHistory Widget
////////////////////////////////////////////////////////////////////////////////

const HEART_RATE_HISTORY_OFFSET_Y = 32;
const HEART_RATE_HISTORY_BAR_PITCH_X = 3;
const HEART_RATE_HISTORY_BAR_WIDTH_X = 2;
const HEART_RATE_HISTORY_BAR_RADIUS = 3;
const HEART_RATE_HISTORY_HEIGHT = 50;
const HEART_RATE_HISTORY_VALUE_MAX = 200;
const HEART_RATE_HISTORY_COUNT: usize = @divTrunc(pebble.PBL_DISPLAY_WIDTH - 2 * WINDOW_MARGIN_PX, HEART_RATE_HISTORY_BAR_PITCH_X);

const HeartRateHistoryWidget = struct {
    layer: ?*pebble.Layer = null,
    heartrate_bpm_history: [HEART_RATE_HISTORY_COUNT]u16 = [_]u16{0} ** HEART_RATE_HISTORY_COUNT,
    heartrate_bpm_max: u16 = 0,
    heartrate_bpm_min: u16 = 0,

    pub fn load(self: *HeartRateHistoryWidget, window: ?*pebble.Window) void {
        self.layer = pebble.layer_create(pebble.layer_get_bounds(pebble.window_get_root_layer(window)));
        pebble.layer_set_update_proc(self.layer, HeartRateHistoryWidget.draw);
        pebble.layer_add_child(pebble.window_get_root_layer(window), self.layer);
    }

    pub fn unload(self: *HeartRateHistoryWidget, _: ?*pebble.Window) void {
        pebble.layer_destroy(self.layer);
    }

    pub fn update(self: *HeartRateHistoryWidget) void {
        // Clear current heart rate history
        @memset(&self.heartrate_bpm_history, 0);
        self.heartrate_bpm_max = 0;
        self.heartrate_bpm_min = 0;

        // Fetch health minute data
        var health_minute_data: [HEART_RATE_HISTORY_COUNT]pebble.HealthMinuteData = undefined;
        var end_time: c_long = pebble.time(null);
        var start_time: c_long = end_time - 60 * HEART_RATE_HISTORY_COUNT;
        const num_records = pebble.health_service_get_minute_history(&health_minute_data, HEART_RATE_HISTORY_COUNT, &start_time, &end_time);

        // Process records
        var i: usize = 0;
        while (i < num_records) : (i += 1) {
            if (health_minute_data[i].is_invalid_and_light_level & 0x1 == 0) {
                const bpm = health_minute_data[i].heart_rate_bpm;
                self.heartrate_bpm_history[HEART_RATE_HISTORY_COUNT - @as(usize, @intCast(num_records)) + i] = bpm;
                if (self.heartrate_bpm_max == 0 or bpm > self.heartrate_bpm_max) self.heartrate_bpm_max = bpm;
                if (self.heartrate_bpm_min == 0 or bpm < self.heartrate_bpm_min) self.heartrate_bpm_min = bpm;
            }
        }

        pebble.layer_mark_dirty(self.layer);
    }

    pub fn draw(layer: ?*pebble.Layer, ctx: ?*pebble.GContext) callconv(.c) void {
        const self = &state.heartratehistory_widget;

        const bounds = pebble.layer_get_bounds(layer);

        // Draw heart rate history
        for (self.heartrate_bpm_history, 0..) |bpm, i| {
            const color = if (bpm == self.heartrate_bpm_max) COLOR_HEARTRATE_HISTORY_MAX else if (bpm == self.heartrate_bpm_min) COLOR_HEARTRATE_HISTORY_MIN else COLOR_HEARTRATE_HISTORY;
            pebble.graphics_context_set_fill_color(ctx, color);

            const barHeight: i16 = @intCast(@divTrunc(bpm * HEART_RATE_HISTORY_HEIGHT, HEART_RATE_HISTORY_VALUE_MAX));
            const rect: pebble.GRect = .{ .origin = .{
                .x = WINDOW_MARGIN_PX + @as(i16, @intCast(i)) * HEART_RATE_HISTORY_BAR_PITCH_X,
                .y = bounds.size.h - HEART_RATE_HISTORY_OFFSET_Y - barHeight,
            }, .size = .{ .w = HEART_RATE_HISTORY_BAR_WIDTH_X, .h = barHeight } };
            pebble.graphics_fill_rect(ctx, rect, HEART_RATE_HISTORY_BAR_RADIUS, pebble.GCornersAll);
        }
    }
};

////////////////////////////////////////////////////////////////////////////////
// DateTime Widget
////////////////////////////////////////////////////////////////////////////////

const DateTimeWidget = struct {
    layer: ?*pebble.Layer = null,
    date_str: [16]u8 = ("---" ++ [_]u8{0} ** 13).*,
    time_str: [8]u8 = ("--:--" ++ [_]u8{0} ** 3).*,
    sec_str: [4]u8 = ("--" ++ [_]u8{0} ** 2).*,
    am_pm: ?enum { AM, PM } = null,
    show_seconds: ?usize = null,

    pub fn load(self: *DateTimeWidget, window: ?*pebble.Window) void {
        self.layer = pebble.layer_create(pebble.layer_get_bounds(pebble.window_get_root_layer(window)));
        pebble.layer_set_update_proc(self.layer, DateTimeWidget.draw);
        pebble.layer_add_child(pebble.window_get_root_layer(window), self.layer);
    }

    pub fn unload(self: *DateTimeWidget, _: ?*pebble.Window) void {
        pebble.layer_destroy(self.layer);
    }

    pub fn enableSeconds(self: *DateTimeWidget) void {
        self.show_seconds = 10;
        pebble.tick_timer_service_subscribe(pebble.SECOND_UNIT, tick_handler);
    }

    pub fn update(self: *DateTimeWidget, tick_time: *pebble.tm, _: pebble.TimeUnits) void {
        _ = pebble.strftime(&self.date_str, self.date_str.len, "%a %b %d", tick_time);
        _ = pebble.strftime(&self.time_str, self.time_str.len, if (pebble.clock_is_24h_style()) "%H:%M" else "%I:%M", tick_time);
        _ = pebble.strftime(&self.sec_str, self.sec_str.len, "%S", tick_time);
        self.am_pm = if (pebble.clock_is_24h_style()) null else (if (tick_time.tm_hour < 12) .AM else .PM);

        if (self.show_seconds) |*show_seconds| {
            show_seconds.* -= 1;
            if (show_seconds.* == 0) {
                self.show_seconds = null;
                pebble.tick_timer_service_subscribe(pebble.MINUTE_UNIT, tick_handler);
            }
        }

        pebble.layer_mark_dirty(self.layer);
    }

    pub fn draw(_: ?*pebble.Layer, ctx: ?*pebble.GContext) callconv(.c) void {
        const self = &state.datetime_widget;

        const layer_bounds = pebble.layer_get_bounds(self.layer);

        const time_size = pebble.graphics_text_layout_get_content_size(&self.time_str, FONT_DATETIME_BIG, layer_bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentLeft);
        const date_size = pebble.graphics_text_layout_get_content_size(&self.date_str, FONT_DATETIME_SMALL, layer_bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentLeft);
        const seconds_size = pebble.graphics_text_layout_get_content_size(&self.sec_str, FONT_DATETIME_SMALL, layer_bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentLeft);
        const am_pm_size = pebble.graphics_text_layout_get_content_size("am", FONT_DATETIME_SMALL, layer_bounds, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentLeft);

        const DATE_X_SPACING = 3;
        const SECONDS_X_SPACING = 6;
        const SECONDS_Y_SPACING = 3;
        const origin: pebble.GPoint = .{ .x = @divTrunc(layer_bounds.size.w - (time_size.w + am_pm_size.w + SECONDS_X_SPACING), 2), .y = 60 };

        pebble.graphics_context_set_text_color(ctx, COLOR_DATETIME);
        pebble.graphics_draw_text(ctx, &self.date_str, FONT_DATETIME_SMALL, .{ .origin = .{ .x = origin.x + DATE_X_SPACING, .y = origin.y }, .size = date_size }, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentLeft, null);
        pebble.graphics_draw_text(ctx, &self.time_str, FONT_DATETIME_BIG, .{ .origin = .{ .x = origin.x, .y = origin.y + date_size.h }, .size = time_size }, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentLeft, null);
        if (self.show_seconds != null) {
            pebble.graphics_draw_text(ctx, &self.sec_str, FONT_DATETIME_SMALL, .{ .origin = .{ .x = origin.x + time_size.w + SECONDS_X_SPACING, .y = origin.y + date_size.h - SECONDS_Y_SPACING }, .size = seconds_size }, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentLeft, null);
        }
        if (self.am_pm) |am_pm| {
            pebble.graphics_draw_text(ctx, if (am_pm == .AM) "am" else "pm", FONT_DATETIME_SMALL, .{ .origin = .{ .x = origin.x + time_size.w + SECONDS_X_SPACING, .y = origin.y + date_size.h + seconds_size.h - SECONDS_Y_SPACING }, .size = am_pm_size }, pebble.GTextOverflowModeWordWrap, pebble.GTextAlignmentLeft, null);
        }
    }
};

////////////////////////////////////////////////////////////////////////////////
// Messaging Callbacks
////////////////////////////////////////////////////////////////////////////////

fn inbox_received_callback(iterator: [*c]pebble.DictionaryIterator, _: ?*anyopaque) callconv(.c) void {
    const weather_temperature_tuple = pebble.dict_find(iterator, @intFromEnum(pebble_appids.MESSAGE_KEYS.WEATHER_TEMPERATURE));
    if (weather_temperature_tuple != null) {
        state.weather_widget.updateTemperature(weather_temperature_tuple.*.value().*.int32);
    }

    const weather_conditions_tuple = pebble.dict_find(iterator, @intFromEnum(pebble_appids.MESSAGE_KEYS.WEATHER_CONDITIONS));
    if (weather_conditions_tuple != null) {
        const conditions = std.mem.span(@as([*c]const u8, &weather_conditions_tuple.*.value().*.cstring));
        inline for (@typeInfo(WeatherConditions).@"enum".fields) |enumField| {
            if (std.mem.eql(u8, conditions, enumField.name)) {
                state.weather_widget.updateConditions(@field(WeatherConditions, enumField.name));
                break;
            }
        } else state.weather_widget.updateConditions(.Unknown);
    }

    const weather_sunrise_tuple = pebble.dict_find(iterator, @intFromEnum(pebble_appids.MESSAGE_KEYS.WEATHER_SUNRISE));
    if (weather_sunrise_tuple != null) {
        const sunrise_iso8601_str = std.mem.span(@as([*c]const u8, &weather_sunrise_tuple.*.value().*.cstring));
        state.sunevent_widget.updateSunrise(sunrise_iso8601_str);
    }

    const weather_sunset_tuple = pebble.dict_find(iterator, @intFromEnum(pebble_appids.MESSAGE_KEYS.WEATHER_SUNSET));
    if (weather_sunset_tuple != null) {
        const sunset_iso8601_str = std.mem.span(@as([*c]const u8, &weather_sunset_tuple.*.value().*.cstring));
        state.sunevent_widget.updateSunset(sunset_iso8601_str);
    }

    const weather_error_tuple = pebble.dict_find(iterator, @intFromEnum(pebble_appids.MESSAGE_KEYS.WEATHER_ERROR));
    if (weather_error_tuple != null) {
        state.weather_widget.reset();
        state.sunevent_widget.reset();
    }
}

fn inbox_dropped_callback(reason: pebble.AppMessageResult, _: ?*anyopaque) callconv(.c) void {
    pebble.app_log(pebble.APP_LOG_LEVEL_INFO, "main.zig", 0, "message inbox failed: %d", reason);
}

fn outbox_failed_callback(_: [*c]pebble.DictionaryIterator, reason: pebble.AppMessageResult, _: ?*anyopaque) callconv(.c) void {
    pebble.app_log(pebble.APP_LOG_LEVEL_INFO, "main.zig", 0, "message outbox failed: %d", reason);
}

fn outbox_sent_callback(_: [*c]pebble.DictionaryIterator, _: ?*anyopaque) callconv(.c) void {}

fn outbox_send(key: pebble_appids.MESSAGE_KEYS, value: anytype) void {
    var iter: [*c]pebble.DictionaryIterator = undefined;

    if (pebble.app_message_outbox_begin(&iter) != pebble.APP_MSG_OK) return;

    if (@TypeOf(value) == u8) {
        _ = pebble.dict_write_uint8(iter, @intFromEnum(key), value);
    } else {
        @compileLog("Unsupported value type");
    }

    _ = pebble.app_message_outbox_send();
}

////////////////////////////////////////////////////////////////////////////////
// Callbacks
////////////////////////////////////////////////////////////////////////////////

fn tick_handler(tick_time: ?*pebble.tm, units_changed: pebble.TimeUnits) callconv(.c) void {
    if (!pebble.window_is_loaded(state.window)) return;

    state.datetime_widget.update(tick_time.?, units_changed);

    // Refresh sun event and heart rate graph every minute
    if (units_changed & pebble.MINUTE_UNIT != 0) {
        state.sunevent_widget.update();
        state.heartratehistory_widget.update();
    }

    // Request weather every 30 minutes
    if (units_changed & pebble.MINUTE_UNIT != 0 and @mod(tick_time.?.tm_min, 30) == 0) {
        outbox_send(pebble_appids.MESSAGE_KEYS.REQUEST_WEATHER, @as(u8, 1));
    }
}

fn tap_handler(_: pebble.AccelAxisType, _: i32) callconv(.c) void {
    if (!pebble.window_is_loaded(state.window)) return;

    state.datetime_widget.enableSeconds();
}

fn battery_state_handler(charge: pebble.BatteryChargeState) callconv(.c) void {
    if (!pebble.window_is_loaded(state.window)) return;

    state.battery_widget.update(charge);
}

fn health_event_handler(event: pebble.HealthEventType, _: ?*anyopaque) callconv(.c) void {
    if (!pebble.window_is_loaded(state.window)) return;

    if (event != pebble.HealthEventHeartRateUpdate) return;

    state.heartrate_widget.update(@intCast(pebble.health_service_peek_current_value(pebble.HealthMetricHeartRateBPM)));
}

fn window_load(window: ?*pebble.Window) callconv(.c) void {
    state.weather_widget.load(window);
    state.sunevent_widget.load(window);
    state.battery_widget.load(window);
    state.heartrate_widget.load(window);
    state.heartratehistory_widget.load(window);
    state.datetime_widget.load(window);
}

fn window_unload(window: ?*pebble.Window) callconv(.c) void {
    state.datetime_widget.unload(window);
    state.heartratehistory_widget.load(window);
    state.heartrate_widget.unload(window);
    state.battery_widget.unload(window);
    state.sunevent_widget.unload(window);
    state.weather_widget.unload(window);
}

////////////////////////////////////////////////////////////////////////////////
// Initialization
////////////////////////////////////////////////////////////////////////////////

fn init() void {
    FONT_ICONS = pebble.fonts_load_custom_font(pebble.resource_get_handle(@intFromEnum(pebble_appids.RESOURCE_IDS.FONT_ICONS_18)));
    FONT_WIDGETS = pebble.fonts_get_system_font(pebble.FONT_KEY_GOTHIC_18_BOLD);
    FONT_DATETIME_BIG = pebble.fonts_get_system_font(pebble.FONT_KEY_BITHAM_42_MEDIUM_NUMBERS);
    FONT_DATETIME_SMALL = pebble.fonts_get_system_font(pebble.FONT_KEY_GOTHIC_24_BOLD);

    state.window = pebble.window_create();
    pebble.window_set_background_color(state.window, COLOR_BACKGROUND);
    pebble.window_set_window_handlers(state.window, .{
        .load = window_load,
        .unload = window_unload,
    });
    pebble.window_stack_push(state.window, true);

    state.battery_widget.update(pebble.battery_state_service_peek());
    state.heartrate_widget.update(@intCast(pebble.health_service_peek_current_value(pebble.HealthMetricHeartRateBPM)));
    state.heartratehistory_widget.update();

    pebble.tick_timer_service_subscribe(pebble.MINUTE_UNIT, tick_handler);
    pebble.accel_tap_service_subscribe(tap_handler);
    pebble.battery_state_service_subscribe(battery_state_handler);
    _ = pebble.health_service_events_subscribe(health_event_handler, null);

    _ = pebble.app_message_register_inbox_received(inbox_received_callback);
    _ = pebble.app_message_register_inbox_dropped(inbox_dropped_callback);
    _ = pebble.app_message_register_outbox_failed(outbox_failed_callback);
    _ = pebble.app_message_register_outbox_sent(outbox_sent_callback);
    _ = pebble.app_message_open(64, 64);
}

fn deinit() void {
    pebble.tick_timer_service_unsubscribe();
    pebble.accel_tap_service_unsubscribe();
    pebble.battery_state_service_unsubscribe();
    _ = pebble.health_service_events_unsubscribe();

    pebble.window_destroy(state.window);

    pebble.fonts_unload_custom_font(FONT_ICONS);
}

////////////////////////////////////////////////////////////////////////////////
// Entry Point
////////////////////////////////////////////////////////////////////////////////

export fn main() void {
    init();
    pebble.app_event_loop();
    deinit();
}
