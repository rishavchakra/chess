const std = @import("std");
const gl = @cImport({
    // Disables GLFW's inclusion of GL libraries
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
    @cInclude("glad/glad.h");
});
const img = @cImport({
    @cInclude("stb_image.h");
});
const board = @import("../board.zig");
const piece = @import("../piece.zig");
const bitboard = @import("../bitboard.zig");

pub const RenderError = error{
    WindowInitError,
    WindowCreationError,
    GLInitError,
    VertShaderCompilationError,
    FragShaderCompilationError,
    ShaderLinkError,
};

pub const RenderState = struct {
    const Self = @This();

    board_shader: c_uint,
    piece_shader: c_uint,
    highlight_square_shader: c_uint,
    board_bufs: Buffers,
    piece_bufs: Buffers,
    highlight_bufs: Buffers,
    textures: [12]c_uint,

    pub fn init() RenderError!Self {
        const board_vert_shader = try createShader(ShaderType.Vertex, "board.vert");
        const board_frag_shader = try createShader(ShaderType.Fragment, "board.frag");
        const board_shader_program = try createShaderProgram(&[_]c_uint{ board_vert_shader, board_frag_shader });
        deleteShader(board_vert_shader);
        deleteShader(board_frag_shader);

        const highlight_square_vert_shader = try createShader(ShaderType.Vertex, "highlight_square.vert");
        const highlight_square_frag_shader = try createShader(ShaderType.Fragment, "highlight_square.frag");
        const highlight_square_shader_program = try createShaderProgram(&[_]c_uint{ highlight_square_vert_shader, highlight_square_frag_shader });
        deleteShader(highlight_square_vert_shader);
        deleteShader(highlight_square_frag_shader);

        const piece_vert_shader = try createShader(ShaderType.Vertex, "piece.vert");
        const piece_frag_shader = try createShader(ShaderType.Fragment, "piece.frag");
        const piece_shader_program = try createShaderProgram(&[_]c_uint{ piece_vert_shader, piece_frag_shader });
        deleteShader(piece_vert_shader);
        deleteShader(piece_frag_shader);
        const textures = [_]c_uint{
            createTexture("assets/pieces/white-pawn.png"),
            createTexture("assets/pieces/white-bishop.png"),
            createTexture("assets/pieces/white-knight.png"),
            createTexture("assets/pieces/white-rook.png"),
            createTexture("assets/pieces/white-queen.png"),
            createTexture("assets/pieces/white-king.png"),
            createTexture("assets/pieces/black-pawn.png"),
            createTexture("assets/pieces/black-bishop.png"),
            createTexture("assets/pieces/black-knight.png"),
            createTexture("assets/pieces/black-rook.png"),
            createTexture("assets/pieces/black-queen.png"),
            createTexture("assets/pieces/black-king.png"),
        };

        const board_bufs = createChessBoardBufs();
        const piece_bufs = createPieceBufs();
        const highlight_bufs = createBitboardBufs();

        gl.glClearColor(0.46, 0.59, 0.34, 1.0);
        gl.glUseProgram(piece_shader_program);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex0"), 0);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex1"), 1);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex2"), 2);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex3"), 3);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex4"), 4);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex5"), 5);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex6"), 6);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex7"), 7);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex8"), 8);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex9"), 9);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex10"), 10);
        gl.glUniform1i(gl.glGetUniformLocation(piece_shader_program, "tex11"), 11);

        gl.glActiveTexture(gl.GL_TEXTURE0);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[0]);
        gl.glActiveTexture(gl.GL_TEXTURE1);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[1]);
        gl.glActiveTexture(gl.GL_TEXTURE2);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[2]);
        gl.glActiveTexture(gl.GL_TEXTURE3);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[3]);
        gl.glActiveTexture(gl.GL_TEXTURE4);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[4]);
        gl.glActiveTexture(gl.GL_TEXTURE5);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[5]);
        gl.glActiveTexture(gl.GL_TEXTURE6);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[6]);
        gl.glActiveTexture(gl.GL_TEXTURE7);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[7]);
        gl.glActiveTexture(gl.GL_TEXTURE8);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[8]);
        gl.glActiveTexture(gl.GL_TEXTURE9);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[9]);
        gl.glActiveTexture(gl.GL_TEXTURE10);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[10]);
        gl.glActiveTexture(gl.GL_TEXTURE11);
        gl.glBindTexture(gl.GL_TEXTURE_2D, textures[11]);

        return Self{
            .board_shader = board_shader_program,
            .piece_shader = piece_shader_program,
            .highlight_square_shader = highlight_square_shader_program,
            .board_bufs = board_bufs,
            .piece_bufs = piece_bufs,
            .highlight_bufs = highlight_bufs,
            .textures = textures,
        };
    }

    pub fn render(self: Self) void {
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        gl.glUseProgram(self.board_shader);
        gl.glBindVertexArray(self.board_bufs.VAO);
        gl.glDrawElements(gl.GL_TRIANGLES, 6, gl.GL_UNSIGNED_INT, null);

        gl.glUseProgram(self.highlight_square_shader);
        gl.glBindVertexArray(self.highlight_bufs.VAO);
        gl.glDrawElements(gl.GL_TRIANGLES, bitboard_inds_len, gl.GL_UNSIGNED_INT, null);

        gl.glUseProgram(self.piece_shader);
        gl.glBindVertexArray(self.piece_bufs.VAO);
        gl.glDrawElements(gl.GL_TRIANGLES, pieces_inds_len, gl.GL_UNSIGNED_INT, null);

        gl.glBindVertexArray(0);
    }

    pub fn updatePiecePositions(self: Self, game_board: board.Board) void {
        updatePieceBufs(self.piece_bufs, game_board);
    }

    pub fn updateBitboardDisplay(self: Self, render_bitboard: bitboard.Bitboard) void {
        updateBitboardBufs(self.highlight_bufs, render_bitboard);
    }
};

