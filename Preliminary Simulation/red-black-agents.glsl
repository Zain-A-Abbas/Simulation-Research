#[compute]
#version 450

layout(local_size_x = 65536, local_size_y = 1, local_size_z = 1) in;

#include "agent-shared-data.glsl"

void main() {

}
