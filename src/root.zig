const std = @import("std");
const assert = std.debug.assert;

const FONT_FORMAT = struct {
    const TRUE_TYPE_1 = BigEnd.get_u32([4]u8{ '1', 0, 0, 0 });
    const TRUE_TYPE_WITH_TYPE_1 = BigEnd.get_u32([4]u8{ 't', 'y', 'p', '1' });
    const OPEN_TYPE_WITH_CFF = BigEnd.get_u32([4]u8{ 'O', 'T', 'T', 'O' });
    const OPEN_TYPE_1 = BigEnd.get_u32([4]u8{ 0, 1, 0, 0 });
    const TRUE_TYPE_APPLE = BigEnd.get_u32([4]u8{ 't', 'r', 'u', 'e' });
    const FONT_COLLECTION = BigEnd.get_u32([4]u8{ 't', 't', 'c', 'f' });
};

const FONT_TABLE = struct {
    const CMAP = BigEnd.get_u32([4]u8{ 'c', 'm', 'a', 'p' });
    const LOCA = BigEnd.get_u32([4]u8{ 'l', 'o', 'c', 'a' });
    const HEAD = BigEnd.get_u32([4]u8{ 'h', 'e', 'a', 'd' });
    const GLYF = BigEnd.get_u32([4]u8{ 'g', 'l', 'y', 'f' });
    const HHEA = BigEnd.get_u32([4]u8{ 'h', 'h', 'e', 'a' });
    const HMTX = BigEnd.get_u32([4]u8{ 'h', 'm', 't', 'x' });
    const KERN = BigEnd.get_u32([4]u8{ 'k', 'e', 'r', 'n' });
    const GPOS = BigEnd.get_u32([4]u8{ 'G', 'P', 'O', 'S' });
    const CFF = BigEnd.get_u32([4]u8{ 'C', 'F', 'F', ' ' });
    const MAXP = BigEnd.get_u32([4]u8{ 'm', 'a', 'x', 'p' });
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
            .data = self.data[start .. start + len],
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
            2 => @as(u32, @intCast(self.data[self.pos] << 8)) | @as(u32, @intCast(self.data[self.pos + 1])),
            3 => @as(u32, @intCast(self.data[self.pos] << 16)) | @as(u32, @intCast(self.data[self.pos + 1] << 8)) | @as(u32, @intCast(self.data[self.pos + 2])),
            4 => @as(u32, @intCast(self.data[self.pos] << 24)) | @as(u32, @intCast(self.data[self.pos + 1] << 16)) | @as(u32, @intCast(self.data[self.pos + 2] << 8)) | @as(u32, @intCast(self.data[self.pos + 3])),
            else => unreachable,
        };
        self.pos += count;
        return val;
    }

    inline fn peek_u16(self: *FontFileReader) u16 {
        return BigEnd.get_u16(self.data[self.pos..]);
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
        return BigEnd.get_u32(self.data[self.pos..]);
    }
    inline fn read_u32(self: *FontFileReader) u32 {
        const val: u32 = self.peek_u32();
        self.pos += 4;
        return val;
    }
    inline fn peek_i32(self: *FontFileReader) i32 {
        return BigEnd.get_i32(self.data[self.pos..]);
    }
    inline fn read_i32(self: *FontFileReader) i32 {
        const val: i32 = self.peek_i32();
        self.pos += 4;
        return val;
    }

    fn cff_get_index(self: *FontFileReader) FontFileReader {
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
            if (op == key) return self.slice(start, end - start);
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
        return self.slice(((count + 1) * offsize) + 2 + sub_start, sub_end - sub_start);
    }

    fn is_font(self: *FontFileReader) bool {
        const font_tag = BigEnd.get_u32(self.data);
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
        const font_tag = BigEnd.get_u32(self.data);
        return font_tag == FONT_FORMAT.FONT_COLLECTION;
    }

    inline fn font_collection_is_ver_1(self: *FontFileReader) bool {
        const ver = BigEnd.get_u32(self.data[4..]);
        return ver == 0x00010000 or ver == 0x00020000;
    }

    fn get_number_of_fonts_in_file(self: *FontFileReader) FontError!u32 {
        if (self.is_font()) {
            return 1;
        }

        if (self.is_font_collection()) {
            if (self.font_collection_is_ver_1()) {
                return BigEnd.get_u32(self.data[8..]);
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
                const num_fonts = BigEnd.get_u32(self.data[8..]);
                if (index >= num_fonts) return FontError.FontIndexGreaterThanNumberOfFontsInCollection;
                return BigEnd.get_u32(self.data[12 + (index * 4) ..]);
            }
        }

        return FontError.FileIsNotAFont_OR_IsUnsuportedFormat;
    }

    fn cff_get_subroutines(self: *FontFileReader, font_dict: *FontFileReader) ?FontFileReader {
        var subrs_offset = [1]u32{0};
        var private_loc = [2]u32{ 0, 0 };
        font_dict.read_cff_dict_ints_to_dst(18, private_loc[0..2]);
        if (private_loc[0] == 0 or private_loc[1] == 0) return null;
        var pdict = self.slice(private_loc[1], private_loc[0]);
        pdict.read_cff_dict_ints_to_dst(19, subrs_offset[0..1]);
        if (subrs_offset[0] == 0) return null;
        self.goto(private_loc[1 + subrs_offset[0]]);
        return self.cff_get_index();
    }
};

