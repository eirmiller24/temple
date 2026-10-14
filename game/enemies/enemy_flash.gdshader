shader_type canvas_item;
// Enemy hurt flash / tell pulse. `flash` 0 = untouched art, 1 = a solid
// white silhouette; Enemy._tick_fx drives it every physics frame.
uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}
