#version 330 core
in vec2 pos;
out vec4 FragColor;
void main()
{
    vec3 colorLight = vec3(0.93f, 0.93f, 0.82f);
    vec3 colorDark = vec3(0.46f, 0.59f, 0.34f);
    vec2 checker_pos = floor(pos * 4.0f) + vec2(4.0f, 4.0f);
    float checkerboard = mod(checker_pos.x + checker_pos.y, 2.0f);
    FragColor = vec4(mix(colorDark, colorLight, checkerboard), 1.0f);
}
