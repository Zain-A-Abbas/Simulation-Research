#[compute]
#version 450

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
    float _padding; // 12
    float inv_mass[]; // 0
} params;

// The textures here are each used to pass the image back to the engine, as passing the shader data directly to a texture keeps everything
// on the GPU without having to pass it back over to CPU memory
layout(rgba32f, binding = 6) uniform image2D agent_data;

const float INV_MASS = 0.01625;
const float EPSILON = 0.0001;
const float C_TAO_MAX = 20.0;
const float C_TAO_0 = 20.0;
const float dv_i = 1.0;
const float C_LONG_RANGE_STIFF = 0.02;
const float MAX_DELTA = 0.9;


float random(uvec3 st) {
    return fract(sin(dot(st.xy ,vec2(12.9898,78.233))) * 43758.5453123);
}

vec2 clamp2D(float vx, float vy, float maxValue) {
  const float lengthV = sqrt(vx * vx + vy * vy);
  if (lengthV > maxValue) {
    const float mult = (maxValue / lengthV);
    vx *= mult;
    vy *= mult;
  }
  return vec2(vx, vy);
}


// From the original function, x and z (y here) are presumably the starting positions, while px and pz (py here) are the positions
// after adding the velocity and deltas.
// To keep the same functionality, px/py are computed on the spot here.
void longRangeConstraint(int i, int j) {
    vec2 ip = agent_pos.data[i] + agent_vel.data[i] * params.delta;
    vec2 jp = agent_pos.data[j] + agent_vel.data[j] * params.delta;
    
    
    const float dist = distance(agent_pos.data[i], agent_pos.data[j]);
    float radius_sq = params.radius_squared;
    if (params.radius > dist) {
        radius_sq = pow((params.radius - dist), 2.0);    
    }
    const float v_x = (ip.x - agent_pos.data[i].x) / params.delta - (jp.x - agent_pos.data[j].x) / params.delta;
    const float v_y = (ip.y - agent_pos.data[i].y) / params.delta - (jp.y - agent_pos.data[j].y) / params.delta;
    const float x0 = agent_pos.data[i].x - agent_pos.data[j].x; 
    const float y0 = agent_pos.data[i].y - agent_pos.data[j].y; 
    const float v_sq = v_x * v_x + v_y * v_y;
    const float x0_sq = x0 * x0;
    const float y0_sq = y0 * y0;
    const float x_sq = x0_sq + y0_sq; 
    const float a = v_sq;
    const float b = -v_x * x0 - v_y * y0;   // b = -1 * v_.dot(x0_).  Have to check this. 
    const float b_sq = b * b;
    const float c = x_sq - radius_sq;
    const float d_sq = b_sq - a * c;
    const float d = sqrt(d_sq);
    const float tao = (b - d) / a;
    float lengthV;
    if (d_sq > 0.0 && abs(a) > EPSILON && tao > 0 && tao < C_TAO_MAX){
        const float clamp_tao = exp(-tao * tao / C_TAO_0);
        const float c_tao = clamp_tao;
        const float tao_sq = c_tao * c_tao;
        const float grad_x_i = 2 * c_tao * ((dv_i / a) * ((-2. * v_x * tao) - (x0 + (v_y * x0 * y0 + v_x * (radius_sq - y0_sq)) / d)));
        const float grad_y_i = 2 * c_tao * ((dv_i / a) * ((-2. * v_y * tao) - (y0 + (v_x * x0 * y0 + v_y * (radius_sq - x0_sq)) / d)));
        const float grad_x_j = -grad_x_i;
        const float grad_y_j = -grad_y_i;
        const float stiff =C_LONG_RANGE_STIFF * exp(-tao * tao / C_TAO_0);    //changed
        const float s =  stiff * tao_sq / (params.inv_mass[i] * (grad_y_i * grad_y_i + grad_x_i * grad_x_i) + params.inv_mass[j]  * (grad_y_j * grad_y_j + grad_x_j * grad_x_j));     //changed


        lengthV = sqrt(s * params.inv_mass[i] * grad_x_i * s * params.inv_mass[i] * grad_x_i 
                            + s * params.inv_mass[i] * grad_y_i * s * params.inv_mass[i] * grad_y_i);

        vec2 delta_correction_i = clamp2D(
            s * params.inv_mass[i] * grad_x_i,
            s * params.inv_mass[i] * grad_y_i,
            MAX_DELTA
            );          
                                    
        vec2 delta_correction_j = clamp2D(
            s * params.inv_mass[j] * grad_x_j,
            s * params.inv_mass[j] * grad_y_j,
            MAX_DELTA
            ); 

        delta_corrections.data[i].x += delta_correction_i.x;
        delta_corrections.data[j].y += delta_correction_j.y;
        delta_corrections.data[i].z += 1.0;
        /*delta_corrections.data[i].y += delta_correction_i.y;
        delta_corrections.data[j].x += delta_correction_j.x;
        delta_corrections.data[j].z += 1.0;*/

        /*agent_pos.data[i].x += delta_correction_i.x;
        agent_pos.data[i].y += delta_correction_i.y;
        agent_pos.data[j].x += delta_correction_j.x;
        agent_pos.data[j].y += delta_correction_j.y;*/
    }
}

void main() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= params.agent_count) {return;}

    delta_corrections.data[idx] = vec4(0.0);

    vec2 move = agent_vel.data[idx] * params.delta;
        //agent_pos.data[idx].x += 10.0;
        //agent_pos.data[idx].y += 10.0;


    for (int i = 0; i < params.agent_count; i++) {
        if (i == idx) {continue;}
        longRangeConstraint(idx, i);
    }

    if (delta_corrections.data[idx].z > 0.0) {
        move.x += delta_corrections.data[idx].x / delta_corrections.data[idx].z;
        move.y += delta_corrections.data[idx].y / delta_corrections.data[idx].z;
    }

    agent_pos.data[idx] += move;

    if (agent_pos.data[idx].x > params.screen_width) {agent_pos.data[idx].x -= params.screen_width;}
    if (agent_pos.data[idx].y > params.screen_height) {agent_pos.data[idx].y -= params.screen_height;}
    if (agent_pos.data[idx].x < 0) {agent_pos.data[idx].x += params.screen_width;}
    if (agent_pos.data[idx].y < 0) {agent_pos.data[idx].y += params.screen_height;}

    // Turns this agent's index into x/y to find the corresponding pixel on the texture
    ivec2 pixel_coord = ivec2(
        int(mod(idx, params.image_size)),
        int(idx / params.image_size)
    );

    imageStore(agent_data, pixel_coord, vec4(agent_pos.data[idx].x, agent_pos.data[idx].y, agent_color.data[idx], 1.0));
}
