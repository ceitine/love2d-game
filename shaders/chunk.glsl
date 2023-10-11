#pragma language glsl3 // i hate glsl

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

struct Tile {
    vec4 vertex_position;
    vec3 tex_coords;
};

Tile unpack(vec4 data)
{
    // unpack data
    Tile tile;
    uint first_data = uint(data.x);
    uint second_data = uint(data.y);

    uint texture_index = (second_data >> 20) & 0xFFFu;
    uint vertex_index = (second_data >> 17) & 0x7u;
    
    vec4 rect = vec4(
        (first_data >> 4) & 0x7Fu, // x
        (first_data >> 11) & 0x7Fu, // y 
        (first_data >> 18) & 0x7Fu, // width
        (first_data >> 25) & 0x7Fu // height
    );
    vec2 offset = offsets[vertex_index] * rect.zw;

    // assign values
    tile.vertex_position = vec4((rect.xy + offset.xy) * scale, 1, 1);
    tile.tex_coords = vec3(offset.xy, texture_index);

    return tile;
}

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    // let's use the values from our unpacked data
    Tile unpacked = unpack(vertex_position);
    VaryingTexCoord.xyz = unpacked.tex_coords;
    return transform_projection * unpacked.vertex_position;
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
    vec4 tex_col = texture2DArray(tex, VaryingTexCoord.xyz);
    return tex_col;
}
#endif