#[compute]
#version 450

#include "shared_data.glsl"

const float INV_MASS = 0.01625;
const float EPSILON = 0.0001;
const float C_TAO_MAX = 20.0;
const float C_TAO_0 = 20.0;
const float dv_i = 1.0;
const float C_LONG_RANGE_STIFF = 0.32;
const float MAX_DELTA = 110.9;
const float MAX_SPEED = 32.0;
const float ksi = 0.1;
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
        if (j == debugging_data.tracked_idx) {
            agent_tracked.data[i] = 1.0;
        }

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
        delta_corrections.data[i].y += delta_correction_i.y;
        delta_corrections.data[i].z += 1.0;

        delta_corrections.data[j].x += delta_correction_j.x;
        delta_corrections.data[j].y += delta_correction_j.y;
        delta_corrections.data[j].z += 1.0;

        /*agent_pos.data[i].x += delta_correction_i.x;
        agent_pos.data[i].y += delta_correction_i.y;
        agent_pos.data[j].x += delta_correction_j.x;
        agent_pos.data[j].y += delta_correction_j.y;*/
    }
}

vec2 rotate_velocity(int idx) {
    vec2 curr_pos = agent_pos.data[idx];
    vec2 pref_vel = agent_pref_vel.data[idx];
    vec2 loc_targ = locomotion_targets.data[idx];

    vec2 direction = normalize(loc_targ - curr_pos);
    float angle = acos(clamp(dot(direction, normalize(pref_vel)), -1.0, 1.0));
    
    mat2 rot_mat = mat2(
        cos(angle), sin(angle),
        -sin(angle), cos(angle)
    ); // The sines are flipped here because GLSL defines matrices in column-major order 

    return pref_vel * rot_mat;
}

void correctionsStage() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= params.agent_count) {return;}

    agent_tracked.data[idx] = 0.0;

    delta_corrections.data[idx] = vec4(0.0);

    if (params.use_spatial_hash > 0.0) {
        int agent_hash = hash.data[idx];
        vec2 hash_location = one_to_two(agent_hash, hash_params.hash_x);
        vec2 starting_hash = hash_location - vec2(1, 1); // upper-left of own hash
        vec2 current_hash = starting_hash;
        
        for (int y = 0; y < 3; y++) {
            current_hash.y = starting_hash.y + y;
            if (current_hash.y < 0 || current_hash.y > hash_params.hash_y) continue;
            
            for (int x = 0; x < 3; x++) {
                current_hash.x = starting_hash.x + x;
                if (current_hash.x < 0 || current_hash.x > hash_params.hash_x) continue;

                int hash_index = two_to_one(current_hash, hash_params.hash_x);

                for (int i = hash_prefix_sum.data[hash_index - 1]; i < hash_prefix_sum.data[hash_index]; i++) {
                    int other_agent = hash_reindex.data[i];
                    if (other_agent == idx) continue;
                    longRangeConstraint(idx, other_agent);
                } 
            }
        }
    }
    else {
        for (int j = 0; j < params.agent_count; j++) {
            if (j == idx) {continue;}
            longRangeConstraint(idx, j);
        }
    }

}

void moveStage() {
    int idx = int(gl_GlobalInvocationID.x);
    if (idx >= params.agent_count) {return;}

    
    if (delta_corrections.data[idx].z > 0.0) {
        agent_vel.data[idx] += delta_corrections.data[idx].xy / delta_corrections.data[idx].z;
    }

    agent_vel.data[idx] = clamp2D(agent_vel.data[idx].x, agent_vel.data[idx].y, MAX_SPEED);
    
    agent_pos.data[idx] += agent_vel.data[idx] * params.delta;

    if (agent_pos.data[idx].x > params.world_width) {agent_pos.data[idx].x -= params.world_width;}
    if (agent_pos.data[idx].y > params.world_height) {agent_pos.data[idx].y -= params.world_height;}
    if (agent_pos.data[idx].x < 0) {agent_pos.data[idx].x += params.world_width;}
    if (agent_pos.data[idx].y < 0) {agent_pos.data[idx].y += params.world_height;}

    // Turns this agent's index into x/y to find the corresponding pixel on the texture
    ivec2 pixel_coord = ivec2(
        int(mod(idx, params.image_size)),
        int(idx / params.image_size)
    );

    agent_vel.data[idx] = ksi * agent_pref_vel.data[idx]  + (1.0-ksi) * agent_vel.data[idx];

    if (params.use_spatial_hash > 0.0) {
        hash.data[idx] = int(agent_pos.data[idx].x / hash_params.hash_size) + int(agent_pos.data[idx].y / hash_params.hash_size) * hash_params.hash_x;
    }

    if (params.use_locomotion_targets > 0.0) {
        if (dot(agent_pos.data[idx] - locomotion_targets.data[idx], agent_pos.data[idx] - locomotion_targets.data[idx]) < 4.0) {
            agent_pref_vel.data[idx] = vec2(0.0);
            agent_vel.data[idx] = vec2(0.0);
        } else {
            agent_pref_vel.data[idx] = rotate_velocity(idx);
        }
    }


    if ( length(vec2(params.click_x, params.click_y)) > 0.01) {
        if (distance(vec2(params.click_x, params.click_y), agent_pos.data[idx]) < params.radius) {
            debugging_data.tracked_idx = idx;
        }
    }

    imageStore(agent_data, pixel_coord, vec4(agent_pos.data[idx].x, agent_pos.data[idx].y, agent_vel.data[idx].x, agent_vel.data[idx].y));
    imageStore(agent_data_2, pixel_coord, vec4(float(debugging_data.tracked_idx == idx), agent_tracked.data[idx], 0.0, 0.0));
    
}

void main() {

    if (params.stage == 0.0) {
        correctionsStage();
    }
    else if (params.stage == 1.0) {
        moveStage();
    }

}
