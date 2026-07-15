shader_type canvas_item;

uniform vec4 holo_color : source_color = vec4(0.4, 0.8, 1.0, 1.0);
uniform float alpha : hint_range(0.0, 1.0) = 0.5;
uniform float scan_density = 40.0;
uniform float scan_speed = 2.0;

void fragment() {
    vec4 tex = texture(TEXTURE, UV);

    // keep the building's internal light/dark detail, but recolor it
    float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
    vec3 col = holo_color.rgb * (0.4 + 0.6 * lum);

    // moving scanlines
    float scan = 0.85 + 0.15 * sin(UV.y * scan_density + TIME * scan_speed);

    COLOR = vec4(col * scan, tex.a * alpha);   // tex.a keeps the exact silhouette
}
