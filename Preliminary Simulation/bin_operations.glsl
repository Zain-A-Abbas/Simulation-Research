#[compute]
#version 450

#include "shared_data.glsl"

void zero_hashes() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx < hash_params.hash_count) {
        hash_sum.data[idx] = 0;
    }
}

void sum() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx < params.agent_count) {
        atomicAdd(hash_sum.data[hash.data[idx]], 1);
    }    
}

void prefix_sum() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= hash_params.hash_count) return;

    hash_prefix_sum.data[idx] = 0;

    for (int i = 0; i <= idx; i++) {
        hash_prefix_sum.data[idx] += hash_sum.data[i];
    }
}

void prefix_sum_shift() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= hash_params.hash_count) return;
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
        zero_hashes();
    }
    else if (params.stage == 1.0) {
        sum();
    }
    else if (params.stage == 2.0) {
        prefix_sum();
    }
    else if (params.stage == 3.0) {
        prefix_sum_shift();
    }
    else if (params.stage == 4.0) {
        reindex();
    }
}