pub const WindowState = struct {
    const Self = @This();

    window_handle: *gl.struct_GLFWwindow,

    pub fn init() RenderError!Self {
        const glfw_init_res = gl.glfwInit();
        if (glfw_init_res == 0) {
            return RenderError.WindowInitError;
        }

        gl.glfwWindowHint(gl.GLFW_CONTEXT_VERSION_MAJOR, 3);
        gl.glfwWindowHint(gl.GLFW_CONTEXT_VERSION_MINOR, 3);
        gl.glfwWindowHint(gl.GLFW_OPENGL_PROFILE, gl.GLFW_OPENGL_CORE_PROFILE);
        gl.glfwWindowHint(gl.GLFW_OPENGL_FORWARD_COMPAT, gl.GL_TRUE);

        const window = gl.glfwCreateWindow(800, 800, "Chess", null, null) orelse return RenderError.WindowCreationError;

        gl.glfwMakeContextCurrent(window);

        const glad_init_res = gl.gladLoadGLLoader(@ptrCast(&gl.glfwGetProcAddress));
        if (glad_init_res == 0) {
            return RenderError.GLInitError;
        }

        gl.glEnable(gl.GL_TEXTURE_2D);
        gl.glEnable(gl.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
        gl.glDisable(gl.GL_DEPTH_TEST);

        return Self{
            .window_handle = window,
        };
    }

    pub fn deinit(self: *const Self) void {
        gl.glfwTerminate();
        gl.glfwDestroyWindow(self.window_handle);
    }

    pub fn isRunning(self: *const Self) bool {
        return gl.glfwWindowShouldClose(self.window_handle) == 0;
    }

    pub fn draw(self: *const Self) void {
        gl.glfwSwapBuffers(self.window_handle);
        gl.glfwPollEvents();
    }
};

const ShaderType = enum {
    Vertex,
    Fragment,
};
fn createShader(shader_type: ShaderType, comptime shader_path: []const u8) RenderError!c_uint {
    const shader_src_ptr: [*c]const u8 = @ptrCast(@embedFile(shader_path));

    const shader = switch (shader_type) {
        ShaderType.Vertex => gl.glCreateShader(gl.GL_VERTEX_SHADER),
        ShaderType.Fragment => gl.glCreateShader(gl.GL_FRAGMENT_SHADER),
    };
    gl.glShaderSource(shader, 1, &shader_src_ptr, null);
    gl.glCompileShader(shader);

    // Error handling
    var success: c_int = undefined;
    var info_log: [512]u8 = undefined;
    gl.glGetShaderiv(shader, gl.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        gl.glGetShaderInfoLog(shader, 512, null, &info_log);
        std.debug.print("ERROR: Vertex compilation\n{s}\n", .{info_log});
        return switch (shader_type) {
            ShaderType.Vertex => RenderError.VertShaderCompilationError,
            ShaderType.Fragment => RenderError.FragShaderCompilationError,
        };
    }
    return shader;
}

fn deleteShader(shader: c_uint) void {
    gl.glDeleteShader(shader);
}

fn createShaderProgram(shader_arr: []const c_uint) RenderError!c_uint {
    const shader_program = gl.glCreateProgram();
    for (shader_arr) |shader| {
        gl.glAttachShader(shader_program, shader);
    }
    gl.glLinkProgram(shader_program);

    // Error handling
    var success: c_int = undefined;
    var info_log: [512]u8 = undefined;
    gl.glGetShaderiv(shader_program, gl.GL_LINK_STATUS, &success);
    if (success == 0) {
        gl.glGetShaderInfoLog(shader_program, 512, null, &info_log);
        std.debug.print("ERROR: Shader program linking\n{s}\n", .{info_log});
        return RenderError.ShaderLinkError;
    }
    return shader_program;
}

fn createTexture(img_file: [*c]const u8) c_uint {
    var img_w: c_int = undefined;
    var img_h: c_int = undefined;
    var img_channels: c_int = undefined;
    img.stbi_set_flip_vertically_on_load(1);
    const img_data = img.stbi_load(img_file, &img_w, &img_h, &img_channels, 0);
    var texture: c_uint = undefined;
    gl.glGenTextures(1, &texture);
    gl.glBindTexture(gl.GL_TEXTURE_2D, texture);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_LINEAR_MIPMAP_LINEAR);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_LINEAR);
    gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RG, img_w, img_h, 0, gl.GL_RG, gl.GL_UNSIGNED_BYTE, img_data);
    gl.glGenerateMipmap(gl.GL_TEXTURE_2D);
    // Image data passed to GPU, can free from CPU memory
    img.stbi_image_free(img_data);
    return texture;
}

