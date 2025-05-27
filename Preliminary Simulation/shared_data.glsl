layout(local_size_x = 1024, local_size_y = 1, local_size_z = 1) in;

layout(set = 0, binding = 0, std430) restrict buffer Position {
    vec2 data[];
} agent_pos;

layout(set = 0, binding = 1, std430) restrict buffer Velocity {
    vec2 data[];
} agent_vel;

layout(set = 0, binding = 2, std430) restrict buffer PreferredVelocity {
    vec2 data[];
} agent_pref_vel;

// z index functions as a counter
layout(set = 0, binding = 3, std430) restrict buffer DeltaCorrections {
    vec4 data[];
} delta_corrections;

layout(set = 0, binding = 4, std430) restrict buffer Color {
    int data[];
} agent_color;

/*layout(set = 0, binding = 5, std430) restrict buffer Radius {
    float data[];
} agent_radius;*/

// Parameters that are exposed/decided on the CPU-side. Stores data typically not expected to be changed once it reaches the GPU.
layout(set = 0, binding = 5, std430) restrict buffer Params {
    float image_size; // 0 (Counting byte alignment)
    float agent_count; // 4
    float screen_width; // 8
    float screen_height; // 12
    float radius; // 0
    float radius_squared; // 4 
    float delta; // 8
    float stage; // 12
    float use_spatial_hash; // 0
    float padding; // 4 (not using vec3 for padding because some glsl implementations treat vec3 as vec4)
    float padding_2; // 8 (not using vec3 for padding because some glsl implementations treat vec3 as vec4)
    float padding_3; // 12 (not using vec3 for padding because some glsl implementations treat vec3 as vec4)
    float inv_mass[]; // 0
} params;

layout(set = 0, binding = 6, std430) restrict buffer HashParams {
    int hash_size;
    int hash_x;
    int hash_y;
    int hash_count;
} hash_params;

// Stores which space each agent is in
layout(set = 0, binding = 7, std430) restrict buffer Hash {
    int data[];
} hash;

// Array number of agents in each hash (i.e. if 2 agents in hash 5, then data[5] == 2)
layout(set = 0, binding = 8, std430) restrict buffer HashCount {
    int data[];
} hash_sum;

// The cumulative agents stored in each hash up until this one
layout(set = 0, binding = 9, std430) restrict buffer ReindexHashCount {
    int data[];
} hash_prefix_sum;

// As above, but with every element shifted one to the right
layout(set = 0, binding = 10, std430) restrict buffer ReindexHash {
    int data[];
} hash_index_tracker;

layout(set = 0, binding = 11, std430) restrict buffer ReindexHashPositions {
    int data[];
} hash_reindex;

// The textures here are each used to pass the image back to the engine, as passing the shader data directly to a texture keeps everything
// on the GPU without having to pass it back over to CPU memory
layout(rgba32f, binding = 12) uniform image2D agent_data;

ivec2 one_to_two(int index, int grid_width) {
    int row = int(index / grid_width);
    int col = int(mod(index, grid_width));
    return ivec2(col,row);
}

int two_to_one(vec2 index, int grid_width) {
    int row = int(index.y);
    int col = int(index.x);
    return row * grid_width + col;
}