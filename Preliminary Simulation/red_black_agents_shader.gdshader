shader_type particles;

// Stores position and color
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
	
	// The r and g color channels store the agent's x/y positions
	// The b color channel stores whether or not the agent is blue (confusing but red is easier on the eyes)
	// The alpha channel stores the agent's radius
	vec4 agent_params = texelFetch(agent_data, texel_pos, 0);
	
	TRANSFORM[0].x = agent_params.a;
	TRANSFORM[1].y = agent_params.a;
	TRANSFORM[3].xy = vec2(agent_params.r, agent_params.g);
	
	// The b channel is either 1 or 0, and when it's 1, use the non-black color
	COLOR = vec4(agent_params.b, 0.0, 0.0, 1.0);
}


