shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(1.0);
uniform sampler2D grain : repeat_enable, filter_linear_mipmap_anisotropic;
uniform int finish = 0; // 0 cast concrete, 1 steel, 2 lane paint, 3 trowelled floor, 4 safety stripes
varying vec3 world;
varying vec3 face;
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	face = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
float slab_joint(float coord) {
	float d = abs(fract(coord+0.5)-0.5);
	return 1.0-smoothstep(0.001,0.006+fwidth(coord)*0.4,d);
}
void fragment() {
	vec3 n = abs(normalize(face));
	vec2 uv = n.y>0.65 ? world.xz : (n.x>n.z ? world.zy : world.xy);
	vec3 tex = texture(grain, uv*0.49).rgb;
	float cloud = texture(grain,uv*0.087).r;
	float metal = finish==1 ? 1.0 : 0.0;
	vec3 base = tint.rgb;
	if (finish==4) {
		float dash = smoothstep(0.48,0.52,fract((uv.x+uv.y*0.8)*2.2));
		base = mix(vec3(0.045,0.055,0.05),base,dash);
	}
	float grain_lum = mix(tex.r,tex.g,metal);
	float pattern = 0.70+grain_lum*0.48+cloud*0.15;
	if (finish==3) {
		float seams = max(slab_joint(world.x/3.4),slab_joint(world.z/4.2));
		pattern *= (1.0-0.36*seams);
	} else if (finish==0 && n.y<0.6) {
		pattern *= 1.0-0.20*max(slab_joint((uv.x+1.4)/3.7),slab_joint((uv.y+0.1)/1.7));
		float tie = length(vec2(fract((uv.x+0.4)*0.55)-0.5,fract((uv.y+0.2)*0.78)-0.5));
		pattern *= 1.0-0.38*(1.0-smoothstep(0.009,0.022,tie));
	}
	// Sunlit patches projected by the south-facing roof monitors and their mullions.
	vec2 sky = vec2(world.x + (6.0-world.y)*0.76, world.z + (6.0-world.y)*0.43);
	float pane = smoothstep(-3.9,-3.65,sky.x)*(1.0-smoothstep(3.25,3.55,sky.x));
	float along = abs(mod(sky.y+2.0,6.0)-3.0);
	pane *= 1.0-smoothstep(1.68,1.89,along);
	pane *= 0.38+0.62*smoothstep(0.035,0.105,abs(mod(sky.x+0.6,1.55)-0.775));
	pane *= 1.0-smoothstep(11.0,12.0,abs(world.x));
	float corner = smoothstep(0.1,2.4, min(10.0-abs(world.x),22.0+world.z));
	ALBEDO = base*pattern*mix(0.84,1.0,corner)*mix(vec3(0.80,0.88,0.96),vec3(1.22,1.11,0.90),pane);
	EMISSION = base*pane*vec3(0.42,0.31,0.18);
	ROUGHNESS = clamp(mix(0.75,0.41,metal)+(tex.b-0.5)*0.30-(finish==3?0.16:0.0),0.18,0.96);
	METALLIC = metal*0.42;
	SPECULAR = 0.46;
}
