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
    \\layout (location = 1) in float inPieceVal;
    \\out vec2 pos;
    \\out float vertPieceVal;
    \\void main()
    \\{
    \\   gl_Position = vec4((aPos * 0.25f) - 1.0f, 0.0f, 1.0f);
    \\   vertPieceVal = inPieceVal;
    \\   pos = aPos;
    \\}
;

pub const piece_frag_shader_src: [:0]const u8 =
    \\#version 330 core
    \\in float vertPieceVal;
    \\in vec2 pos;
    \\out vec4 FragColor;
    \\uniform sampler2D pieceTexture;
    \\void main()
    \\{
    // \\   FragColor = vec4(0.8f, 0.8f, 0.8f, 1.0f);
    \\   float val = vertPieceVal;
    \\   vec2 calc_uv = mod(pos, vec2(1.0f, 1.0f));
    \\   FragColor = texture(pieceTexture, calc_uv).rrrg;
    // \\   FragColor = vec4(val, 0.0f, 0.0f, 1.0f);
    // \\   FragColor = vec4(vertPieceVal / 12.0f, 0.0f, 0.0f, 1.0f);
    // \\   FragColor = vec4(pos, 0.0f, 1.0f);
    // \\   FragColor = vec4(uv, 0.0f, 1.0f);
    // \\   FragColor = vec4(calc_uv, 0.0f, 1.0f);
    \\}
;
