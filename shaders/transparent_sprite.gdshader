shader_type canvas_item;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	// Make cyan/light blue colors transparent (checkerboard background)
	// Check if the color is close to cyan (#00FFFF) or light cyan (#AAFFFF)
	float cyan_dist = distance(color.rgb, vec3(0.0, 1.0, 1.0));
	float light_cyan_dist = distance(color.rgb, vec3(0.67, 1.0, 1.0));
	float light_blue_dist = distance(color.rgb, vec3(0.6, 0.8, 1.0));

	// If very close to cyan/light blue, make it transparent
	if (cyan_dist < 0.2 || light_cyan_dist < 0.2 || light_blue_dist < 0.3) {
		color.a = 0.0;
	}

	COLOR = color;
}
