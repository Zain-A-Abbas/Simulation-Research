
layout(set = 0, binding = 0, std430) restrict buffer Position {
    vec2 data[];
} agent_pos;

layout(set = 0, binding = 0, std430) restrict buffer Velocity {
    vec2 data[];
} agent_vol;

layout(set = 0, binding = 0, std430) restrict buffer Color {
    int data[];
} agent_color;