pub const FontInfo = struct {
    issues: u64 = FONT_ISSUE.NONE,
    user_data: *anyopaque = undefined,
    data: []const u8 = undefined,
    /// number of individual glyphs in this font
    num_glyphs: u32 = 0,
    /// the number of data tables in this font
    num_tables: u16 = 0,
    /// table locations as offsets from start of font data
    table: struct {
        loca: u32 = 0,
        head: u32 = 0,
        glyf: u32 = 0,
        hhea: u32 = 0,
        hmtx: u32 = 0,
        kern: u32 = 0,
        gpos: u32 = 0,
        svg: u32 = 0,
        maxp: u32 = 0,
        cff: u32 = 0,
        cmap: u32 = 0,
    } = .{},
    has_table: struct {
        loca: bool = false,
        head: bool = false,
        glyf: bool = false,
        hhea: bool = false,
        hmtx: bool = false,
        kern: bool = false,
        gpos: bool = false,
        svg: bool = false,
        maxp: bool = false,
        cff: bool = false,
        cmap: bool = false,
    } = .{},
    /// a cmap mapping for our chosen character encoding
    char_map: u32 = 0,
    /// format needed to map from glyph index to glyph
    index_to_loc_format: u32 = 0,
    cff_data: []const u8 = undefined,
    charstring_data: []const u8 = undefined,
    global_subroutine_data: []const u8 = undefined,
    private_subroutine_data: []const u8 = undefined,
    font_dicts: []const u8 = undefined,
    font_dict_select: []const u8 = undefined,

    inline fn init_num_tables(self: *FontInfo) void {
        self.num_tables = BigEnd.get_u16(self.data[4..]);
    }

    /// Returns `null` if table matching tag was not found
    fn find_table_location(self: *FontInfo, tag: u32) ?u32 {
        var idx: usize = 0;
        var pos: usize = 12;
        while (idx < self.num_tables) {
            const tag_at_pos = BigEnd.get_u32(self.data[pos..]);
            if (tag_at_pos == tag) {
                return BigEnd.get_u32(self.data[pos + 8 ..]);
            }
            idx += 1;
            pos += 16;
        }
        return null;
    }

    pub fn init_font(font_file_data: []const u8, offset: u32) FontInfo {
        //FIXME refactor to return FontError when error conditions occur
        var font = FontInfo{};
        font.data = FontFileReader{
            .data = font_file_data[offset..],
            .pos = 0,
        };
        font.init_num_tables();
        var reader = FontFileReader{
            .data = font.data,
            .pos = 0,
        };
        if (reader.find_table_location(FONT_TABLE.CMAP)) |loc| {
            font.has_table.cmap = true;
            font.table.cmap = loc;
        } else {
            font.issues |= FONT_ISSUE.NO_CMAP;
        }
        if (reader.find_table_location(FONT_TABLE.HEAD)) |loc| {
            font.has_table.head = true;
            font.table.head = loc;
        } else {
            font.issues |= FONT_ISSUE.NO_HEAD;
        }
        if (reader.find_table_location(FONT_TABLE.HHEA)) |loc| {
            font.has_table.hhea = true;
            font.table.hhea = loc;
        } else {
            font.issues |= FONT_ISSUE.NO_HHEA;
        }
        if (reader.find_table_location(FONT_TABLE.HMTX)) |loc| {
            font.has_table.hmtx = true;
            font.table.hmtx = loc;
        } else {
            font.issues |= FONT_ISSUE.NO_HMTX;
        }
        if (reader.find_table_location(FONT_TABLE.LOCA)) |loc| {
            font.has_table.loca = true;
            font.table.loca = loc;
        }
        if (reader.find_table_location(FONT_TABLE.GLYF)) |loc| {
            font.has_table.glyf = true;
            font.table.glyf = loc;
        }
        if (reader.find_table_location(FONT_TABLE.KERN)) |loc| {
            font.has_table.kern = true;
            font.table.kern = loc;
        }
        if (reader.find_table_location(FONT_TABLE.GPOS)) |loc| {
            font.has_table.gpos = true;
            font.table.gpos = loc;
        }
        if (font.issues > 0) return font;
        if (font.has_table.glyf and !font.has_table.loca) {
            // required for TrueType fonts
            font.issues |= FONT_ISSUE.GLYF_BUT_NO_LOCA;
            return font;
        } else {
            // initialize CFF / Type 2 font (OTF)
            var cstype = [1]u32{0};
            var charstrings = [1]u32{0};
            var fdarray_offset = [1]u32{0};
            var fdselect_offset = [1]u32{0};
            if (reader.find_table_location(FONT_TABLE.CFF)) |loc| {
                font.table.cff = loc;
                font.has_table.cff = true;
            } else {
                font.issues |= FONT_ISSUE.NO_CFF;
                return font;
            }
            var cff_reader = FontFileReader{
                .data = font.data[font.table.cff..], //TODO: find the actual end of the cff table
                .pos = 0,
            };
            cff_reader.skip(2);
            const hdrsize_loc = cff_reader.read_u8();
            cff_reader.goto(hdrsize_loc);
            //TODO: the "name" index entry could list multiple fonts, but we only use the first listed
            _ = cff_reader.cff_get_index(); // "name" index
            var topdict_idx = cff_reader.cff_get_index(); // "topdict" index
            var topdict = topdict_idx.cff_get_indexed_sub_slice(0); // "topdict" data
            _ = cff_reader.cff_get_index(); // "string" index
            font.global_subroutine_data = cff_reader.cff_get_index();

            topdict.read_cff_dict_ints_to_dst(17, charstrings[0..1]);
            topdict.read_cff_dict_ints_to_dst(0x100 | 6, cstype[0..1]);
            topdict.read_cff_dict_ints_to_dst(0x100 | 36, fdarray_offset[0..1]);
            topdict.read_cff_dict_ints_to_dst(0x100 | 37, fdselect_offset[0..1]);
            font.private_subroutine_data = cff_reader.cff_get_subroutines(&topdict);

            if (cstype[0] != 2) {
                font.issues |= FONT_ISSUE.CSTYPE_NOT_2;
                return font;
            }
            if (charstrings == 0) {
                font.issues |= FONT_ISSUE.NO_CHARSTRINGS;
                return font;
            }

            if (fdarray_offset[0] != 0) {
                if (fdselect_offset[0] == 0) {
                    font.issues |= FONT_ISSUE.FDARRAY_BUT_NO_FDSELECT;
                    return font;
                }
                reader.goto(fdarray_offset[0]);
                font.font_dicts = reader.cff_get_index();
                font.font_dict_select = reader.slice(fdselect_offset[0], font.data.len - fdselect_offset[0]);
            }

            reader.goto(charstrings[0]);
            font.charstring_data = reader.cff_get_index();
        }

        const maxp = font.find_table_location(FONT_TABLE.MAXP);
        if (maxp) |loc| {
            font.table.maxp = loc;
            font.has_table.maxp = true;
            font.num_glyphs = BigEnd.get_u16(font.data[loc + 4 ..]);
        } else {
            font.num_glyphs = 0xFFFF;
        }

        const num_cmap_tables = BigEnd.get_u16(font.data[font.table.cmap + 2]);
        var i: usize = 0;
        var encoding_loc = font.table.cmap + 4;
        while (i < num_cmap_tables) {
            switch (BigEnd.get_u16(font.data[encoding_loc..])) {
                PLATFORM_ID.WIN => switch (BigEnd.get_u16(font.data[encoding_loc + 2 ..])) {
                    WIN_EID.UNICODE_BMP, WIN_EID.UNICODE_FULL => {
                        font.char_map = font.table.cmap + BigEnd.get_u32(font.data[encoding_loc + 4 ..]);
                    },
                    else => {},
                },
                PLATFORM_ID.UNI => {
                    font.char_map = font.table.cmap + BigEnd.get_u32(font.data[encoding_loc + 4 ..]);
                },
                else => {},
            }
            i += 1;
            encoding_loc += 8;
        }
        if (font.char_map == 0) {
            font.issues |= FONT_ISSUE.NO_SUPPORTED_CMAP_ENCODING_TABLE;
            return font;
        }

        font.index_to_loc_format = BigEnd.get_u16(font.data[font.table.head + 50 ..]);
        return font;
    }

    fn find_glyph_index_from_utf8(self: *FontInfo, codepoint: u32) FontError!u32 {
        const char_map = self.char_map;

        try self.check_read_2_bytes_at(char_map);
        const format = self.read_u16(char_map);

        switch (format) {
            CMAP_FORMAT.ONE_BYTE => {
                try self.check_read_2_bytes_at(char_map + 2);
                const bytes_in_cmap = self.read_u16(char_map + 2);
                if (codepoint < bytes_in_cmap - 6) {
                    try self.check_read_1_byte_at(char_map + 6 + codepoint);
                    return self.read_u8(char_map + 6 + codepoint);
                }
                return 0;
            },
            CMAP_FORMAT.TWO_BYTE_DENSE => {
                try self.check_read_4_bytes_at(char_map + 6);
                const first_code: u32 = @intCast(self.read_u16(char_map + 6));
                const code_count: u32 = @intCast(self.read_u16(char_map + 8));
                if (codepoint >= first_code and codepoint <= first_code + code_count) {
                    const glyph_loc = char_map + 10 + ((codepoint - first_code) * 2);
                    try self.check_read_2_bytes_at(glyph_loc);
                    return self.read_u16(glyph_loc);
                }
                return 0;
            },
            CMAP_FORMAT.TWO_BYTE_SPARSE => {
                if (codepoint > 0xFFFF) return 0;

                try self.check_read_2_bytes_at(char_map + 12);
                const seg_count: u32 = @intCast(self.read_u16(char_map + 6) >> 1);
                var search_range: u32 = @intCast(self.read_u16(char_map + 8) >> 1);
                var entry_selector: u32 = @intCast(self.read_u16(char_map + 10));
                const range_shift: u32 = @intCast(self.read_u16(char_map + 10) >> 1);

                const end_count: u32 = char_map + 14;
                var search: u32 = end_count;

                try self.check_read_2_bytes_at(search + (range_shift << 1));
                if (codepoint >= self.read_u16(search + (range_shift << 1))) {
                    search += (range_shift << 1);
                }

                search -= 2;
                while (entry_selector > 0) {
                    try self.check_read_2_bytes_at(search + search_range);
                    const end = self.read_u16(search + search_range);
                    if (codepoint > end) {
                        search += search_range;
                    }
                    search_range >>= 1;
                    entry_selector -= 1;
                }
                search += 2;

                const item: u32 = ((search - end_count) >> 1);

                const start_loc: u32 = char_map + 14 + (seg_count << 1) + 2 + (2 * item);
                try self.check_read_2_bytes_at(start_loc);
                const start = self.read_u16(start_loc);

                const last_loc: u32 = end_count + (2 * item);
                try self.check_read_2_bytes_at(last_loc);
                const last = self.read_u16(last_loc);

                if (codepoint < start or codepoint > last) return 0;

                const offset_loc = char_map + 14 + (seg_count * 6) + 2 + (2 * item);
                try self.check_read_2_bytes_at(offset_loc);
                const offset = self.read_u16(offset_loc);

                if (offset == 0) {
                    const glyph_offset_loc = char_map + 14 + (seg_count * 4) + 2 + (2 * item);
                    try self.check_read_2_bytes_at(glyph_offset_loc);
                    const glyph_offset: i32 = @intCast(self.read_i16(glyph_offset_loc));
                    return @intCast(@as(i32, @intCast(codepoint)) + glyph_offset);
                }

                const glyph_loc = offset + ((codepoint - start) * 2) + char_map + 14 + (seg_count * 6) + 2 + (2 * item);
                try self.check_read_2_bytes_at(glyph_loc);
                return @intCast(self.read_u16(glyph_loc));
            },
            CMAP_FORMAT.FOUR_BYTE_SPARSE, CMAP_FORMAT.FOUR_BYTE_SPARSE_MANY_TO_ONE => {
                const num_groups_offset = char_map + 12;
                try self.check_read_4_bytes_at(num_groups_offset);
                const num_groups = self.read_u32(num_groups_offset);

                var low: i32 = 0;
                var high: i32 = @intCast(num_groups);

                while (low < high) {
                    const mid = low + ((high - low) >> 1);
                    const start_char_offset = char_map + 16 + (mid * 12);
                    const end_char_offset = start_char_offset + 4;
                    try self.check_read_4_bytes_at(end_char_offset);
                    const start_char = self.read_u32(start_char_offset);
                    const end_char = self.read_u32(end_char_offset);
                    if (codepoint < start_char) {
                        high = mid;
                    } else if (codepoint > end_char) {
                        low = mid + 1;
                    } else {
                        const start_glyph_offset = start_char_offset + 8;
                        try self.check_read_4_bytes_at(start_glyph_offset);
                        const start_glyph = self.read_u32(start_glyph_offset);
                        if (format == CMAP_FORMAT.FOUR_BYTE_SPARSE) {
                            return start_glyph + codepoint - start_char;
                        } else {
                            return start_glyph;
                        }
                    }
                }
                return 0;
            },
            else => {
                return FontError.cmap_format_not_supported;
            },
        }
    }

    inline fn check_read_1_byte_at(self: *const FontInfo, offset: usize) FontError!void {
        if (self.data.len <= offset) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn check_read_2_bytes_at(self: *const FontInfo, offset: usize) FontError!void {
        if (self.data.len < offset + 2) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn check_read_4_bytes_at(self: *const FontInfo, offset: usize) FontError!void {
        if (self.data.len < offset + 4) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn check_read_n_bytes_at(self: *const FontInfo, offset: usize, comptime count: usize) FontError!void {
        if (self.data.len < offset + count) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn read_u8(self: *const FontInfo, offset: u32) u8 {
        return self.data[offset];
    }
    inline fn read_i8(self: *const FontInfo, offset: u32) i8 {
        return @bitCast(self.read_u8(offset));
    }

    inline fn read_u16(self: *const FontInfo, offset: u32) u16 {
        return @as(u16, @intCast(self.data[offset])) << 8 | @as(u16, @intCast(self.data[offset + 1]));
    }
    inline fn read_i16(self: *const FontInfo, offset: u32) i16 {
        return @bitCast(self.read_u16(offset));
    }

    inline fn read_u32(self: *const FontInfo, offset: u32) u32 {
        assert(data.len >= 4);
        return @as(u32, @intCast(self.data[0])) << 24 | @as(u32, @intCast(self.data[offset + 1])) << 16 | @as(u32, @intCast(self.data[offset + 2])) << 8 | @as(u32, @intCast(self.data[offset + 3]));
    }
    inline fn read_i32(self: *const FontInfo, offset: u32) i32 {
        return @bitCast(self.read_u32(offset));
    }
};

/// Utility functions for reading values from a BigEndian byte buffer
const BigEnd = struct {
    inline fn get_u16(data: []const u8) u16 {
        assert(data.len >= 2);
        return @as(u16, @intCast(data[0])) << 8 | @as(u16, @intCast(data[1]));
    }
    inline fn get_i16(data: []const u8) i16 {
        return @bitCast(BigEnd.get_u16(data));
    }

    inline fn get_u32(data: []const u8) u32 {
        assert(data.len >= 4);
        return @as(u32, @intCast(data[0])) << 24 | @as(u32, @intCast(data[1])) << 16 | @as(u32, @intCast(data[2])) << 8 | @as(u32, @intCast(data[3]));
    }
    inline fn get_i32(data: []const u8) i32 {
        return @bitCast(BigEnd.get_u32(data));
    }
};

pub const FONT_ISSUE = struct {
    pub const NONE: u64 = 0;
    // ERROR class issues
    pub const NO_CMAP: u64 = 1 << 1;
    pub const NO_HEAD: u64 = 1 << 2;
    pub const NO_HHEA: u64 = 1 << 3;
    pub const NO_HMTX: u64 = 1 << 4;
    pub const GLYF_BUT_NO_LOCA: u64 = 1 << 5;
    pub const NO_CFF: u64 = 1 << 6;
    pub const CSTYPE_NOT_2: u64 = 1 << 7;
    pub const NO_CHARSTRINGS: u64 = 1 << 8;
    pub const FDARRAY_BUT_NO_FDSELECT: u64 = 1 << 9;
    pub const NO_SUPPORTED_CMAP_ENCODING_TABLE: u64 = 1 << 10;
};

const CMAP_FORMAT = struct {
    const ONE_BYTE: u16 = 0;
    const ONE_OR_TWO_BYTE_CJK: u16 = 2;
    const TWO_BYTE_SPARSE: u16 = 4;
    const TWO_BYTE_DENSE: u16 = 6;
    const TWO_OR_FOUR_BYTE: u16 = 8;
    const FOUR_BYTE_DENSE: u16 = 10;
    const FOUR_BYTE_SPARSE: u16 = 12;
    const FOUR_BYTE_SPARSE_MANY_TO_ONE: u16 = 13;
    const UNICODE_VAR_SEQ: u16 = 14;
};

const PLATFORM_ID = enum(u32) {
    UNI = 0,
    MAC = 1,
    ISO = 2,
    WIN = 3,
};

const UNICODE_EID = enum(u32) {
    UNICODE_1_0 = 0,
    UNICODE_1_1 = 1,
    ISO_10646 = 2,
    UNICODE_2_0_BMP = 3,
    UNICODE_2_0_FULL = 4,
};

const WIN_EID = enum(u32) {
    SYMBOL = 0,
    UNICODE_BMP = 1,
    SHIFTJIS = 2,
    UNICODE_FULL = 10,
};

const MAC_EID = enum(u32) {
    ROMAN = 0,
    JAPANESE = 1,
    CHINESE_TRAD = 2,
    KOREAN = 3,
    ARABIC = 4,
    HEBREW = 5,
    GREEK = 6,
    RUSSIAN = 7,
};

const WIN_LANG = enum(u32) {
    ENGLISH = 0x0409,
    CHINESE = 0x0804,
    DUTCH = 0x0413,
    FRENCH = 0x040C,
    GERMAN = 0x0407,
    HEBREW = 0x040D,
    ITALIAN = 0x0410,
    JAPANESE = 0x0411,
    KOREAN = 0x0412,
    RUSSIAN = 0x0419,
    SPANISH = 0x0409,
    SWEDISH = 0x041D,
};

const MAC_LANG = enum(u32) {
    ENGLISH = 0,
    FRENCH = 1,
    GERMAN = 2,
    ITALIAN = 3,
    DUTCH = 4,
    SWEDISH = 5,
    SPANISH = 6,
    HEBREW = 10,
    JAPANESE = 11,
    ARABIC = 12,
    CHINESE_TRAD = 19,
    KOREAN = 23,
    RUSSIAN = 32,
    CHINESE_SIMPLIFIED = 33,
};

pub const FontError = error{
    FontFileContainsOnlyOneFont_BUT_RequestedFontIndexGreaterThanZero,
    FontCollectionIsUnsuportedVersion,
    FontIndexGreaterThanNumberOfFontsInCollection,
    RequiredTableNotFound_CMAP,
    RequiredTableNotFound_LOCA,
    RequiredTableNotFound_HEAD,
    RequiredTableNotFound_GLYF,
    RequiredTableNotFound_HHEA,
    RequiredTableNotFound_HMTX,
    RequiredTableNotFound_KERN,
    RequiredTableNotFound_GPOS,

    font_attempted_to_read_past_its_own_data,
    cmap_format_not_supported,
};
