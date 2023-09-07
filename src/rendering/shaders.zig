pub const vert_shader_src: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\void main()
    \\{
    \\   gl_Position = vec4(aPos.x, aPos.y, aPos.z, 1.0f);
    \\}
;
pub const frag_shader_src: [:0]const u8 =
    \\#version 330 core
    \\out vec4 FragColor;
    \\void main()
    \\{
    \\   FragColor = vec4(0.8f, 0.8f, 0.8f, 1.0f);
    \\}
;
