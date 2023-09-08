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
const shaders = @import("shaders.zig");
const board = @import("../board.zig");
const piece = @import("../piece.zig");

pub const RenderError = error{
    WindowInitError,
    WindowCreationError,
    GLInitError,
    VertShaderCompilationError,
    FragShaderCompilationError,
    ShaderLinkError,
};

pub fn windowInit() RenderError!*gl.struct_GLFWwindow {
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

    return window;
}

pub fn windowDeinit(window: *gl.struct_GLFWwindow) void {
    gl.glfwTerminate();
    gl.glfwDestroyWindow(window);
}

pub fn windowIsRunning(window: *gl.struct_GLFWwindow) bool {
    return gl.glfwWindowShouldClose(window) == 0;
}

pub const ShaderType = enum {
    Vertex,
    Fragment,
};
pub fn createShader(shader_type: ShaderType, shader_src: [:0]const u8) RenderError!c_uint {
    const shader = switch (shader_type) {
        ShaderType.Vertex => gl.glCreateShader(gl.GL_VERTEX_SHADER),
        ShaderType.Fragment => gl.glCreateShader(gl.GL_FRAGMENT_SHADER),
    };
    const shader_src_ptr: ?[*]const u8 = shader_src.ptr;
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

pub fn deleteShader(shader: c_uint) void {
    gl.glDeleteShader(shader);
}

pub fn createShaderProgram(shader_arr: []const c_uint) RenderError!c_uint {
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

pub fn createTexture(img_file: [*c]const u8) c_uint {
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

pub const Buffers = struct {
    VAO: c_uint,
    VBO: c_uint,
    EBO: c_uint,

    pub fn deleteBuffers(self: Buffers) void {
        gl.glDeleteVertexArrays(1, &self.VAO);
        gl.glDeleteBuffers(1, &self.VBO);
        gl.glDeleteBuffers(1, &self.EBO);
    }
};
// 9 * 9: (8 + 1) * (8 + 1) vertices on a single row
// 3: components per vert
pub const chessboard_verts_len = 9 * 9 * 2;
// 8 * 8: 64 squares
// 3: verts per triangle
// 2: tris needed to make a quad
pub const chessboard_inds_len = 8 * 8 * 3 * 2;
pub fn createChessboard() Buffers {
    var vertices: [chessboard_verts_len]f32 = [_]f32{0.0} ** (chessboard_verts_len);
    // Currently allocates twice as much space as necessary (only half of squares filled in)
    var indices: [chessboard_inds_len]u32 = [_]u32{0} ** (chessboard_inds_len);
    {
        var y: f32 = -1.0;
        for (0..9) |i| {
            var x: f32 = -1.0;
            for (0..9) |j| {
                const ind = (j + (9 * i)) * 2;
                vertices[ind + 0] = x;
                vertices[ind + 1] = y;
                // vertices[ind + 2] = 0.0;
                x += 0.25;
            }
            y += 0.25;
        }
    }
    {
        var x: u32 = 0;
        var y: u32 = 0;
        while (y < 8) : (y += 1) {
            while (x < 8) : (x += 1) {
                if ((x + y) % 2 == 0) {
                    continue;
                }
                const vert_ind: u32 = x + (9 * y);
                const ind = (x + (8 * y)) * 3 * 2;
                indices[ind + 0] = vert_ind; // Bottom left point
                indices[ind + 1] = vert_ind + 1; // Bottom right point
                indices[ind + 2] = vert_ind + 9 + 1; // Top right point
                // Next triangle
                indices[ind + 3] = vert_ind + 9 + 1; // Top right point
                indices[ind + 4] = vert_ind + 9; // Top left point
                indices[ind + 5] = vert_ind; // Bottom left point
            }
            x = 0;
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
pub const pieces_verts_len = 32 * 4 * 3;
// 32 pieces
// 2 tris per piece
// 3 inds per tri
pub const pieces_inds_len = 32 * 2 * 3;
pub fn createPieceBufs() Buffers {

    // var vertices: [pieces_verts_len]f32 = [_]f32{0.0} ** (pieces_verts_len);
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

pub fn updatePieceBufs(piece_bufs: Buffers, board_data: board.Board) void {
    const PType = piece.PieceType;
    const Side = piece.Side;
    var vertices: [pieces_verts_len]f32 = [_]f32{0.0} ** (pieces_verts_len);

    var piece_ind: usize = 0;
    for (board_data.piece_arr, 0..) |p, i| {
        if (PType.getPieceType(p) == PType.None) {
            continue;
        }

        const x: f32 = @as(f32, @floatFromInt(i % 8));
        const y: f32 = @as(f32, @floatFromInt(i / 8));
        // std.debug.print("{}, {}\n", .{i % 8, i / 8});
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
        // std.debug.print("Piece val: {}\n", .{piece_val});
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
