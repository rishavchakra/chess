const std = @import("std");

const gl = @cImport({
    // Disables GLFW's inclusion of GL libraries
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
    // @cInclude("GL/glew.h");
    @cInclude("glad/glad.h");
});

const RenderError = error{
    WindowInitError,
    WindowCreationError,
    GLInitError,
    VertShaderCompilationError,
    FragShaderCompilationError,
    ShaderLinkError,
};

const vert_shader_src: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\void main()
    \\{
    \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0f);
    \\}
;
const frag_shader_src: [:0]const u8 =
    \\#version 330 core
    \\out vec4 FragColor;
    \\void main()
    \\{
    \\   FragColor = vec4(0.8f, 0.8f, 0.8f, 1.0f);
    \\}
;

pub fn main() !void {
    const glfw_init_res = gl.glfwInit();
    if (glfw_init_res == 0) {
        return RenderError.WindowInitError;
    }
    defer gl.glfwTerminate();

    gl.glfwWindowHint(gl.GLFW_CONTEXT_VERSION_MAJOR, 3);
    gl.glfwWindowHint(gl.GLFW_CONTEXT_VERSION_MINOR, 3);
    gl.glfwWindowHint(gl.GLFW_OPENGL_PROFILE, gl.GLFW_OPENGL_CORE_PROFILE);
    gl.glfwWindowHint(gl.GLFW_OPENGL_FORWARD_COMPAT, gl.GL_TRUE);

    const window = gl.glfwCreateWindow(512, 512, "Chess", null, null);
    if (window == null) {
        return RenderError.WindowCreationError;
    }
    defer gl.glfwDestroyWindow(window);

    gl.glfwMakeContextCurrent(window);

    const glad_init_res = gl.gladLoadGLLoader(@ptrCast(&gl.glfwGetProcAddress));
    if (glad_init_res == 0) {
        return RenderError.GLInitError;
    }

    const vert_shader = gl.glCreateShader(gl.GL_VERTEX_SHADER);
    const vert_src_ptr: ?[*]const u8 = vert_shader_src.ptr;
    gl.glShaderSource(vert_shader, 1, &vert_src_ptr, null);
    gl.glCompileShader(vert_shader);
    var success: c_int = undefined;
    var info_log: [512]u8 = undefined;
    gl.glGetShaderiv(vert_shader, gl.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        gl.glGetShaderInfoLog(vert_shader, 512, null, &info_log);
        std.debug.print("ERROR: Vertex compilation\n{s}\n", .{info_log});
        return RenderError.VertShaderCompilationError;
    }
    const frag_shader = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
    const frag_src_ptr: ?[*]const u8 = frag_shader_src.ptr;
    gl.glShaderSource(frag_shader, 1, &frag_src_ptr, null);
    gl.glCompileShader(frag_shader);
    gl.glGetShaderiv(frag_shader, gl.GL_COMPILE_STATUS, &success);
    if (success == 0) {
        gl.glGetShaderInfoLog(frag_shader, 512, null, &info_log);
        std.debug.print("ERROR: Fragment compilation\n{s}\n", .{info_log});
        return RenderError.FragShaderCompilationError;
    }
    const shader_program = gl.glCreateProgram();
    gl.glAttachShader(shader_program, vert_shader);
    gl.glAttachShader(shader_program, frag_shader);
    gl.glLinkProgram(shader_program);
    gl.glGetShaderiv(shader_program, gl.GL_LINK_STATUS, &success);
    if (success == 0) {
        gl.glGetShaderInfoLog(shader_program, 512, null, &info_log);
        std.debug.print("ERROR: Shader program linking\n{s}\n", .{info_log});
        return RenderError.ShaderLinkError;
    }
    gl.glDeleteShader(vert_shader);
    gl.glDeleteShader(frag_shader);

    // 9 * 9: (8 + 1) * (8 + 1) vertices on a single row
    // 3: verts per tri
    var vertices: [9 * 9 * 3]f32 = [_]f32{0.0} ** (9 * 9 * 3);
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

    // Currently allocates twice as much space as necessary (only half of squares filled in)
    // 8 * 8: 64 squares
    // 3: verts per triangle
    // 2: tris needed to make a quad
    var indices: [8 * 8 * 3 * 2]u32 = [_]u32{0} ** (8 * 8 * 3 * 2);
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

    var VAO: c_uint = undefined;
    var VBO: c_uint = undefined;
    var EBO: c_uint = undefined;
    gl.glGenVertexArrays(1, &VAO);
    gl.glGenBuffers(1, &VBO);
    gl.glGenBuffers(1, &EBO);
    defer gl.glDeleteVertexArrays(1, &VAO);
    defer gl.glDeleteBuffers(1, &VBO);
    defer gl.glDeleteBuffers(1, &EBO);
    gl.glBindVertexArray(VAO);

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, VBO);
    gl.glBufferData(gl.GL_ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, gl.GL_STATIC_DRAW);

    gl.glBindBuffer(gl.GL_ELEMENT_ARRAY_BUFFER, EBO);
    gl.glBufferData(gl.GL_ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, gl.GL_STATIC_DRAW);

    gl.glVertexAttribPointer(0, 3, gl.GL_FLOAT, gl.GL_FALSE, 3 * @sizeOf(f32), null);
    gl.glEnableVertexAttribArray(0);

    gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);

    gl.glBindVertexArray(0);

    while (gl.glfwWindowShouldClose(window) == 0) {
        gl.glClearColor(0.11, 0.11, 0.14, 1.0);
        gl.glClear(gl.GL_COLOR_BUFFER_BIT);

        gl.glUseProgram(shader_program);
        gl.glBindVertexArray(VAO);
        gl.glDrawElements(gl.GL_TRIANGLES, indices.len, gl.GL_UNSIGNED_INT, null);

        gl.glfwSwapBuffers(window);
        gl.glfwPollEvents();
    }
}
