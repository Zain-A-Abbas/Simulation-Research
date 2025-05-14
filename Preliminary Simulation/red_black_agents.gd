extends Node2D
class_name RedBlackAgents

## Class that creates the necessary buffers and uniforms to pass on agent simulation data to the GPU.
##
## The data of each individual agent is stored across textures, the reason for this being that Godot stores
## texture data entirely on the GPU, while allowing both compute, fragment, and vertex shaders to easily read and write from a texture.
## This prevents there from being a bottleneck in rendering as no rendering data has to pass by the CPU.
## The way this approach works in practice is that each pixel on the textures maps to a specific particle, and that the R, G, B, and A 
## channels on each texture stores a different piece of data.[br][br]
## e.g. the R and G channels on the 'agent_data_1' texture store the x and y position of each agent.[br][br]
## The [b]red_black_agents.glsl[/b] source code has the computer shader logic, while the [b]red_black_agents_shader.gdshader[/b] file is
## the particle shader used for actually rendering the agents to the screen.

## The node that is used to draw the agents to screen.
@onready var agent_particles: GPUParticles2D = $AgentParticles

## The number of agents.
const AGENT_COUNT = 8192

## Upper limit of velocity. 
const MAX_VELOCITY: float = 32.0
## Radius of each agent.
const RADIUS: float = 8.0

## Size of the textures that store the agent data.
var IMAGE_SIZE = ceili(sqrt(AGENT_COUNT))

## Texture 1 stores the position and color of each agent. RD (Rendering Device) texture allows mapping the image data to the Vulkan logical device.
var agent_data_1_texture_rd: Texture2DRD
## Texture 2 is not currently used.
var agent_data_2_texture_rd: Texture2DRD

## Starting positions.
var agent_positions: PackedVector2Array = []
## Starting velocities.
var agent_velocities: PackedVector2Array = []

## Color is stored as ints, holding either 1s or 0s. The value is used to deterine the red channel of the agents. 
var agent_colors: PackedInt32Array = []

## The inverted mass of each agent.
var agent_inv_mass: PackedFloat32Array = []

## Radius of the individual agents. Only used when performing a simulation where agents have variable sizes.
var agent_radii: PackedFloat32Array = []

## Squared radius of the individual agents. Only used when performing a simulation where agents have variable sizes.
var agent_radii_sqr: PackedFloat32Array = []

## The logical rendering device; allows for interaction with the low-level graphics API.
var rendering_device: RenderingDevice

## The shader instance created from SPIR-V.
var agent_compute_shader: RID
## The pipeline in which all of the compute commands are passed through.
var agent_pipeline: RID
## The bindings used to create the uniforms from.
var agent_bindings: Array[RDUniform]
## The uniform set holding all the GPU data.
var uniform_set: RID

## Buffer that stores the position of the agents.
var agent_position_buffer: RID
## Buffer that stores the velocity of the agents.
var agent_velocity_buffer: RID
## Buffer that stores the color data of the agents.
var agent_color_buffer: RID
## Buffer that stores the radii of the agents. Only used when performing a simulation where agents have variable sizes.
var agent_radii_buffer: RID
## Buffer that stores the squared radii of the agents. Only used when performing a simulation where agents have variable sizes.
var agent_radii_squared_buffer: RID
## Buffer that stores the first data-storing texture.
var agent_data_1_buffer: RID
## Buffer that stores the second data-storing texture.
var agent_data_2_buffer: RID

## Buffer that stores the tunable parameters.
var param_buffer: RID
## Uniform for the previous buffer.
var param_uniform: RDUniform

## Runs when the scene is loaded.
func _ready() -> void:
	generate_agents()
	agent_particles.amount = AGENT_COUNT
	 
	# Gets the texture resource stored on the shader.
	agent_data_1_texture_rd = agent_particles.process_material.get_shader_parameter("agent_data")
	RenderingServer.call_on_render_thread(setup_compute)

## Generates the initial information of all agents, such as starting position/velocity, as well as the color.
func generate_agents():
	for agent in AGENT_COUNT:
		var starting_position: Vector2 = Vector2(randf() * get_viewport_rect().size.x, randf() * get_viewport_rect().size.y)
		agent_positions.append(starting_position)
		agent_velocities.append(Vector2(randf_range(-1.0, 1.0 * MAX_VELOCITY), randf_range(-1.0, 1.0 * MAX_VELOCITY)))
		agent_colors.append(1 if randf() > 0.5 else 0)
		agent_inv_mass.append(randf_range(1.0, 2.0)) # Unsure as of yet if this range is correct. 
		#agent_radii.append(RADIUS)

## Runs every frame.
func _process(delta: float) -> void:
	get_window().title = "FPS: " + str(Engine.get_frames_per_second())
	RenderingServer.call_on_render_thread(gpu_process.bind(delta))

