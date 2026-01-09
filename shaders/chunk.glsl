#pragma language glsl3 // i hate glsl

uniform float scale;
uniform ArrayImage tex;

#ifdef VERTEX
vec4 position(mat4 transform_projection, vec4 vertex_position)
{
    VaryingTexCoord.xyz = VertexTexCoord.xyz;
    return transform_projection * vec4(vertex_position.xy * scale, 0, 1);
}
#endif

#ifdef PIXEL
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 pixel_coords)
{
    // get light information from color
    //vec3 col = color.rgb;
    //float level = color.a / 7;

    // get texture
    vec4 tex_col = texture2DArray(tex, VaryingTexCoord.xyz);
    //vec3 mult = col * level;
    return vec4(tex_col.rgb, 1);
}
#endif