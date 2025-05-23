shader_type particles;

// Stores position and color
uniform sampler2D agent_data;

uniform float radius = 1.0;

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
	// The b and g color channels store the agent's velocity (used for rotation)
	vec4 agent_params = texelFetch(agent_data, texel_pos, 0);

	
	// Rotation
	float dir = atan(agent_params.a, agent_params.b) + PI / 2.0;
	TRANSFORM[0].x = cos(dir);
	TRANSFORM[0].y = sin(dir);
	TRANSFORM[1].x = -sin(dir);
	TRANSFORM[1].y = cos(dir);
	
	// Scale
	float texture_radius = (radius / 32.0);
	TRANSFORM[0] *= texture_radius;
	TRANSFORM[1] *= texture_radius;
	
	// Translation
	TRANSFORM[3].xy = vec2(agent_params.r, agent_params.g);
	
	COLOR = vec4(1.0);
}
