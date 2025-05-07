#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

#include "agent-shared-data.glsl"

float random(uvec3 st) {
    return fract(sin(dot(st.xy ,vec2(12.9898,78.233))) * 43758.5453123);
}

void main() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= params.agent_count) {return;}

    vec2 position = agent_pos.data[idx];
    vec2 velocity = agent_vel.data[idx];


    for (int i = 0; i < params.agent_count; i++) {
        if (i == idx) {continue;}

        //if (abs(position.x - agent_pos.data[i].x) > 10) {continue;}
        //if (abs(position.y - agent_pos.data[i].y) > 10) {continue;}

        // [i] index is for the other agent in the pair
        float normalDirX = position.x - agent_pos.data[i].x;
        float normalDirY = position.y - agent_pos.data[i].y;
        float dist = distance(position, agent_pos.data[i]);
        float constraint_distance = dist - agent_radius.data[idx] - agent_radius.data[i];
        if (constraint_distance < 0) {

            if (dist < 0.001) {
                dist = 1.0;
                float rand_dir = random(gl_GlobalInvocationID);
                normalDirX = cos(rand_dir);
                normalDirY = sin(rand_dir);
            }

            normalDirX /= dist;
            normalDirY /= dist;

            position.x -= 0.5 * constraint_distance * normalDirX;
            position.y -= 0.5 * constraint_distance * normalDirY;
            agent_pos.data[i].x += 0.5 * constraint_distance * normalDirX;
            agent_pos.data[i].y += 0.5 * constraint_distance * normalDirY;
        }

    }

    position += (velocity) * params.delta;

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

    imageStore(agent_data, pixel_coord, vec4(position.x, position.y, agent_color.data[idx], agent_radius.data[idx]));
}
