#[compute]
#version 450

layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

#include "agent-shared-data.glsl"

void main() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= params.agent_count) {return;}

    vec2 position = agent_pos.data[idx];
    vec2 velocity = agent_vel.data[idx];
    position += velocity * params.delta;
    if (position.x > params.screen_width) {position.x -= params.screen_width;}
    if (position.y > params.screen_height) {position.y -= params.screen_height;}
    if (position.x < 0) {position.x += params.screen_width;}
    if (position.y < 0) {position.y += params.screen_height;}
    agent_pos.data[idx] = position;
}
