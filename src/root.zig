const std = @import("std");
const assert = std.debug.assert;

const FONT_FORMAT = struct {
    const TRUE_TYPE_1 = BigEnd.peek_u32([4]u8{'1', 0, 0, 0});
    const TRUE_TYPE_WITH_TYPE_1 = BigEnd.peek_u32([4]u8{'t', 'y', 'p', '1'});
    const OPEN_TYPE_WITH_CFF = BigEnd.peek_u32([4]u8{'O', 'T', 'T', 'O'});
    const OPEN_TYPE_1 = BigEnd.peek_u32([4]u8{0, 1, 0, 0});
    const TRUE_TYPE_APPLE = BigEnd.peek_u32([4]u8{'t', 'r', 'u', 'e'});
    const FONT_COLLECTION = BigEnd.peek_u32([4]u8{'t', 't', 'c', 'f'});
};

const FONT_TABLE = struct {
    const CMAP = BigEnd.peek_u32([4]u8{'c', 'm', 'a', 'p'});
    const LOCA = BigEnd.peek_u32([4]u8{'l', 'o', 'c', 'a'});
    const HEAD = BigEnd.peek_u32([4]u8{'h', 'e', 'a', 'd'});
    const GLYF = BigEnd.peek_u32([4]u8{'g', 'l', 'y', 'f'});
    const HHEA = BigEnd.peek_u32([4]u8{'h', 'h', 'e', 'a'});
    const HMTX = BigEnd.peek_u32([4]u8{'h', 'm', 't', 'x'});
    const KERN = BigEnd.peek_u32([4]u8{'k', 'e', 'r', 'n'});
    const GPOS = BigEnd.peek_u32([4]u8{'G', 'P', 'O', 'S'});
};