## Processing behavior that has to run on the RenderingServer object.
func gpu_process(delta: float):
	var param_buffer_bytes = generate_parameter_buffer(delta)
	rendering_device.buffer_update(param_buffer, 0, param_buffer_bytes.size(), param_buffer_bytes)
	run_compute(agent_pipeline)

func generate_parameter_buffer(delta: float) -> PackedByteArray:
	var floats: PackedFloat32Array = [
		IMAGE_SIZE,
		AGENT_COUNT,
		get_viewport_rect().size.x,
		get_viewport_rect().size.y,
		RADIUS,
		RADIUS * RADIUS,
		delta,
		0.0 # Padding
	]
	
	# append_array must be used when including an additional array in parameter data
	var packed_data: PackedFloat32Array = []
	packed_data.append_array(floats)
	packed_data.append_array(agent_inv_mass)
	
	return packed_data.to_byte_array()

## The compute processing that is called every frame.
func run_compute(pipeline: RID):
	var compute_list: int = rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rendering_device.compute_list_dispatch(compute_list, ceil(AGENT_COUNT / 1024.), 1, 1)
	rendering_device.compute_list_end()

## Sets up the computer shader once.
func setup_compute():
	rendering_device = RenderingServer.get_rendering_device()
	
	# Compiles the .glsl to spirv, and then creates the shader instance
	var shader: RDShaderFile = load("res://Preliminary Simulation/red_black_agents.glsl")
	var compiled_shader: RDShaderSPIRV = shader.get_spirv()
	agent_compute_shader = rendering_device.shader_create_from_spirv(compiled_shader)
	agent_pipeline = rendering_device.compute_pipeline_create(agent_compute_shader)
	
	# Generates the buffers and then the uniform they are mapped to.
	
	agent_position_buffer = generate_packed_array_buffer(agent_positions)
	var agent_position_uniform: RDUniform = generate_compute_uniform(agent_position_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
	
	agent_velocity_buffer = generate_packed_array_buffer(agent_velocities)
	var agent_velocity_uniform: RDUniform = generate_compute_uniform(agent_velocity_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	
	agent_color_buffer = generate_packed_array_buffer(agent_colors)
	var agent_color_uniform: RDUniform = generate_compute_uniform(agent_color_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	
	#agent_radii_buffer = generate_packed_array_buffer(agent_radii)
	#var agent_radii_uniform: RDUniform = generate_compute_uniform(agent_radii_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3)
	
	var param_buffer_bytes = generate_parameter_buffer(0)
	param_buffer = rendering_device.storage_buffer_create(param_buffer_bytes.size(), param_buffer_bytes)
	param_uniform = generate_compute_uniform(param_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3)
	
	# Prepares the image data to bind it to the GPU
	var texture_format: RDTextureFormat = RDTextureFormat.new()
	texture_format.width = IMAGE_SIZE
	texture_format.height = IMAGE_SIZE
	
	# Can be changed to a 64-bit format if the extra precision is ever needed.
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT 
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	
	var texture_view: RDTextureView = RDTextureView.new()
	agent_data_1_buffer = rendering_device.texture_create(texture_format, texture_view, [])
	agent_data_1_texture_rd.texture_rd_rid = agent_data_1_buffer
	var agent_data_1_buffer_uniform = generate_compute_uniform(agent_data_1_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 4)
	
	agent_bindings = [
		agent_position_uniform,
		agent_velocity_uniform,
		agent_color_uniform,
		#agent_radii_uniform,
		param_uniform,
		agent_data_1_buffer_uniform
	]
	
	uniform_set = rendering_device.uniform_set_create(agent_bindings, agent_compute_shader, 0)

func generate_packed_array_buffer(data) -> RID:
	var data_bytes: PackedByteArray = data.to_byte_array()
	var data_buffer: RID = rendering_device.storage_buffer_create(data_bytes.size(), data_bytes)
	return data_buffer


func generate_compute_uniform(buffer: RID, type: RenderingDevice.UniformType, binding: int) -> RDUniform:
	var uniform: RDUniform = RDUniform.new()
	uniform.uniform_type = type
	uniform.binding = binding
	uniform.add_id(buffer)
	return uniform

## Called on scene exit.
func _exit_tree() -> void:
	RenderingServer.call_on_render_thread(free_resources)

## Frees up the GPU memory.
func free_resources():
	rendering_device.free_rid(agent_data_1_buffer)
	#rendering_device.free_rid(agent_radii_buffer)
	rendering_device.free_rid(agent_color_buffer)
	rendering_device.free_rid(agent_velocity_buffer)
	rendering_device.free_rid(agent_position_buffer)
	rendering_device.free_rid(uniform_set)
	rendering_device.free_rid(agent_pipeline)
	rendering_device.free_rid(agent_compute_shader)
