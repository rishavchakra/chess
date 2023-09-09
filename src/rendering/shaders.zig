pub const board_vert_shader_src: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec2 aPos;
    \\out vec2 pos;
    \\void main()
    \\{
    \\   pos = aPos;
    \\   gl_Position = vec4(aPos, 0.0f, 1.0f);
    \\}
;

pub const board_frag_shader_src: [:0]const u8 =
    \\#version 330 core
    \\in vec2 pos;
    \\out vec4 FragColor;
    \\void main()
    \\{
    \\   vec3 colorLight = vec3(0.93f, 0.93f, 0.82f);
    \\   vec3 colorDark = vec3(0.46f, 0.59f, 0.34f);
    \\   vec2 checker_pos = floor(pos * 4.0f) + vec2(4.0f, 4.0f);
    \\   float checkerboard = mod(checker_pos.x + checker_pos.y, 2.0f);
    // \\   FragColor = vec4(checkerboard, 0.0f, 0.0f, 1.0f);
    \\   FragColor = vec4(mix(colorDark, colorLight, checkerboard), 1.0f);
    \\}
;

pub const piece_vert_shader_src: [:0]const u8 =
    \\#version 330 core
    \\layout (location = 0) in vec2 aPos;
    \\layout (location = 1) in float aPieceVal;
    \\out vec2 pos;
    \\out float pVal;
    \\void main()
    \\{
    \\   gl_Position = vec4((aPos * 0.25f) - 1.0f, 0.0f, 1.0f);
    \\   pVal = aPieceVal;
    \\   pos = aPos;
    \\}
;

pub const piece_frag_shader_src: [:0]const u8 =
    \\#version 330 core
    \\in float pVal;
    \\in vec2 pos;
    \\out vec4 FragColor;
    \\uniform sampler2D tex0;
    \\uniform sampler2D tex1;
    \\uniform sampler2D tex2;
    \\uniform sampler2D tex3;
    \\uniform sampler2D tex4;
    \\uniform sampler2D tex5;
    \\uniform sampler2D tex6;
    \\uniform sampler2D tex7;
    \\uniform sampler2D tex8;
    \\uniform sampler2D tex9;
    \\uniform sampler2D tex10;
    \\uniform sampler2D tex11;
    \\
    \\void main()
    \\{
    // \\   FragColor = vec4(0.8f, 0.8f, 0.8f, 1.0f);
    // \\   float val = pVal / 12.0f;
    \\   vec2 calc_uv = mod(pos, vec2(1.0f, 1.0f));
    \\   if (pVal < 1.1f) {
    \\   FragColor = texture(tex0, calc_uv).rrrg;
    \\   } else if (pVal < 2.1f) {
    \\   FragColor = texture(tex1, calc_uv).rrrg;
    \\   } else if (pVal < 3.1f) {
    \\   FragColor = texture(tex2, calc_uv).rrrg;
    \\   } else if (pVal < 4.1f) {
    \\   FragColor = texture(tex3, calc_uv).rrrg;
    \\   } else if (pVal < 5.1f) {
    \\   FragColor = texture(tex4, calc_uv).rrrg;
    \\   } else if (pVal < 6.1f) {
    \\   FragColor = texture(tex5, calc_uv).rrrg;
    \\   } else if (pVal < 7.1f) {
    \\   FragColor = texture(tex6, calc_uv).rrrg;
    \\   } else if (pVal < 8.1f) {
    \\   FragColor = texture(tex7, calc_uv).rrrg;
    \\   } else if (pVal < 9.1f) {
    \\   FragColor = texture(tex8, calc_uv).rrrg;
    \\   } else if (pVal < 11.0f) {
    \\   FragColor = texture(tex9, calc_uv).rrrg;
    \\   } else if (pVal < 11.1f) {
    \\   FragColor = texture(tex10, calc_uv).rrrg;
    \\   } else if (pVal < 12.1f) {
    \\   FragColor = texture(tex11, calc_uv).rrrg;
    \\   };
    // \\   FragColor = texture(pieceTexture, calc_uv).rrrg;
    // \\   FragColor = vec4(val, 0.0f, 0.0f, 1.0f);
    // \\   FragColor = vec4(vertPieceVal / 12.0f, 0.0f, 0.0f, 1.0f);
    // \\   FragColor = vec4(pos, 0.0f, 1.0f);
    // \\   FragColor = vec4(uv, 0.0f, 1.0f);
    // \\   FragColor = vec4(calc_uv, 0.0f, 1.0f);
    \\}
;