const FontFileReader = struct {
    data: []const u8,
    pos: usize,

    inline fn new(data: []u8) FontFileReader {
        return FontFileReader{
            .data = data,
            .pos = 0,
        };
    }

    inline fn slice(self: *FontFileReader, start: usize, len: usize) FontFileReader {
        assert(start + len <= self.data.len);
        return FontFileReader{
            .data = self.data[start..start+len],
            .pos = 0,
        };
    }

    inline fn read_u8(self: *FontFileReader) u8 {
        assert(self.pos < self.data.len);
        const val = self.data[self.pos];
        self.pos += 1;
        return val;
    }

    inline fn peek_u8(self: *FontFileReader) u8 {
        assert(self.pos < self.data.len);
        return self.data[self.pos];
    }

    inline fn goto(self: *FontFileReader, pos: usize) void {
        assert(pos <= self.data.len);
        self.pos = pos;
    }

    inline fn skip(self: *FontFileReader, count: usize) void {
        assert(count + self.pos <= self.data.len);
        self.pos += count;
    }

    inline fn read_n_bytes_to_u32(self: *FontFileReader, count: usize) u32 {
        assert(count > 0 and count < 5);
        assert(count + self.pos <= self.data.len);
        const val: u32 = switch (count) {
            1 => @as(u32, @intCast(self.data[self.pos])),
            2 => @as(u32, @intCast(self.data[self.pos] << 8)) | @as(u32, @intCast(self.data[self.pos+1])),
            3 => @as(u32, @intCast(self.data[self.pos] << 16)) | @as(u32, @intCast(self.data[self.pos+1] << 8)) | @as(u32, @intCast(self.data[self.pos+2])),
            4 => @as(u32, @intCast(self.data[self.pos] << 24)) | @as(u32, @intCast(self.data[self.pos+1] << 16)) | @as(u32, @intCast(self.data[self.pos+2] << 8)) | @as(u32, @intCast(self.data[self.pos+3])),
            else => unreachable,
        };
        self.pos += count;
        return val;
    }


    inline fn peek_u16(self: *FontFileReader) u16 {
        return BigEnd.peek_u16(self.data[self.pos..]);
    }
    inline fn read_u16(self: *FontFileReader) u16 {
        const val: u16 = self.peek_u16();
        self.pos += 2;
        return val;
    }
    inline fn peek_i16(self: *FontFileReader) i16 {
        return BigEnd.peek_i16(self.data[self.pos..]);
    }
    inline fn read_i16(self: *FontFileReader) i16 {
        const val: i16 = self.peek_i16();
        self.pos += 2;
        return val;
    }

    inline fn peek_u32(self: *FontFileReader) u32 {
        return BigEnd.peek_u32(self.data[self.pos..]);
    }
    inline fn read_u32(self: *FontFileReader) u32 {
        const val: u32 = self.peek_u32();
        self.pos += 4;
        return val;
    }
    inline fn peek_i32(self: *FontFileReader) i32 {
        return BigEnd.peek_i32(self.data[self.pos..]);
    }
    inline fn read_i32(self: *FontFileReader) i32 {
        const val: i32 = self.peek_i32();
        self.pos += 4;
        return val;
    }

    fn cff_get_index_slice(self: *FontFileReader) FontFileReader {
        const start = self.pos;
        const count = self.read_u16();
        if (count > 0) {
            const offsize = self.read_u8();
            assert(offsize > 0 and offsize < 5);
            self.skip(offsize * count);
            self.skip(self.read_n_bytes_to_u32(offsize) - 1);
        }
        return self.slice(start, self.pos - start);
    }

    fn read_cff_int(self: *FontFileReader) u32 {
        const byte_0: u32 = @intCast(self.read_u8());
        if (byte_0 >= 32 and byte_0 <= 246) {
            return byte_0 - 139;
        } else if (byte_0 >= 247 and byte_0 <= 250) {
            return ((byte_0 - 247) * 256) + self.read_u8() + 108;
        } else if (byte_0 >= 251 and byte_0 <= 254) {
            return -((byte_0 - 251) * 256) - self.read_u8() - 108;
        } else if (byte_0 == 28) {
            return @intCast(self.read_u16());
        } else if (byte_0 == 29) {
            return self.read_u32();
        }
        unreachable;
    }

    fn skip_cff_operand(self: *FontFileReader) void {
        const byte_0: u8 = self.read_u8();
        assert(byte_0 >= 28);
        if (byte_0 == 30) {
            self.skip(1);
            while (self.pos < self.data.len) {
                const val = self.read_u8();
                if (((val & 0xF) == 0xF) || ((val >> 4) == 0xF)) break;
            }
        } else {
            _ = self.read_cff_int();
        }
    }

    /// Returns `null` if no cff dict matching key was found
    fn get_cff_dict_slice(self: *FontFileReader, key: u32) ?FontFileReader {
        self.goto(0);
        while (self.pos < self.data.len) {
            const start = self.pos;
            while (self.peek_u8() >= 28) {
                self.skip_cff_operand();
            }
            const end = self.pos;
            var op: u32 = @intCast(self.read_u8());
            if (op == 12) op = @as(u32, @intCast(self.read_u8())) | 0x100;
            if (op == key) return self.slice(start, end-start);
        }
        return null;
    }

    /// Writes dict ints to destination slice
    ///
    /// Returns `false` if no dict matching key was found
    fn read_cff_dict_ints_to_dst(self: *FontFileReader, key: u32, int_dst: []u32) bool {
        const operands_or_null = self.get_cff_dict_slice(key);
        if (operands_or_null) |operands| {
            var i: usize = 0;
            while (i < int_dst.len) {
                int_dst[i] = operands.read_cff_int();
                i += 1;
            }
            return true;
        } else {
            return false;
        }
    }

    inline fn cff_index_count(self: *FontFileReader) u16 {
        self.goto(0);
        return self.read_u16();
    }

    fn cff_get_indexed_sub_slice(self: *FontFileReader, idx_key: u32) FontFileReader {
        const count = self.cff_index_count();
        const offsize = self.read_u8();
        assert(idx_key < count);
        assert(offsize >= 1 and offsize <= 4);
        self.skip(idx_key * offsize);
        const sub_start = self.read_n_bytes_to_u32(offsize);
        const sub_end = self.read_n_bytes_to_u32(offsize);
        return self.slice(((count+1)*offsize)+2+sub_start, sub_end-sub_start);
    }

    fn is_font(self: *FontFileReader) bool {
        const font_tag = BigEnd.peek_u32(self.data);
        return switch (font_tag) {
            FONT_FORMAT.TRUE_TYPE_1 => true,
            FONT_FORMAT.TRUE_TYPE_WITH_TYPE_1 => true,
            FONT_FORMAT.OPEN_TYPE_WITH_CFF => true,
            FONT_FORMAT.OPEN_TYPE_1 => true,
            FONT_FORMAT.TRUE_TYPE_APPLE => true,
            else => false,
        };
    }

    inline fn is_font_collection(self: *FontFileReader) bool {
        const font_tag = BigEnd.peek_u32(self.data);
        return font_tag == FONT_FORMAT.FONT_COLLECTION;
    }

    inline fn font_collection_is_ver_1(self: *FontFileReader) bool {
        const ver = BigEnd.peek_u32(self.data[4..]);
        return ver == 0x00010000 or ver == 0x00020000;
    }

    /// Returns `null` if table matching tag was not found
    fn find_table_location(self: *FontFileReader, tag: u32) ?u32 {
        const num_tables = BigEnd.peek_u16(self.data[self.pos+4..]);
        const table_dir = self.pos + 12;
        var idx: usize = 0;
        while (idx < num_tables) {
            const pos = table_dir + (16 * idx);
            const tag_at_pos = BigEnd.peek_u32(self.data[pos..]);
            if (tag_at_pos == tag) {
                return BigEnd.peek_u32(self.data[pos+8..]);
            }
            idx += 1;
        }
        return null;
    }

    fn get_number_of_fonts_in_file(self: *FontFileReader, index: usize) FontError!u32 {
        if (self.is_font()) {
            return 1;
        }

        if (self.is_font_collection()) {
            if (self.font_collection_is_ver_1()) {
                return BigEnd.peek_u32(self.data[8..]);
            }
            return FontError.FontCollectionIsUnsuportedVersion;
        }

        return FontError.FileIsNotAFont_OR_IsUnsuportedFormat;
    }

    fn get_byte_offset_for_font_index(self: *FontFileReader, index: usize) FontError!u32 {
        if (self.is_font()) {
            if (index == 0) return 0;
            return FontError.FontFileContainsOnlyOneFont_BUT_RequestedFontIndexGreaterThanZero;
        }

        if (self.is_font_collection()) {
            if (self.font_collection_is_ver_1()) {
                const num_fonts = BigEnd.peek_u32(self.data[8..]);
                if (index >= num_fonts) return FontError.FontIndexGreaterThanNumberOfFontsInCollection;
                return BigEnd.peek_u32(self.data[12+(index*4)..]);
            }
        }

        return FontError.FileIsNotAFont_OR_IsUnsuportedFormat;
    }

    fn cff_get_subroutines(self: *FontFileReader, font_dict: *FontFileReader) ?FontFileReader {
        var subrs_offset = [1]u32{0};
        var private_loc = [2]u32{0, 0};
        font_dict.read_cff_dict_ints_to_dst(18, private_loc[0..2]);
        if (private_loc[0] == 0 or private_loc[1] == 0) return null;
        var pdict = self.slice(private_loc[1], private_loc[0]);
        pdict.read_cff_dict_ints_to_dst(19, subrs_offset[0..1]);
        if (subrs_offset[0] == 0) return null;
        self.goto(private_loc[1+subrs_offset[0]]);
        return self.cff_get_index_slice();
    }


};

