
layout(set = 0, binding = 0, std430) restrict buffer Position {
    vec2 data[];
} agent_pos;

layout(set = 0, binding = 1, std430) restrict buffer Velocity {
    vec2 data[];
} agent_vel;

layout(set = 0, binding = 2, std430) restrict buffer Color {
    int data[];
} agent_color;

layout(set = 0, binding = 3, std430) restrict buffer Radius {
    float data[];
} agent_radius;

layout(set = 0, binding = 4, std430) restrict buffer Params {
    float agent_count;
    float screen_width;
    float screen_height;
    float image_size;
    float delta;
} params;

layout(rgba32f, binding = 5) uniform image2D agent_data;