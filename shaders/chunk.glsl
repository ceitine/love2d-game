#pragma language glsl3 // i hate glsl

uniform float world_scale;
uniform ArrayImage tile_atlas;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    VaryingTexCoord.xyz = VertexTexCoord.xyz;
    return transform_projection * vec4(vertex_position.xy * world_scale, 0, 1);
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
    vec4 tex_col = texture2DArray(tile_atlas, VaryingTexCoord.xyz);
    return vec4(tex_col.rgb, tex_col.a);
}
#endif