pub const FontInfo = struct {
    user_data: *anyopaque = undefined,
    data: FontFileReader = undefined,
    /// number of individual glyphs in this font
    num_glyphs: u32 = undefined,
    /// table locations as offsets from start of font data
    table: struct {
        loca: u32 = undefined,
        head: u32 = undefined,
        glyf: u32 = undefined,
        hhea: u32 = undefined,
        hmtx: u32 = undefined,
        kern: u32 = undefined,
        gpos: u32 = undefined,
        svg: u32 = undefined,
    } = undefined,
    /// a cmap mapping for our chosen character encoding
    index_map: u32 = undefined,
    /// format needed to map from glyph index to glyph
    index_to_loc_format: u32 = undefined,
    cff_data: FontFileReader = undefined,
    charstring_data: FontFileReader = undefined,
    global_subroutine_data: FontFileReader = undefined,
    private_subroutine_data: FontFileReader = undefined,
    font_dicts: FontFileReader = undefined,
    font_dict_select: FontFileReader = undefined,

    pub fn init_font(font_file_data: []const u8, offset: u32) FontError!FontInfo {
        var info = FontInfo{};
        info.data = FontFileReader{
            .data = font_file_data[offset..],
            .pos = 0,
        };

        const cmap = info.data.find_table_location(FONT_TABLE.CMAP) orelse return FontError.RequiredTableNotFound_CMAP;
        //TODO: finish implmenenting InitFont
    }
};

