shader_type canvas_item;
// Colour grade for the world: saturation and a tint, applied before the interface.

uniform sampler2D screen_tex : hint_screen_texture, filter_nearest;
uniform float saturation = 1.0;
uniform vec3 tint = vec3(1.0);

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation) * tint;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
