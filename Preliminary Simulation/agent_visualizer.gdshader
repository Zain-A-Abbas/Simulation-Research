shader_type particles;

uniform sampler2D agent_data;

void process() {
	ivec2 pos_image_size = textureSize(agent_data, 0);
	
	ivec2 texel_pos = ivec2(int(mod(float(INDEX),float(pos_image_size.x))),
							int(float(INDEX)/float(pos_image_size.x)));
						
	vec4 boid_pos_rot = texelFetch(agent_data, texel_pos, 0);
	
	mat2 scale_rot_mat = mat2(vec2(cos(boid_pos_rot.b), sin(boid_pos_rot.b)), // First column
							  vec2(-sin(boid_pos_rot.b), cos(boid_pos_rot.b))); // Second column
	
	//scale_rot_mat[0] *= scale.x;
	//scale_rot_mat[1] *= scale.y;
	
	TRANSFORM[0].xy = scale_rot_mat[0];
	TRANSFORM[1].xy = scale_rot_mat[1];
	TRANSFORM[3].xy = vec2(boid_pos_rot.r, boid_pos_rot.g); 
}