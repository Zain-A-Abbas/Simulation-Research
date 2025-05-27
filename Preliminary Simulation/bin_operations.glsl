#[compute]
#version 450

#include "shared_data.glsl"

void sum() {
    int idx = int(gl_GlobalInvocationID.x);

    if (idx < hash_params.hash_count) {
        hash_sum.data[idx] = 0;
    }
    barrier();

    if (idx < params.agent_count) {
        atomicAdd(hash_sum.data[hash.data[idx]], 1);

        /*if (params.color_mode == 4) {
            ivec2 my_pos = one_to_two(idx, int(params.image_size));
            imageStore(boid_data, my_pos, vec4(0,0,0,0));
        }*/
    }    
}

void prefix_sum() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= hash_params.hash_count) return;

    hash_prefix_sum.data[idx] = 0;

    for (int i = 0; i <= idx; i++) {
        hash_prefix_sum.data[idx] += hash_sum.data[i];
    }

    barrier(); 
    
    // Shifting the array of each sum
    hash_index_tracker.data[idx] = 0;
    if (idx > 0) {
        hash_index_tracker.data[idx] = hash_prefix_sum.data[idx - 1];
    }
}

void reindex() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= params.agent_count) return;

    int curr_hash = hash.data[idx];

    int last_index = atomicAdd(hash_index_tracker.data[curr_hash], 1);
    hash_reindex.data[last_index] = idx;
}

void main() {
    
    if (params.stage == 0.0) {
        sum();
    }
    else if (params.stage == 1.0) {
        prefix_sum();
    }
    else if (params.stage == 2.0) {
        reindex();
    }
}