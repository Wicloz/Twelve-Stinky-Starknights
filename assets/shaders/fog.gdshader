shader_type canvas_item;

// Rolling fog-of-war for hex tiles.
// Meant for a sprite using assets/hexagon.svg (pure white, hex fills the whole
// viewBox) - the shader supplies the colour, the softness and the animation.
// Noise is sampled in *world* space, so every tile can share one material and
// the fog still reads as one continuous cloud bank across the board.

uniform vec4 fog_color : source_color = vec4(0.90, 0.93, 0.97, 1.0);
uniform vec4 fog_shadow : source_color = vec4(0.55, 0.60, 0.70, 1.0);
uniform float fog_alpha : hint_range(0.0, 1.0) = 0.92;
uniform float base_opacity : hint_range(0.0, 1.0) = 0.6;  // thinnest the fog ever gets
uniform float coverage : hint_range(0.0, 1.0) = 0.5;      // how much reads as thick
uniform float softness : hint_range(0.05, 1.0) = 0.5;     // thick -> thin falloff
uniform float world_scale = 150.0;                        // pixels per noise cell
uniform float drift_speed = 0.035;
uniform float wispiness : hint_range(0.0, 1.0) = 0.5;     // domain warp strength
uniform float edge_feather : hint_range(0.0, 0.5) = 0.18; // fade inside the hex rim
// How opaque the fog still is *at* the rim. Keep this high (~0.7) when tiles sit
// side by side, or the two feathered edges leave a dark seam along the border.
uniform float edge_opacity : hint_range(0.0, 1.0) = 0.72;
uniform float rim_glow : hint_range(0.0, 1.0) = 0.15;

varying vec2 world_pos;

float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 34.56);
    return fract(p.x * p.y);
}

float vnoise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
    float sum = 0.0;
    float amp = 0.5;
    float norm = 0.0;
    for (int i = 0; i < 4; i++) {
        sum += amp * vnoise(p);
        norm += amp;
        p *= 2.03;
        amp *= 0.5;
    }
    return sum / norm; // roughly 0..1, centred near 0.5
}

// Flat-top hexagon, apothem r along y (circumradius 1.1547 * r along x).
// Negative inside, 0 on the border. iq's sdHexagon.
float sd_hex(vec2 p, float r) {
    const vec3 k = vec3(-0.866025404, 0.5, 0.577350269);
    p = abs(p);
    p -= 2.0 * min(dot(k.xy, p), 0.0) * k.xy;
    p -= vec2(clamp(p.x, -k.z * r, k.z * r), r);
    return length(p) * sign(p.y);
}

void vertex() {
    world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
    // UV -> hex space. x spans [-1, 1], y spans [-0.866, 0.866].
    vec2 p = (UV - vec2(0.5)) * vec2(2.0, 1.7320508);
    float d = sd_hex(p, 0.8660254);

    // 1 well inside the tile, edge_opacity at the rim, so neighbouring tiles blend.
    float rim = smoothstep(-edge_feather, 0.0, d); // 0 inside -> 1 at the border
    float inner = mix(1.0, edge_opacity, rim);

    vec2 n_uv = world_pos / world_scale;
    float t = TIME * drift_speed;

    // light domain warp gives the billowy, non-tiling look
    vec2 warp = vec2(fbm(n_uv + vec2(t, -t * 0.7)),
                     fbm(n_uv + vec2(5.2 - t * 0.4, 1.3 + t * 0.5)));
    vec2 q = n_uv + wispiness * (warp - vec2(0.5));

    float clouds = mix(fbm(q + vec2(t, t * 0.35)),
                       fbm(q * 1.9 - vec2(t * 0.6, t * 0.2) + vec2(7.1)),
                       0.45);

    // fine detail on top of the big billows, so the fog has wisps up close
    clouds = mix(clouds, vnoise(q * 6.0 + vec2(t * 1.6, -t)), 0.14);

    float thr = 1.0 - coverage;
    float density = smoothstep(thr - softness * 0.5, thr + softness * 0.5, clouds);

    vec3 col = mix(fog_shadow.rgb, fog_color.rgb, density);
    col += fog_color.rgb * rim_glow * rim; // brighter, hazier rim

    float a = fog_alpha * mix(base_opacity, 1.0, density) * inner;
    COLOR = vec4(col, a * texture(TEXTURE, UV).a);
}
