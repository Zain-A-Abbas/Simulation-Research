#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

#include "agent-shared-data.glsl"

void main() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= params.agent_count) {return;}

    vec2 position = agent_pos.data[idx];
    vec2 velocity = agent_vel.data[idx];


    vec2 avoid = vec2(0.0);
    for (int i = 0; i < params.agent_count; i++) {
        if (i == idx) {continue;}

        //if (abs(position.x - agent_pos.data[i].x) > 10) {continue;}
        //if (abs(position.y - agent_pos.data[i].y) > 10) {continue;}

        float dist = distance(position, agent_pos.data[i]);
        if (dist > 0 && dist < 8.0) {
            float dist_ab = max(dist - 1.0, 0.001);
            float k = max(80.0 - dist_ab, 0.0);
            float x_ab = (position.x - agent_pos.data[i].x) / dist;
            float y_ab = (position.y - agent_pos.data[i].y) / dist;

            avoid.x += k * x_ab / dist_ab;
            avoid.y += k * y_ab / dist_ab;
        }
    }

    position += (velocity + avoid) * params.delta;

    if (position.x > params.screen_width) {position.x -= params.screen_width;}
    if (position.y > params.screen_height) {position.y -= params.screen_height;}
    if (position.x < 0) {position.x += params.screen_width;}
    if (position.y < 0) {position.y += params.screen_height;}
    agent_pos.data[idx] = position;

    // Turns this agent's index into x/y to find the corresponding pixel on the texture
    ivec2 pixel_coord = ivec2(
        int(mod(idx, params.image_size)),
        int(idx / params.image_size)
    );

    imageStore(agent_data, pixel_coord, vec4(position.x, position.y, agent_color.data[idx], 1.0));
}