const Buffers = struct {
    VAO: c_uint,
    VBO: c_uint,
    EBO: c_uint,

    fn deleteBuffers(self: Buffers) void {
        gl.glDeleteVertexArrays(1, &self.VAO);
        gl.glDeleteBuffers(1, &self.VBO);
        gl.glDeleteBuffers(1, &self.EBO);
    }
};
fn createChessBoardBufs() Buffers {
    var vertices: [8]f32 = [_]f32{
        -1.0, 1.0,
        1.0,  1.0,
        -1.0, -1.0,
        1.0,  -1.0,
    };
    var indices: [6]u32 = [_]u32{ 0, 2, 1, 1, 2, 3 };
    var bufs = Buffers{
        .VAO = undefined,
        .VBO = undefined,
        .EBO = undefined,
    };
    gl.glGenVertexArrays(1, &bufs.VAO);
    gl.glGenBuffers(1, &bufs.VBO);
    gl.glGenBuffers(1, &bufs.EBO);

    gl.glBindVertexArray(bufs.VAO);
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, bufs.VBO);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, gl.GL_STATIC_DRAW);
    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, bufs.EBO);
    gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, gl.GL_STATIC_DRAW);

    gl.glVertexAttribPointer(0, 2, gl.GL_FLOAT, gl.GL_FALSE, 2 * @sizeOf(f32), null);
    gl.glEnableVertexAttribArray(0);

    // Unbind all bound data
    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
    gl.glBindVertexArray(0);

    return bufs;
}

