#version 330 core
layout (location = 0) in vec2 aPos;
layout (location = 1) in float aPieceVal;
out vec2 pos;
out float pVal;
void main()
{
    gl_Position = vec4((aPos * 0.25f) - 1.0f, 0.0f, 1.0f);
    pVal = aPieceVal;
    pos = aPos;
}
