layout(set = 0, binding = 0, std430) restrict buffer Position {
    vec2 data[];
} agent_pos;

layout(set = 0, binding = 1, std430) restrict buffer Velocity {
    vec2 data[];
} agent_vel;

layout(set = 0, binding = 2, std430) restrict buffer Color {
    int data[];
} agent_color;

/*layout(set = 0, binding = 3, std430) restrict buffer Radius {
    float data[];
} agent_radius;*/

layout(set = 0, binding = 3, std430) restrict buffer Params {
    float agent_count;
    float screen_width;
    float screen_height;
    float image_size;
    float radius;
    float radius_squared;
    float delta;
} params;

// The textures here are each used to pass the image back to the engine, as passing the shader data directly to a texture keeps everything
// on the GPU without having to pass it back over to CPU memory
layout(rgba32f, binding = 4) uniform image2D agent_data;