// 32 pieces
// 4 verts per piece
// 3 components per piece (x, y, piece)
const pieces_verts_len = 32 * 4 * 3;
// 32 pieces
// 2 tris per piece
// 3 inds per tri
const pieces_inds_len = 32 * 2 * 3;
fn createPieceBufs() Buffers {
    var indices: [pieces_inds_len]u32 = [_]u32{0} ** (pieces_inds_len);
    {
        // 0  1
        // 2  3
        var i: u32 = 0;
        while (i < 32) : (i += 1) {
            const ind = i * 6;
            const vert_ind = i * 4;
            indices[ind + 0] = vert_ind + 0;
            indices[ind + 1] = vert_ind + 2;
            indices[ind + 2] = vert_ind + 1;
            indices[ind + 3] = vert_ind + 1;
            indices[ind + 4] = vert_ind + 2;
            indices[ind + 5] = vert_ind + 3;
        }
        // std.debug.print("{any}\n", .{indices});
    }
    var bufs: Buffers = Buffers{
        .VAO = undefined,
        .VBO = undefined,
        .EBO = undefined,
    };
    gl.glGenVertexArrays(1, &bufs.VAO);
    gl.glGenBuffers(1, &bufs.VBO);
    gl.glGenBuffers(1, &bufs.EBO);

    gl.glBindVertexArray(bufs.VAO);

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, bufs.VBO);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, pieces_verts_len * @sizeOf(f32), null, gl.GL_DYNAMIC_DRAW);

    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, bufs.EBO);
    gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, pieces_inds_len * @sizeOf(u32), &indices, gl.GL_STATIC_DRAW);

    gl.glVertexAttribPointer(0, 2, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), null);
    const offset: *anyopaque = @ptrFromInt(2 * @sizeOf(f32));
    gl.glVertexAttribPointer(1, 1, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), offset);
    gl.glEnableVertexAttribArray(0);
    gl.glEnableVertexAttribArray(1);

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
    gl.glBindVertexArray(0);

    return bufs;
}

fn updatePieceBufs(piece_bufs: Buffers, board_data: board.Board) void {
    const PType = piece.PieceType;
    const Side = piece.PieceSide;
    var vertices: [pieces_verts_len]f32 = [_]f32{0.0} ** (pieces_verts_len);

    var piece_ind: usize = 0;
    for (board_data.piece_arr, 0..) |p, i| {
        if (PType.getPieceType(p) == PType.None) {
            continue;
        }

        const x: f32 = @as(f32, @floatFromInt(i % 8));
        const y: f32 = @as(f32, @floatFromInt(i / 8));
        // std.debug.print("{d}, {d}\n", .{x, y});
        // 0  1
        // 2  3
        // Vert 0: Top left
        vertices[piece_ind + 0] = x + 0;
        vertices[piece_ind + 1] = y + 1;

        // Vert 1: Top right
        vertices[piece_ind + 3] = x + 1;
        vertices[piece_ind + 4] = y + 1;

        // Vert 2: Bottom left
        vertices[piece_ind + 6] = x + 0;
        vertices[piece_ind + 7] = y + 0;

        // Vert 3: Bottom right
        vertices[piece_ind + 9] = x + 1;
        vertices[piece_ind + 10] = y + 0;

        const type_val = @as(u32, @intFromEnum(PType.getPieceType(p)));
        const side_val = @as(u32, @intFromEnum(Side.getPieceSide(p)));
        const int_val = type_val + (6 * (side_val >> 3));
        const piece_val = @as(f32, @floatFromInt(int_val));
        vertices[piece_ind + 2] = piece_val;
        vertices[piece_ind + 5] = piece_val;
        vertices[piece_ind + 8] = piece_val;
        vertices[piece_ind + 11] = piece_val;
        // std.debug.print("Piece val: {d}\n", .{piece_val});
        // std.debug.print(
        // "{}: {any}\t{any}\t{any}\t{any}\n",
        // .{type_val, vertices[piece_ind .. piece_ind + 2], vertices[piece_ind + 3 .. piece_ind + 5], vertices[piece_ind + 6 .. piece_ind + 8], vertices[piece_ind + 9 .. piece_ind + 11]});
        piece_ind += 12;
    }
    // std.debug.print("{any}\n", .{vertices});

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, piece_bufs.VBO);
    gl.glBufferSubData(gl.GL_ARRAY_BUFFER, 0, vertices.len * @sizeOf(f32), &vertices);

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
}

