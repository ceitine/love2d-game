#pragma language glsl3

uniform float scale;
uniform ArrayImage tex;

#ifdef VERTEX
const vec2 offsets[4] = vec2[4] 
(
    vec2(0, 0),
    vec2(1, 0),
    vec2(0, 1),
    vec2(1, 1)
);

/*
some sizes for our vertex:
x - 8 bits
y - 8 bits
width - 8 bits
height - 8 bits

other:
texture index: 12 bits
vertex index: 3 bits
*/

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    // let's unpack some data and handle our vertices
    int first_data = int(vertex_position.x);
    int second_data = int(vertex_position.y);

    int texture_index = (second_data >> 20) & 0xFFF;
    int vertex_index = (second_data >> 17) & 0x7;
    vec4 rect = vec4(first_data & 0xFF, (first_data >> 8) & 0xFF, (first_data >> 16) & 0xFF, (first_data >> 24) & 0xFF);
    vec2 offset = offsets[vertex_index];
    vertex_position = vec4((rect.xy + (offset.xy * rect.zw)) * scale, 0, 1);
    VaryingTexCoord.xyz = vec3(offset.xy * rect.zw, texture_index);

    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
    vec4 tex_col = texture2DArray(tex, VaryingTexCoord.xyz);
    return tex_col;
}
#endif