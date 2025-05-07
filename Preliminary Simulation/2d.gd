extends Node2D

@onready var agent_particles: GPUParticles2D = $AgentParticles

const AGENT_COUNT = 16384#65536

# Am image is used to store the position and color of the awgents
var IMAGE_SIZE = ceili(sqrt(AGENT_COUNT))
var agent_data : Image
var agent_data_texture_rd: Texture2DRD = Texture2DRD.new()

const MAX_VELOCITY: float = 32.0
var agent_positions: PackedVector2Array = []
var agent_velocities: PackedVector2Array = []

# Color is stored as ints, holding either 1s or 0s. The value is used to deterine the red channel
# of the agents. 
var agent_colors: PackedInt32Array = []

# Radius of the individual agents
var agent_radii: PackedFloat32Array = []

# Equivalent to vulkan logical device
var rendering_device: RenderingDevice
var agent_compute_shader: RID
var agent_pipeline: RID
var agent_bindings: Array[RDUniform]
var uniform_set: RID

var agent_position_buffer: RID
var agent_velocity_buffer: RID
var agent_color_buffer: RID
var agent_radii_buffer: RID
var agent_data_buffer: RID

var param_buffer: RID
var param_uniform: RDUniform

func _ready() -> void:
	generate_agents()
	agent_particles.amount = AGENT_COUNT
	
	agent_data = Image.create(IMAGE_SIZE, IMAGE_SIZE, false, Image.FORMAT_RGBAF)
	agent_data_texture_rd = agent_particles.process_material.get_shader_parameter("agent_data")
	RenderingServer.call_on_render_thread(setup_compute)

func generate_agents():
	for agent in AGENT_COUNT:
		var starting_position: Vector2 = Vector2(randf() * get_viewport_rect().size.x, randf() * get_viewport_rect().size.y)
		agent_positions.append(starting_position)
		agent_velocities.append(Vector2(randf_range(-1.0, 1.0 * MAX_VELOCITY), randf_range(-1.0, 1.0 * MAX_VELOCITY)))
		agent_colors.append(1 if randf() > 0.5 else 0)
		agent_radii.append(randf_range(5.0, 12.0))

func _process(delta: float) -> void:
	get_window().title = "FPS: " + str(Engine.get_frames_per_second())
	RenderingServer.call_on_render_thread(gpu_process.bind(delta))

func gpu_process(delta: float):
	var param_buffer_bytes = generate_parameter_buffer(delta)
	rendering_device.buffer_update(param_buffer, 0, param_buffer_bytes.size(), param_buffer_bytes)
	run_compute(agent_pipeline)


func generate_parameter_buffer(delta: float) -> PackedByteArray:
	var params_buffer_bytes : PackedByteArray = PackedFloat32Array([
		AGENT_COUNT,
		get_viewport_rect().size.x,
		get_viewport_rect().size.y,
		IMAGE_SIZE,
		delta
	]).to_byte_array()
	return params_buffer_bytes 


func run_compute(pipeline: RID):
	var compute_list: int = rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rendering_device.compute_list_dispatch(compute_list, ceil(AGENT_COUNT / 1024.), 1, 1)
	rendering_device.compute_list_end()

func setup_compute():
	rendering_device = RenderingServer.get_rendering_device()
	
	var shader: RDShaderFile = load("res://Preliminary Simulation/red-black-agents.glsl")
	var compiled_shader: RDShaderSPIRV = shader.get_spirv()
	agent_compute_shader = rendering_device.shader_create_from_spirv(compiled_shader)
	agent_pipeline = rendering_device.compute_pipeline_create(agent_compute_shader)
	
	agent_position_buffer = generate_packed_array_buffer(agent_positions)
	var agent_position_uniform: RDUniform = generate_compute_uniform(agent_position_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
	
	agent_velocity_buffer = generate_packed_array_buffer(agent_velocities)
	var agent_velocity_uniform: RDUniform = generate_compute_uniform(agent_velocity_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	
	agent_color_buffer = generate_packed_array_buffer(agent_colors)
	var agent_color_uniform: RDUniform = generate_compute_uniform(agent_color_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	
	agent_radii_buffer = generate_packed_array_buffer(agent_radii)
	var agent_radii_uniform: RDUniform = generate_compute_uniform(agent_radii_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3)
	
	var param_buffer_bytes = generate_parameter_buffer(0)
	param_buffer = rendering_device.storage_buffer_create(param_buffer_bytes.size(), param_buffer_bytes)
	param_uniform = generate_compute_uniform(param_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)
	
	# Prepares the image data to bind it to the GPU
	var texture_format: RDTextureFormat = RDTextureFormat.new()
	texture_format.width = IMAGE_SIZE
	texture_format.height = IMAGE_SIZE
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	
	var texture_view: RDTextureView = RDTextureView.new()
	agent_data_buffer = rendering_device.texture_create(texture_format, texture_view, [agent_data.get_data()])
	agent_data_texture_rd.texture_rd_rid = agent_data_buffer
	var agent_data_buffer_uniform = generate_compute_uniform(agent_data_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 5)
	
	agent_bindings = [
		agent_position_uniform,
		agent_velocity_uniform,
		agent_color_uniform,
		agent_radii_uniform,
		param_uniform,
		agent_data_buffer_uniform
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

func _exit_tree() -> void:
	RenderingServer.call_on_render_thread(free_resources)

func free_resources():
	rendering_device.free_rid(agent_data_buffer)
	rendering_device.free_rid(agent_radii_buffer)
	rendering_device.free_rid(agent_color_buffer)
	rendering_device.free_rid(agent_velocity_buffer)
	rendering_device.free_rid(agent_position_buffer)
	rendering_device.free_rid(uniform_set)
	rendering_device.free_rid(agent_pipeline)
	rendering_device.free_rid(agent_compute_shader)