/// Utility functions for reading values from a BigEndian byte buffer
const BigEnd = struct {
    inline fn peek_u16(data: []const u8) u16 {
        assert(data.len >= 2);
        return @as(u16, @intCast(data[0])) << 8 | @as(u16, @intCast(data[1]));
    }
    inline fn peek_i16(data: []const u8) i16 {
        return @bitCast(BigEnd.peek_u16(data));
    }
    inline fn peek_u16_at(data: []const u8, offset: usize) u16 {
        return BigEnd.peek_u16(data[offset..]);
    }
    inline fn peek_i16_at(data: []const u8, offset: usize) i16 {
        return BigEnd.peek_i16(data[offset..]);
    }

    inline fn peek_u32(data: []const u8) u32 {
        assert(data.len >= 4);
        return @as(u32, @intCast(data[0])) << 24 | @as(u32, @intCast(data[1])) << 16 | @as(u32, @intCast(data[2])) << 8 | @as(u32, @intCast(data[3]));
    }
    inline fn peek_i32(data: []const u8) i32 {
        return @bitCast(BigEnd.peek_u32(data));
    }
    inline fn peek_u32_at(data: []const u8, offset: usize) u32 {
        return BigEnd.peek_u32(data[offset..]);
    }
    inline fn peek_i32_at(data: []const u8, offset: usize) i32 {
        return BigEnd.peek_i32(data[offset..]);
    }
};

// const BakedChar = struct {
//     x0: u16,
//     x1: u16,
//     y0: u16,
//     y1: u16,
//     xoff: f32,
//     yoff: f32,
//     xadvance: f32,
// };

const PLATFORM_ID = enum(u32) {
    UNICODE = 0,
    MAC = 1,
    ISO = 2,
    WIN = 3,
};

const UNICODE_EID = enum(u32) {
    UNICODE_1_0   = 0,
    UNICODE_1_1 = 1,
    ISO_10646 = 2,
    UNICODE_2_0_BMP = 3,
    UNICODE_2_0_FULL = 4,
};

const WINDOWS_EID = enum(u32) {
    SYMBOL    = 0,
    UNICODE_BMP = 1,
    SHIFTJIS = 2,
    UNICODE_FULL = 10,
};

const MAC_EID = enum(u32) {
    ROMAN    = 0,
    JAPANESE = 1,
    CHINESE_TRAD = 2,
    KOREAN  = 3,
    ARABIC  = 4,
    HEBREW  = 5,
    GREEK  = 6,
    RUSSIAN  = 7,
};

const WIN_LANG = enum(u32) {
    ENGLISH     = 0x0409,
    CHINESE     = 0x0804,
    DUTCH       = 0x0413,
    FRENCH      = 0x040C,
    GERMAN      = 0x0407,
    HEBREW      = 0x040D,
    ITALIAN     = 0x0410,
    JAPANESE    = 0x0411,
    KOREAN      = 0x0412,
    RUSSIAN     = 0x0419,
    SPANISH     = 0x0409,
    SWEDISH     = 0x041D,
};

const MAC_LANG = enum(u32) {
    ENGLISH     = 0,
    FRENCH      = 1,
    GERMAN      = 2,
    ITALIAN     = 3,
    DUTCH       = 4,
    SWEDISH     = 5,
    SPANISH     = 6,
    HEBREW      = 10,
    JAPANESE    = 11,
    ARABIC     = 12,
    CHINESE_TRAD = 19,
    KOREAN      = 23,
    RUSSIAN     = 32,
    CHINESE_SIMPLIFIED = 33,
};

pub const FontError = error {
    FontFileContainsOnlyOneFont_BUT_RequestedFontIndexGreaterThanZero,
    FontCollectionIsUnsuportedVersion,
    FontIndexGreaterThanNumberOfFontsInCollection,
    RequiredTableNotFound_CMAP,
};