// 64 possible squares
// 4 verts per square
// 2 components per piece (x, y)
const bitboard_verts_len = 64 * 4 * 2;
// 64 possible squares
// 2 tris per square
// 3 inds per tri
const bitboard_inds_len = 64 * 2 * 3;
fn createBitboardBufs() Buffers {
    var indices: [bitboard_inds_len]u32 = [_]u32{0} ** (bitboard_inds_len);
    {
        // 0  1
        // 2  3
        var i: u32 = 0;
        while (i < 32) : (i += 1) {
            const ind = i * 6;
            const vert_ind = i * 4;
            indices[ind + 0] = vert_ind + 0;
            indices[ind + 1] = vert_ind + 2;
            indices[ind + 2] = vert_ind + 1;
            indices[ind + 3] = vert_ind + 1;
            indices[ind + 4] = vert_ind + 2;
            indices[ind + 5] = vert_ind + 3;
        }
    }
    var bufs: Buffers = Buffers{
        .VAO = undefined,
        .VBO = undefined,
        .EBO = undefined,
    };
    gl.glGenVertexArrays(1, &bufs.VAO);
    gl.glGenBuffers(1, &bufs.VBO);
    gl.glGenBuffers(1, &bufs.EBO);

    gl.glBindVertexArray(bufs.VAO);

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, bufs.VBO);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, bitboard_verts_len * @sizeOf(f32), null, gl.GL_DYNAMIC_DRAW);

    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, bufs.EBO);
    gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, bitboard_inds_len * @sizeOf(u32), &indices, gl.GL_STATIC_DRAW);

    gl.glVertexAttribPointer(0, 2, gl.GL_FLOAT, gl.GL_FALSE, 2 * @sizeOf(f32), null);
    gl.glEnableVertexAttribArray(0);

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
    gl.glBindVertexArray(0);

    return bufs;
}
// TODO: replace u64 with Bitboard type
fn updateBitboardBufs(highlight_bufs: Buffers, highlight_data: bitboard.Bitboard) void {
    var vertices: [bitboard_verts_len]f32 = [_]f32{0.0} ** bitboard_verts_len;

    var square_ind: usize = 0;
    for (0..64) |i| {
        // const top_bit = 0b1 << 63;
        if (highlight_data.getBit(@truncate(i)) == 0) {
            // This position is not a possible move and
            // not meant to be highlighted
            continue;
        }
        // std.debug.print("hl square {}\n", .{i});

        const x: f32 = @as(f32, @floatFromInt(i % 8));
        const y: f32 = @as(f32, @floatFromInt(i / 8));

        // 0  1
        // 2  3
        // Vert 0: Top left
        vertices[square_ind + 0] = x + 0;
        vertices[square_ind + 1] = y + 1;

        // Vert 1: Top right
        vertices[square_ind + 2] = x + 1;
        vertices[square_ind + 3] = y + 1;

        // Vert 2: Bottom left
        vertices[square_ind + 4] = x + 0;
        vertices[square_ind + 5] = y + 0;

        // Vert 3: Bottom right
        vertices[square_ind + 6] = x + 1;
        vertices[square_ind + 7] = y + 0;

        square_ind += 8;
    }

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, highlight_bufs.VBO);
    gl.glBufferSubData(gl.GL_ARRAY_BUFFER, 0, vertices.len * @sizeOf(f32), &vertices);

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
}
