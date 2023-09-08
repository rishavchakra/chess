pub const board_vert_shader_src: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec2 aPos;
    \\void main()
    \\{
    \\   gl_Position = vec4(aPos.x, aPos.y, 0.0f, 1.0f);
    \\}
;

pub const board_frag_shader_src: [:0]const u8 =
    \\#version 330 core
    \\out vec4 FragColor;
    \\void main()
    \\{
    \\   FragColor = vec4(0.8f, 0.8f, 0.8f, 1.0f);
    \\}
;

pub const piece_vert_shader_src: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec2 aPos;
    \\layout (location = 1) in vec2 uv;
    \\layout (location = 2) in float inPieceVal;
    \\out vec2 vertUv;
    \\out float vertPieceVal;
    \\void main()
    \\{
    \\   gl_Position = vec4(aPos.x, aPos.y, 0.0f, 1.0f);
    \\   vertPieceVal = inPieceVal;
    \\   vertUv = uv;
    \\}
;

pub const piece_frag_shader_src: [:0]const u8 =
    \\#version 330 core
    \\in float vertPieceVal;
    \\in vec2 vertUv;
    \\out vec4 FragColor;
    \\void main()
    \\{
    // \\   FragColor = vec4(0.8f, 0.8f, 0.8f, 1.0f);
    \\   float val = vertPieceVal;
    // \\   val = 1.0f;
    \\   FragColor = vec4(1.0f, 1.0f, 1.0f, 1.0f);
    \\}
;
