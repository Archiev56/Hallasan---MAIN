shader_type canvas_item;

uniform vec2 speed = vec2(0.0, -3.0);

void fragment() {
	vec2 uv = UV + TIME * speed;
	COLOR = texture(TEXTURE, uv);
}
