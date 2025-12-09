// Window style masks (NSWindowStyleMask)

pub const StyleMask = struct {
    pub const titled: u64 = 1 << 0;
    pub const closable: u64 = 1 << 1;
    pub const miniaturizable: u64 = 1 << 2;
    pub const resizable: u64 = 1 << 3;
    pub const fullscreen: u64 = 1 << 14;
    pub const borderless: u64 = 0;
    pub const default: u64 = titled | closable | miniaturizable | resizable;
};
