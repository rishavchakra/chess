#version 330 core
in float pVal;
in vec2 pos;
out vec4 FragColor;
uniform sampler2D tex0;
uniform sampler2D tex1;
uniform sampler2D tex2;
uniform sampler2D tex3;
uniform sampler2D tex4;
uniform sampler2D tex5;
uniform sampler2D tex6;
uniform sampler2D tex7;
uniform sampler2D tex8;
uniform sampler2D tex9;
uniform sampler2D tex10;
uniform sampler2D tex11;

void main()
{
    vec2 calc_uv = mod(pos, vec2(1.0f, 1.0f));
    if (pVal < 1.1f) {
        FragColor = texture(tex0, calc_uv).rrrg;
    } else if (pVal < 2.1f) {
        FragColor = texture(tex1, calc_uv).rrrg;
    } else if (pVal < 3.1f) {
        FragColor = texture(tex2, calc_uv).rrrg;
    } else if (pVal < 4.1f) {
        FragColor = texture(tex3, calc_uv).rrrg;
    } else if (pVal < 5.1f) {
        FragColor = texture(tex4, calc_uv).rrrg;
    } else if (pVal < 6.1f) {
        FragColor = texture(tex5, calc_uv).rrrg;
    } else if (pVal < 7.1f) {
        FragColor = texture(tex6, calc_uv).rrrg;
    } else if (pVal < 8.1f) {
        FragColor = texture(tex7, calc_uv).rrrg;
    } else if (pVal < 9.1f) {
        FragColor = texture(tex8, calc_uv).rrrg;
    } else if (pVal < 11.0f) {
        FragColor = texture(tex9, calc_uv).rrrg;
    } else if (pVal < 11.1f) {
        FragColor = texture(tex10, calc_uv).rrrg;
    } else if (pVal < 12.1f) {
        FragColor = texture(tex11, calc_uv).rrrg;
    };
}
