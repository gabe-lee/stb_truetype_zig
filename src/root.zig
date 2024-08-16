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

    inline fn check_slice(self: *FontFileReader, start: u32, len: u32) FontError!void {
        if (self.data.len < start + len) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn slice(self: *FontFileReader, start: usize, len: usize) FontFileReader {
        return FontFileReader{
            .data = self.data[start .. start + len],
            .pos = 0,
        };
    }

    inline fn check_goto(self: *FontFileReader, offset: u32) FontError!void {
        if (self.data.len <= offset) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn goto(self: *FontFileReader, offset: u32) void {
        self.pos = offset;
    }

    inline fn check_skip(self: *FontFileReader, count: u32) FontError!void {
        if (self.data.len <= self.pos + count) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn skip(self: *FontFileReader, count: u32) void {
        self.pos += count;
    }

    inline fn check_read_1_byte(self: *FontFileReader) FontError!void {
        return BigEnd.check_read_1_byte_at(self.data, self.pos);
    }

    inline fn check_read_2_bytes(self: *FontFileReader) FontError!void {
        return BigEnd.check_read_2_bytes_at(self.data, self.pos);
    }

    inline fn check_read_4_bytes(self: *FontFileReader) FontError!void {
        return BigEnd.check_read_4_bytes_at(self.data, self.pos);
    }

    inline fn check_read_n_bytes_comptime(self: *FontFileReader, comptime count: usize) FontError!void {
        return BigEnd.check_read_n_bytes_at_comptime(self.data, self.pos, count);
    }

    inline fn check_read_n_bytes(self: *FontFileReader, count: usize) FontError!void {
        return BigEnd.check_read_n_bytes_at(self.data, self.pos, count);
    }

    inline fn peek_u8(self: *FontFileReader) u8 {
        return BigEnd.read_u8(self.data, self.pos);
    }
    inline fn peek_i8(self: *FontFileReader) i8 {
        return BigEnd.read_i8(self.data, self.pos);
    }
    inline fn read_u8(self: *FontFileReader) u8 {
        const read_pos = self.pos;
        self.pos += 1;
        return BigEnd.read_u8(self.data, read_pos);
    }
    inline fn read_i8(self: *FontFileReader) i8 {
        const read_pos = self.pos;
        self.pos += 1;
        return BigEnd.read_i8(self.data, read_pos);
    }

    inline fn peek_u16(self: *FontFileReader) u16 {
        return BigEnd.read_u16(self.data, self.pos);
    }
    inline fn peek_i16(self: *FontFileReader) i16 {
        return BigEnd.read_i16(self.data, self.pos);
    }
    inline fn read_u16(self: *FontFileReader) u16 {
        const read_pos = self.pos;
        self.pos += 2;
        return BigEnd.read_u16(self.data, read_pos);
    }
    inline fn read_i16(self: *FontFileReader) i16 {
        const read_pos = self.pos;
        self.pos += 2;
        return BigEnd.read_i16(self.data, read_pos);
    }

    inline fn peek_u32(self: *FontFileReader) u32 {
        return BigEnd.read_u32(self.data, self.pos);
    }
    inline fn peek_i32(self: *FontFileReader) i32 {
        return BigEnd.read_i32(self.data, self.pos);
    }
    inline fn read_u32(self: *FontFileReader) u32 {
        const read_pos = self.pos;
        self.pos += 4;
        return BigEnd.read_u32(self.data, read_pos);
    }
    inline fn read_i32(self: *FontFileReader) i32 {
        const read_pos = self.pos;
        self.pos += 4;
        return BigEnd.read_i32(self.data, read_pos);
    }

    inline fn peek_n_bytes_to_u32(self: *FontFileReader, count: u8) u32 {
        return BigEnd.read_n_bytes_to_u32(self.data, self.pos, count);
    }
    inline fn read_n_bytes_to_u32(self: *FontFileReader, count: u8) u32 {
        const read_pos = self.pos;
        self.pos += count;
        return BigEnd.read_n_bytes_to_u32(self.data, read_pos, count);
    }

    fn cff_get_index(self: *FontFileReader) FontError!FontFileReader {
        const start = self.pos;
        try self.check_read_2_bytes();
        const count = self.read_u16();
        if (count > 0) {
            try self.check_read_1_byte();
            const offsize = self.read_u8();
            var skip_bytes = offsize * count;
            try self.check_skip(skip_bytes);
            self.skip(offsize * count);
            try self.check_read_n_bytes(offsize);
            skip_bytes = self.read_n_bytes_to_u32(offsize) - 1;
            try self.check_skip(skip_bytes);
            self.skip(skip_bytes);
        }
        return self.slice(start, self.pos - start);
    }

    fn read_cff_int(self: *FontFileReader) FontError!u32 {
        try self.check_read_1_byte();
        const byte_0: u32 = @intCast(self.read_u8());
        switch (byte_0) {
            28 => {
                try self.check_read_2_bytes();
                return @intCast(self.read_u16());
            },
            29 => {
                try self.check_read_4_bytes();
                return self.read_u32();
            },
            32...246 => {
                return byte_0 - 139;
            },
            247...250 => {
                try self.check_read_1_byte();
                return ((byte_0 - 247) * 256) + self.read_u8() + 108;
            },
            251...254 => {
                try self.check_read_1_byte();
                return -((byte_0 - 251) * 256) - self.read_u8() - 108;
            },
            else => return FontError.read_cff_int_invalid_byte_0,
        }
    }

    fn skip_cff_operand(self: *FontFileReader) FontError!void {
        try self.check_read_1_byte();
        const byte_0: u8 = self.read_u8();
        if (byte_0 == 30) {
            try self.check_skip(1);
            self.skip(1);
            while (self.pos < self.data.len) {
                try self.check_read_1_byte();
                const val = self.read_u8();
                if (((val & 0xF) == 0xF) or ((val >> 4) == 0xF)) break;
            }
        } else {
            _ = try self.read_cff_int();
        }
    }

    /// Returns `null` if no cff dict matching key was found
    fn get_cff_dict_slice(self: *FontFileReader, key: u32) FontError!FontFileReader {
        self.goto(0);
        while (self.pos < self.data.len) {
            const start = self.pos;
            try self.check_read_1_byte();
            var byte_0 = self.peek_u8();
            while (byte_0 >= 28) {
                try self.skip_cff_operand();
                try self.check_read_1_byte();
                byte_0 = self.peek_u8();
            }
            const end = self.pos;
            try self.check_read_1_byte();
            var op: u32 = @intCast(self.read_u8());
            if (op == 12) {
                try self.check_read_1_byte();
                op = @as(u32, @intCast(self.read_u8())) | 0x100;
            }
            if (op == key) return self.slice(start, end - start);
        }
        return FontError.missing_cff_dict;
    }

    /// Writes dict ints to destination slice
    ///
    /// Returns `false` if no dict matching key was found
    fn read_cff_dict_ints(self: *FontFileReader, key: u32, comptime count: comptime_int) FontError![count]u32 {
        const operands = try self.get_cff_dict_slice(key);
        var output: [count]u32 = undefined;
        var i: usize = 0;
        while (i < count) {
            output[i] = try operands.read_cff_int();
            i += 1;
        }
        return output;
    }

    inline fn cff_index_count(self: *FontFileReader) FontError!u16 {
        self.goto(0);
        try self.check_read_2_bytes();
        return self.read_u16();
    }

    inline fn check_index_less_than_count(idx: u32, count: u32) FontError!void {
        if (idx >= count) return FontError.requested_index_greater_than_max_index;
    }

    inline fn check_offsize(offsize: u8) FontError!void {
        if (offsize < 1 or offsize > 4) return FontError.cff_offset_size_malformed;
    }

    fn cff_get_indexed_sub_slice(self: *FontFileReader, idx_key: u32) FontError!FontFileReader {
        const count = try self.cff_index_count();
        try check_index_less_than_count(idx_key, count);
        try self.check_read_1_byte();
        const offsize = self.read_u8();
        try check_offsize(offsize);
        const skip_count = idx_key * offsize;
        try BigEnd.check_read_4_bytes_at(self.data, self.pos + skip_count + 4);
        self.skip(skip_count);
        const sub_start = self.read_n_bytes_to_u32(offsize);
        const sub_end = self.read_n_bytes_to_u32(offsize);
        const slice_start: u32 = ((count + 1) * offsize) + 2 + sub_start;
        const slice_len: u32 = sub_end - sub_start;
        try self.check_slice(slice_start, slice_len);
        return self.slice(slice_start, slice_len);
    }

    fn is_font(self: *FontFileReader) FontError!bool {
        try BigEnd.check_read_4_bytes_at(self.data, 0);
        const font_tag = BigEnd.read_u32(self.data, 0);
        return switch (font_tag) {
            FONT_FORMAT.TRUE_TYPE_1 => true,
            FONT_FORMAT.TRUE_TYPE_WITH_TYPE_1 => true,
            FONT_FORMAT.OPEN_TYPE_WITH_CFF => true,
            FONT_FORMAT.OPEN_TYPE_1 => true,
            FONT_FORMAT.TRUE_TYPE_APPLE => true,
            else => false,
        };
    }

    inline fn is_font_collection(self: *FontFileReader) FontError!bool {
        try BigEnd.check_read_4_bytes_at(self.data, 0);
        const font_tag = BigEnd.read_u32(self.data, 0);
        return font_tag == FONT_FORMAT.FONT_COLLECTION;
    }

    inline fn font_collection_is_ver_1(self: *FontFileReader) FontError!bool {
        try BigEnd.check_read_4_bytes_at(self.data, 4);
        const ver = BigEnd.read_u32(self.data, 4);
        return ver == 0x00010000 or ver == 0x00020000;
    }

    fn get_number_of_fonts_in_file(self: *FontFileReader) FontError!u32 {
        if (try self.is_font()) {
            return 1;
        }

        if (try self.is_font_collection()) {
            if (try self.font_collection_is_ver_1()) {
                try BigEnd.check_read_4_bytes_at(self.data, 8);
                return BigEnd.read_u32(self.data, 8);
            }
            return FontError.font_collection_is_unsupported_version;
        }

        return FontError.file_is_not_a_font_OR_is_unsupported_format;
    }

    fn get_byte_offset_for_font_index(self: *FontFileReader, index: usize) FontError!u32 {
        if (try self.is_font()) {
            if (index == 0) return 0;
            return FontError.file_contains_only_one_font_BUT_requested_font_index_greater_than_zero;
        }

        if (try self.is_font_collection()) {
            if (try self.font_collection_is_ver_1()) {
                try BigEnd.check_read_4_bytes_at(self.data, 8);
                const num_fonts = BigEnd.read_u32(self.data, 8);
                if (index >= num_fonts) return FontError.font_index_greater_than_number_of_fonts_in_collection;
                const offset_loc = 12 + (index * 4);
                try BigEnd.check_read_4_bytes_at(self.data, offset_loc);
                return BigEnd.read_u32(self.data, offset_loc);
            }
        }

        return FontError.file_is_not_a_font_OR_is_unsupported_format;
    }

    fn cff_get_subroutines(self: *FontFileReader, font_dict: *FontFileReader) FontError!FontFileReader {
        const private_loc = try font_dict.read_cff_dict_ints(18, 2);
        if (private_loc[0] == 0 or private_loc[1] == 0) return FontError.no_cff_subroutines;
        try self.check_slice(private_loc[1], private_loc[0]);
        var pdict = self.slice(private_loc[1], private_loc[0]);
        const subrs_offset = try pdict.read_cff_dict_ints(19, 1);
        if (subrs_offset[0] == 0) return FontError.no_cff_subroutines;
        const goto_loc = private_loc[1] + subrs_offset;
        try self.check_goto(goto_loc);
        self.goto(goto_loc);
        return try self.cff_get_index();
    }
};

pub const FontInfo = struct {
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
        loca: HAS_TABLE = .UNKNOWN,
        head: HAS_TABLE = .UNKNOWN,
        glyf: HAS_TABLE = .UNKNOWN,
        hhea: HAS_TABLE = .UNKNOWN,
        hmtx: HAS_TABLE = .UNKNOWN,
        kern: HAS_TABLE = .UNKNOWN,
        gpos: HAS_TABLE = .UNKNOWN,
        svg: HAS_TABLE = .UNKNOWN,
        maxp: HAS_TABLE = .UNKNOWN,
        cff: HAS_TABLE = .UNKNOWN,
        cmap: HAS_TABLE = .UNKNOWN,
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

    /// Returns `FontError.no_table_matching_tag` if table matching tag was not found
    fn find_table_location(self: *FontInfo, tag: u32) FontError!u32 {
        var idx: usize = 0;
        var pos: usize = 12;
        const max_read = 12 + ((self.num_tables - 1) * 16) + 8;
        try BigEnd.check_read_4_bytes_at(self.data, max_read);
        while (idx < self.num_tables) {
            const tag_at_pos = BigEnd.read_u32(self.data, pos);
            if (tag_at_pos == tag) {
                return BigEnd.read_u32(self.data, pos + 8);
            }
            idx += 1;
            pos += 16;
        }
        return FontError.no_table_matching_tag;
    }

    pub fn init_font(font_file_data: []const u8, offset: u32) FontError!FontInfo {
        var font = FontInfo{};
        font.data = FontFileReader{
            .data = font_file_data[offset..],
            .pos = 0,
        };

        try font.check_read_2_bytes_at(4);
        font.num_tables = font.read_u16(4);

        var reader = FontFileReader{
            .data = font.data,
            .pos = 0,
        };
        //TODO find all required tables in one loop and cache optional tables found
        if (font.find_table_location(FONT_TABLE.CMAP)) |loc| {
            font.has_table.cmap = .TRUE;
            font.table.cmap = loc;
        } else |err| switch (err) {
            .no_table_matching_tag => {
                return FontError.required_table_not_found__cmap;
            },
            else => return err,
        }
        if (font.find_table_location(FONT_TABLE.HEAD)) |loc| {
            font.has_table.head = .TRUE;
            font.table.head = loc;
        } else |err| switch (err) {
            .no_table_matching_tag => {
                return FontError.required_table_not_found__head;
            },
            else => return err,
        }
        if (font.find_table_location(FONT_TABLE.HHEA)) |loc| {
            font.has_table.hhea = .TRUE;
            font.table.hhea = loc;
        } else |err| switch (err) {
            .no_table_matching_tag => {
                return FontError.required_table_not_found__hhea;
            },
            else => return err,
        }
        if (font.find_table_location(FONT_TABLE.HMTX)) |loc| {
            font.has_table.hmtx = .TRUE;
            font.table.hmtx = loc;
        } else |err| switch (err) {
            .no_table_matching_tag => {
                return FontError.required_table_not_found__hmtx;
            },
            else => return err,
        }
        if (font.find_table_location(FONT_TABLE.LOCA)) |loc| {
            font.has_table.loca = .TRUE;
            font.table.loca = loc;
        } else |err| switch (err) {
            .no_table_matching_tag => {
                font.has_table.loca = .FALSE;
            },
            else => return err,
        }
        if (font.find_table_location(FONT_TABLE.GLYF)) |loc| {
            font.has_table.glyf = .TRUE;
            font.table.glyf = loc;
        } else |err| switch (err) {
            .no_table_matching_tag => {
                font.has_table.glyf = .FALSE;
            },
            else => return err,
        }
        if (font.find_table_location(FONT_TABLE.KERN)) |loc| {
            font.has_table.kern = .TRUE;
            font.table.kern = loc;
        } else |err| switch (err) {
            .no_table_matching_tag => {
                font.has_table.kern = .FALSE;
            },
            else => return err,
        }
        if (font.find_table_location(FONT_TABLE.GPOS)) |loc| {
            font.has_table.gpos = .TRUE;
            font.table.gpos = loc;
        } else |err| switch (err) {
            .no_table_matching_tag => {
                font.has_table.gpos = .FALSE;
            },
            else => return err,
        }
        if (font.has_table.glyf == .TRUE and font.has_table.loca != .TRUE) {
            // required for TrueType fonts
            return FontError.glyf_table_but_no_loca_table;
        } else {
            // initialize CFF / Type 2 font (OTF)
            if (font.find_table_location(FONT_TABLE.CFF)) |loc| {
                font.table.cff = loc;
                font.has_table.cff = .TRUE;
            } else |err| switch (err) {
                .no_table_matching_tag => {
                    return FontError.cff_font_has_no_cff_table;
                },
                else => return err,
            }
            var cff_reader = FontFileReader{
                .data = font.data[font.table.cff..], //TODO: find the actual end of the cff table
                .pos = 0,
            };
            try BigEnd.check_read_1_byte_at(cff_reader.data, 2);
            cff_reader.skip(2);
            const hdrsize_loc = cff_reader.read_u8();
            try cff_reader.check_goto(hdrsize_loc);
            cff_reader.goto(hdrsize_loc);
            //TODO: the "name" index entry could list multiple fonts, but we only use the first listed
            _ = try cff_reader.cff_get_index(); // "name" index
            var topdict_idx = try cff_reader.cff_get_index(); // "topdict" index
            var topdict = try topdict_idx.cff_get_indexed_sub_slice(0); // "topdict" data
            _ = try cff_reader.cff_get_index(); // "string" index
            font.global_subroutine_data = (try cff_reader.cff_get_index()).data;

            const charstrings = try topdict.read_cff_dict_ints(17, 1);
            const cstype = try topdict.read_cff_dict_ints(0x100 | 6, 1);
            const fdarray_offset = try topdict.read_cff_dict_ints(0x100 | 36, 1);
            const fdselect_offset = try topdict.read_cff_dict_ints(0x100 | 37, 1);
            font.private_subroutine_data = (try cff_reader.cff_get_subroutines(&topdict)).data;

            if (cstype != 2) return FontError.cff_cstype_must_be_2;
            if (charstrings == 0) return FontError.cff_no_charstrings;

            if (fdarray_offset != 0) {
                if (fdselect_offset == 0) return FontError.cff_fdarray_but_no_fdselect;
                try reader.check_goto(fdarray_offset);
                reader.goto(fdarray_offset);
                font.font_dicts = try reader.cff_get_index();
                //TODO font.data.len - fdselect_offset could cause unhandled panic
                try reader.check_slice(fdselect_offset, font.data.len - fdselect_offset);
                font.font_dict_select = reader.slice(fdselect_offset, font.data.len - fdselect_offset);
            }
            try reader.check_goto(charstrings);
            reader.goto(charstrings);
            font.charstring_data = try reader.cff_get_index();
        }

        const maxp = font.find_table_location(FONT_TABLE.MAXP);
        if (maxp) |loc| {
            font.table.maxp = loc;
            font.has_table.maxp = .TRUE;
            try font.check_read_2_bytes_at(loc + 4);
            font.num_glyphs = font.read_u16(loc + 4);
        } else |err| switch (err) {
            .no_table_matching_tag => {
                font.has_table.maxp = .FALSE;
                font.num_glyphs = 0xFFFF;
            },
            else => return err,
        }

        try font.check_read_2_bytes_at(font.table.cmap + 2);
        const num_cmap_tables = font.read_u16(font.table.cmap + 2);
        var i: usize = 0;
        var encoding_loc = font.table.cmap + 4;
        const max_read = encoding_loc + ((num_cmap_tables - 1) * 8) + 4;
        try font.check_read_4_bytes_at(max_read);
        while (i < num_cmap_tables) {
            switch (font.read_u16(encoding_loc)) {
                PLATFORM_ID.WIN => switch (font.read_u16(encoding_loc + 2)) {
                    WIN_EID.UNICODE_BMP, WIN_EID.UNICODE_FULL => {
                        font.char_map = font.table.cmap + font.read_u32(encoding_loc + 4);
                    },
                    else => {},
                },
                PLATFORM_ID.UNI => {
                    font.char_map = font.table.cmap + font.read_u32(encoding_loc + 4);
                },
                else => {},
            }
            i += 1;
            encoding_loc += 8;
        }
        if (font.char_map == 0) return FontError.no_supported_cmap_encoding_table;
        const font_to_loc_format_loc = font.table.head + 50;
        try font.check_read_2_bytes_at(font_to_loc_format_loc);
        font.index_to_loc_format = font.read_u16(font_to_loc_format_loc);
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

    //TODO: stbtt_GetCodepointShape

    inline fn check_read_1_byte_at(self: *const FontInfo, offset: usize) FontError!void {
        return BigEnd.check_read_1_byte_at(self.data, offset);
    }

    inline fn check_read_2_bytes_at(self: *const FontInfo, offset: usize) FontError!void {
        return BigEnd.check_read_2_bytes_at(self.data, offset);
    }

    inline fn check_read_4_bytes_at(self: *const FontInfo, offset: usize) FontError!void {
        return BigEnd.check_read_4_bytes_at(self.data, offset);
    }

    inline fn check_read_n_bytes_at_comptime(self: *const FontInfo, offset: usize, comptime count: usize) FontError!void {
        return BigEnd.check_read_n_bytes_at_comptime(self.data, offset, count);
    }

    inline fn check_read_n_bytes_at(self: *const FontInfo, offset: usize, count: usize) FontError!void {
        return BigEnd.check_read_n_bytes_at(self.data, offset, count);
    }

    inline fn read_u8(self: *const FontInfo, offset: u32) u8 {
        return BigEnd.read_u8(self.data, offset);
    }
    inline fn read_i8(self: *const FontInfo, offset: u32) i8 {
        return BigEnd.read_i8(self.data, offset);
    }

    inline fn read_u16(self: *const FontInfo, offset: u32) u16 {
        return BigEnd.read_u16(self.data, offset);
    }
    inline fn read_i16(self: *const FontInfo, offset: u32) i16 {
        return BigEnd.read_i16(self.data, offset);
    }

    inline fn read_u32(self: *const FontInfo, offset: u32) u32 {
        return BigEnd.read_u32(self.data, offset);
    }
    inline fn read_i32(self: *const FontInfo, offset: u32) i32 {
        return BigEnd.read_i32(self.data, offset);
    }
};

/// Utility functions for reading values from a BigEndian byte buffer
const BigEnd = struct {
    inline fn check_read_1_byte_at(data: []const u8, offset: usize) FontError!void {
        if (data.len <= offset) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn check_read_2_bytes_at(data: []const u8, offset: usize) FontError!void {
        if (data.len < offset + 2) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn check_read_4_bytes_at(data: []const u8, offset: usize) FontError!void {
        if (data.len < offset + 4) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn check_read_n_bytes_at_comptime(data: []const u8, offset: usize, comptime count: usize) FontError!void {
        if (data.len < offset + count) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn check_read_n_bytes_at(data: []const u8, offset: usize, count: usize) FontError!void {
        if (data.len < offset + count) return FontError.font_attempted_to_read_past_its_own_data;
    }

    inline fn read_u8(data: []const u8, offset: u32) u8 {
        return data[offset];
    }
    inline fn read_i8(data: []const u8, offset: u32) i8 {
        return @bitCast(BigEnd.read_u8(data, offset));
    }

    inline fn read_u16(data: []const u8, offset: u32) u16 {
        return @as(u16, @intCast(data[offset])) << 8 | @as(u16, @intCast(data[offset + 1]));
    }
    inline fn read_i16(data: []const u8, offset: u32) i16 {
        return @bitCast(BigEnd.read_u16(data, offset));
    }

    inline fn read_u32(data: []const u8, offset: u32) u32 {
        return @as(u32, @intCast(data[0])) << 24 | @as(u32, @intCast(data[offset + 1])) << 16 | @as(u32, @intCast(data[offset + 2])) << 8 | @as(u32, @intCast(data[offset + 3]));
    }
    inline fn read_i32(data: []const u8, offset: u32) i32 {
        return @bitCast(BigEnd.read_u32(data, offset));
    }

    inline fn check_read_n_bytes_to_u32_count(count: u8) FontError!void {
        if (count < 1 or count > 4) return FontError.cff_offset_size_malformed;
    }

    inline fn read_n_bytes_to_u32(data: []const u8, offset: u32, count: u8) u32 {
        return switch (count) {
            1 => @as(u32, @intCast(data[offset])),
            2 => @as(u32, @intCast(data[offset] << 8)) | @as(u32, @intCast(data[offset + 1])),
            3 => @as(u32, @intCast(data[offset] << 16)) | @as(u32, @intCast(data[offset + 1] << 8)) | @as(u32, @intCast(data[offset + 2])),
            4 => @as(u32, @intCast(data[offset] << 24)) | @as(u32, @intCast(data[offset + 1] << 16)) | @as(u32, @intCast(data[offset + 2] << 8)) | @as(u32, @intCast(data[offset + 3])),
            else => unreachable,
        };
    }
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

pub const HAS_TABLE = enum(u8) {
    FALSE = 0,
    TRUE = 1,
    UNKNOWN = 2,
};

pub const FontError = error{
    file_is_not_a_font_OR_is_unsupported_format,
    file_contains_only_one_font_BUT_requested_font_index_greater_than_zero,
    font_collection_is_unsupported_version,
    font_index_greater_than_number_of_fonts_in_collection,
    required_table_not_found__cmap,
    required_table_not_found__head,
    required_table_not_found__hhea,
    required_table_not_found__hmtx,
    font_attempted_to_read_past_its_own_data,
    cmap_format_not_supported,
    cff_offset_size_malformed,
    read_cff_int_invalid_byte_0,
    missing_cff_dict,
    requested_index_greater_than_max_index,
    no_cff_subroutines,
    no_table_matching_tag,
    cff_font_has_no_cff_table,
    cff_cstype_must_be_2,
    cff_no_charstrings,
    cff_fdarray_but_no_fdselect,
    no_supported_cmap_encoding_table,
};
