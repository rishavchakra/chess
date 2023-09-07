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

    const window = gl.glfwCreateWindow(512, 512, "Chess", null, null) orelse return RenderError.WindowCreationError;

    gl.glfwMakeContextCurrent(window);

    const glad_init_res = gl.gladLoadGLLoader(@ptrCast(&gl.glfwGetProcAddress));
    if (glad_init_res == 0) {
        return RenderError.GLInitError;
    }

    return window.?;
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
    gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGBA, img_w, img_h, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, img_data);
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
// 3: verts per tri
pub const chessboard_verts_len = 9 * 9 * 3;
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
                const ind = (j + (9 * i)) * 3;
                vertices[ind + 0] = x;
                vertices[ind + 1] = y;
                vertices[ind + 2] = 0.0;
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

    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), null);
    gl.glEnableVertexAttribArray(0);

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);

    gl.glBindVertexArray(0);

    return bufs;
}
