shader_type particles;
uniform sampler2D agent_data;


void start() {
	// Called when a particle is spawned.
}

void process() {
	ivec2 pos_image_size = textureSize(agent_data, 0);
	
	ivec2 texel_pos = ivec2(
		int(mod(float(INDEX), float(pos_image_size.x))),
		int(float(INDEX) / float(pos_image_size.x))
	);
	
	vec4 agent_pos_color = texelFetch(agent_data, texel_pos, 0);
	//TRANSFORM[0].xy = vec2(1.0, 1.0);
	//TRANSFORM[1].xy = vec2(1.0, 1.0);
	TRANSFORM[3].xy = vec2(agent_pos_color.r, agent_pos_color.g);
	
	// The b channel is either 1 or 0, and when it's 1, use the non-black color
	COLOR = vec4(agent_pos_color.b, 0.0, 0.0, 1.0);
}


