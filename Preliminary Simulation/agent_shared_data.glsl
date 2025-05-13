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

// Parameters that are exposed/decided on the CPU-side. Stores data typically not expected to be changed once it reaches the GPU.
layout(set = 0, binding = 3, std430) restrict buffer Params {
    float image_size; // 0 (Counting byte alignment)
    float agent_count; // 4
    float screen_width; // 8
    float screen_height; // 12
    float radius; // 0
    float radius_squared; // 4 
    float delta; // 8
    float _padding; // 12
    float inv_mass[]; // 0
} params;

// The textures here are each used to pass the image back to the engine, as passing the shader data directly to a texture keeps everything
// on the GPU without having to pass it back over to CPU memory
layout(rgba32f, binding = 4) uniform image2D agent_data;