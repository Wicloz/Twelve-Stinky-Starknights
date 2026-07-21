shader_type canvas_item;

uniform float brightness : hint_range(-1.0, 1.0) = 0.0;
uniform float contrast : hint_range(0.0, 2.0) = 1.0;

void fragment() {
    vec4 color = texture(TEXTURE, UV);

    // contrast
    color.rgb = (color.rgb - 0.5) * contrast + 0.5;

    // brightness
    color.rgb += vec3(brightness);

    COLOR = clamp(color, 0.0, 1.0);
}
