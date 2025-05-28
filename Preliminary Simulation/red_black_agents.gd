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
@onready var time_passed_label: Label = %TimePassedLabel
@onready var fps_label: Label = %FPSLabel
@onready var pause_button: Button = %PauseButton
@onready var save_button: Button = %SaveButton
@onready var hash_viewer: HashViewer = %HashViewer
@onready var agent_generator: AgentGenerator = %AgentGenerator

## Enum storing all possible scenarios that can be simulated.
enum Scenarios {
	LONG_RANGE_CONSTRAINT,
	OPPOSING_AGENTS,
	OPPOSING_SMALL_GROUPS,
	OPPOSING_LARGE_GROUPS,
	CIRCLE_POSITION_EXCHANGE
}

const RED_BLACK_AGENTS_CONFIG_FILE: String = "user://red_black_agents_config.json"

# If not set to 0, then all agents will spawn in the same locations with the same velocities
# (assuming all other variables are identical)
# DOES NOT CURRENTLY WORK WITH LONG RANGE CONSTAINT
const SEED: int = 0

#region The follow parameters are set based on the selected parameters in the Simulation Interface
## The currently chosen scenario
var scenario: Scenarios = Scenarios.LONG_RANGE_CONSTRAINT

## The number of agents.
var agent_count: int = 512

## Upper limit of velocity. 
var max_velocity: float = 32.0

## Radius of each agent.
var radius: float = 16.0

## Size of the world-space
var world_size: Vector2 = Vector2.ZERO

## Hash args
var use_spatial_hash: bool = false
var hash_count: int = 256
var horizontal_hash_count: int = 16
var vertical_hash_count: int = 16

#endregion

## Size of the textures that store the agent data.
var image_size: int = 0

## Set on run-time.
var count: int = 0

## Texture 1 stores the position and color of each agent. RD (Rendering Device) texture allows mapping the image data to the Vulkan logical device.
var agent_data_1_texture_rd: Texture2DRD
## Texture 2 is not currently used.
var agent_data_2_texture_rd: Texture2DRD

## Starting positions.
var agent_positions: PackedVector2Array = []
## The current velocities of agents.
var agent_velocities: PackedVector2Array = []
## Equal to starting velocities.
var agent_preferred_velocities: PackedVector2Array = []
## Corrections applied to agent positions each frame. z index is used as a counter
var delta_corrections: PackedVector4Array = []

## Where the agents move towards 
var locomotion_targets: PackedVector2Array = []
var use_locomotion_targets: bool = false

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
var hash_bindings: Array[RDUniform]
var image_bindings: Array[RDUniform]
## The uniform set holding all the GPU data.
var uniform_set: RID
var agent_set: RID
var hash_set: RID
var image_set: RID

## Buffer that stores the position of the agents.
var agent_position_buffer: RID
## Buffer that stores the velocity of the agents.
var agent_velocity_buffer: RID
## Buffer that stores the preferred velocity of the agents.
var agent_preferred_velocity_buffer: RID
## Buffer that stores the delta corrections of the agents.
var delta_corrections_buffer: RID
## Buffer that stores the locomotion targets of the agents.
var locomotion_targets_buffer: RID
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

var hash_size: int = 32
var hashes: Vector2i = Vector2i.ZERO

var hash_shader : RID
var hash_pipeline : RID

var hash_buffer : RID
var hash_sum_buffer : RID
var hash_prefix_sum_buffer : RID
var hash_index_tracker_buffer : RID
var hash_reindex_buffer : RID
var hash_params_buffer : RID

var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var parameters: Dictionary = {}

#region Engine Parameters (Parameters and settings controlled during run-time)

var paused: bool = false
var start_time: int = 0
var time_passed: int = 0

#endregion

## Stores the values saved every frame of execution
var simulation_saver: SimulationSaver = SimulationSaver.new()
var sim_file: FileAccess
var frame: int = 0

## Runs when the scene is loaded.
func _ready() -> void:
	import_config()
	if SEED == 0:
		rng.randomize()
	else:
		rng.seed = SEED
	
	start_time = Time.get_ticks_msec()
	
	# Connect GUI signals to functions
	pause_button.pressed.connect(pause)
	save_button.pressed.connect(save)
	
	agent_generator.generate_agents(self)
	image_size = ceili(sqrt(count))
	if parameters["disable_rendering"]:
		agent_particles.emitting = false
	else:
		agent_particles.amount = count
	
	agent_particles.process_material.set_shader_parameter("radius", radius)
	
	# Gets the texture resource stored on the shader.
	agent_data_1_texture_rd = agent_particles.process_material.get_shader_parameter("agent_data")
	RenderingServer.call_on_render_thread(setup_compute)


func import_config():
	var config_file: FileAccess = FileAccess.open(RED_BLACK_AGENTS_CONFIG_FILE, FileAccess.READ)
	var config_json: JSON = JSON.new()
	config_json.parse(config_file.get_as_text())
	parameters = config_json.data
	agent_count = parameters["agent_count"]
	max_velocity = parameters["max_velocity"]
	radius = parameters["radius"]
	scenario = Scenarios[parameters["scenario"]]
	get_tree().root.size = (Vector2i(parameters["window_width"], parameters["window_height"]))
	world_size = Vector2(parameters["world_width"], parameters["world_height"])
	
	if parameters.has("use_hashes"):
		use_spatial_hash = parameters["use_hashes"]
	
	if use_spatial_hash:
		hash_size = parameters["hash_size"]
		hashes = Vector2i(
			snappedf(world_size.x / hash_size + 0.4, 1),
			snappedf(world_size.y / hash_size + 0.4, 1),
		)
		hash_count = hashes.x * hashes.y
		
		
		hash_viewer.h_hashes = hashes.x
		hash_viewer.v_hashes = hashes.y
	hash_viewer.world_size = world_size
	hash_viewer.queue_redraw()
	
	if parameters["save"] == true:
		start_save()

func start_save():
	var file_location: String = "user://" + Time.get_datetime_string_from_system().replace(":", "-") + ".sav"
	sim_file = FileAccess.open(file_location, FileAccess.WRITE)
 
func pause():
	paused = !paused

func save():
	sim_file.close()
	
	# Now that the raw file has been saved, open it again and write its contents in a human-readable format
	simulation_saver.save_red_black(sim_file.get_path())
	
	start_save()


## Runs every frame.
func _process(delta: float) -> void:
	if paused:
		return
	
	time_passed = Time.get_ticks_msec() - start_time
	var hours: int = time_passed / 360000
	var minutes: int = (time_passed % 360000) / 60000
	var seconds: int = (time_passed % 60000) / 1000
	var ms: int = time_passed % 1000
	time_passed_label.text = "%02d:%02d:%02d.%03d" % [hours, minutes, seconds, ms]
	fps_label.text = "FPS: " + str(Engine.get_frames_per_second())
	
	var finalDelta: float = delta * float(!paused)
	RenderingServer.call_on_render_thread(gpu_process.bind(finalDelta))

## Processing behavior that has to run on the RenderingServer object.
func gpu_process(delta: float):
	if delta > 0:
		frame += 1
	
	var param_buffer_bytes: PackedByteArray = []
	
	# Hash setup
	if use_spatial_hash:
		param_buffer_bytes = generate_parameter_buffer(delta, 0) 
		rendering_device.buffer_update(param_buffer, 0, param_buffer_bytes.size(), param_buffer_bytes)
		run_compute(hash_pipeline, maxi(count, hash_count))
		param_buffer_bytes = generate_parameter_buffer(delta, 1) 
		rendering_device.buffer_update(param_buffer, 0, param_buffer_bytes.size(), param_buffer_bytes)
		run_compute(hash_pipeline, maxi(count, hash_count))
		param_buffer_bytes = generate_parameter_buffer(delta, 2) 
		rendering_device.buffer_update(param_buffer, 0, param_buffer_bytes.size(), param_buffer_bytes)
		run_compute(hash_pipeline, maxi(count, hash_count))
		param_buffer_bytes = generate_parameter_buffer(delta, 3) 
		rendering_device.buffer_update(param_buffer, 0, param_buffer_bytes.size(), param_buffer_bytes)
		run_compute(hash_pipeline, maxi(count, hash_count))
		param_buffer_bytes = generate_parameter_buffer(delta, 4) 
		rendering_device.buffer_update(param_buffer, 0, param_buffer_bytes.size(), param_buffer_bytes)
		run_compute(hash_pipeline, maxi(count, hash_count))
	
	# First pass
	param_buffer_bytes = generate_parameter_buffer(delta, 0)
	rendering_device.buffer_update(param_buffer, 0, param_buffer_bytes.size(), param_buffer_bytes)
	run_compute(agent_pipeline, maxi(count, hash_count))
	
	RenderingServer.force_sync() # May not be necessary
	
	# Second pass
	param_buffer_bytes = generate_parameter_buffer(delta, 1)
	rendering_device.buffer_update(param_buffer, 0, param_buffer_bytes.size(), param_buffer_bytes)
	run_compute(agent_pipeline, maxi(count, hash_count))
	
	# Testing saving
	#simulation_file.saved_floats.append(agent_data_1_texture_rd.get_image().get_data().to_float32_array())
	if parameters["save"] == true:
		sim_file.store_var((agent_data_1_texture_rd.get_image().get_data().to_float32_array()))

func generate_parameter_buffer(delta: float, stage: float) -> PackedByteArray:
	var floats: PackedFloat32Array = [
		image_size,
		count,
		world_size.x,
		world_size.y,
		radius,
		radius * radius * 1.05 * 1.05, #radius_squared
		delta,
		stage, # "Stage" variable,
		float(use_spatial_hash),
		float(use_locomotion_targets),
		0.0,
		0.0
	]
	
	# append_array must be used when including an additional array in parameter data
	var packed_data: PackedFloat32Array = []
	packed_data.append_array(floats)
	packed_data.append_array(agent_inv_mass)
	
	return packed_data.to_byte_array()

## The compute processing that is called every frame.
## num refers to the number of objects being operated on. 
func run_compute(pipeline: RID, num: int):
	var compute_list: int = rendering_device.compute_list_begin()
	rendering_device.compute_list_bind_compute_pipeline(compute_list, pipeline)
	#rendering_device.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rendering_device.compute_list_bind_uniform_set(compute_list, agent_set, 0)
	rendering_device.compute_list_bind_uniform_set(compute_list, hash_set, 1)
	rendering_device.compute_list_bind_uniform_set(compute_list, image_set, 2)
	rendering_device.compute_list_dispatch(compute_list, ceil(num / 1024.), 1, 1)
	rendering_device.compute_list_end()

## Sets up the computer shader once.
func setup_compute():
	rendering_device = RenderingServer.get_rendering_device()
	
	# Compiles the .glsl to spirv, and then creates the shader instance
	var shader: RDShaderFile = load("res://Preliminary Simulation/red_black_agents.glsl")
	var compiled_shader: RDShaderSPIRV = shader.get_spirv()
	agent_compute_shader = rendering_device.shader_create_from_spirv(compiled_shader)
	agent_pipeline = rendering_device.compute_pipeline_create(agent_compute_shader)
	
	shader = load("res://Preliminary Simulation/bin_operations.glsl")
	compiled_shader = shader.get_spirv()
	hash_shader = rendering_device.shader_create_from_spirv(compiled_shader)
	hash_pipeline = rendering_device.compute_pipeline_create(hash_shader)
	
	
	# Generates the buffers and then the uniform they are mapped to.
	
	agent_position_buffer = generate_packed_array_buffer(agent_positions)
	var agent_position_uniform: RDUniform = generate_compute_uniform(agent_position_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
	
	agent_velocity_buffer = generate_packed_array_buffer(agent_velocities)
	var agent_velocity_uniform: RDUniform = generate_compute_uniform(agent_velocity_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	
	agent_preferred_velocity_buffer = generate_packed_array_buffer(agent_preferred_velocities)
	var agent_preferred_velocity_uniform: RDUniform = generate_compute_uniform(agent_preferred_velocity_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	
	delta_corrections_buffer = generate_packed_array_buffer(delta_corrections)
	var delta_corrections_uniform: RDUniform = generate_compute_uniform(delta_corrections_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3)
	
	locomotion_targets_buffer = generate_packed_array_buffer(locomotion_targets)
	var locomotion_targets_uniform: RDUniform = generate_compute_uniform(locomotion_targets_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)
	
	agent_color_buffer = generate_packed_array_buffer(agent_colors)
	var agent_color_uniform: RDUniform = generate_compute_uniform(agent_color_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 5)
	
	#agent_radii_buffer = generate_packed_array_buffer(agent_radii)
	#var agent_radii_uniform: RDUniform = generate_compute_uniform(agent_radii_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 6)
	
	var param_buffer_bytes: PackedByteArray = generate_parameter_buffer(0, 0)
	param_buffer = rendering_device.storage_buffer_create(param_buffer_bytes.size(), param_buffer_bytes)
	param_uniform = generate_compute_uniform(param_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 6)
	
	var hash_param_buffer_bytes: PackedByteArray = PackedInt32Array([hash_size, hashes.x, hashes.y, hash_count]).to_byte_array()
	hash_params_buffer = rendering_device.storage_buffer_create(hash_param_buffer_bytes.size(), hash_param_buffer_bytes)
	var hash_params_uniform: RDUniform = generate_compute_uniform(hash_params_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 0)
	
	hash_buffer = generate_int_buffer(agent_count)
	var hash_buffer_uniform: RDUniform = generate_compute_uniform(hash_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 1)
	
	hash_sum_buffer = generate_int_buffer(hash_count)
	var hash_sum_buffer_uniform: RDUniform = generate_compute_uniform(hash_sum_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 2)
	
	hash_prefix_sum_buffer = generate_int_buffer(hash_count)
	var hash_prefix_sum_buffer_uniform: RDUniform = generate_compute_uniform(hash_prefix_sum_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 3)
	
	hash_index_tracker_buffer = generate_int_buffer(hash_count)
	var hash_index_tracker_buffer_uniform: RDUniform = generate_compute_uniform(hash_index_tracker_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 4)
	
	hash_reindex_buffer = generate_int_buffer(agent_count)
	var hash_reindex_buffer_uniform: RDUniform = generate_compute_uniform(hash_reindex_buffer, RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER, 5)
	
	# Prepares the image data to bind it to the GPU
	var texture_format: RDTextureFormat = RDTextureFormat.new()
	texture_format.width = image_size
	texture_format.height = image_size
	
	# Can be changed to a 64-bit format if the extra precision is ever needed.
	texture_format.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT 
	texture_format.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	
	var texture_view: RDTextureView = RDTextureView.new()
	agent_data_1_buffer = rendering_device.texture_create(texture_format, texture_view, [])
	agent_data_1_texture_rd.texture_rd_rid = agent_data_1_buffer
	var agent_data_1_buffer_uniform = generate_compute_uniform(agent_data_1_buffer, RenderingDevice.UNIFORM_TYPE_IMAGE, 0)
	
	agent_bindings = [
		agent_position_uniform, # 0
		agent_velocity_uniform, # 1
		agent_preferred_velocity_uniform, # 2
		delta_corrections_uniform, # 3
		locomotion_targets_uniform, # 4
		agent_color_uniform, # 5
				#agent_radii_uniform,
		param_uniform, # 6
	]
	
	hash_bindings = [
		hash_params_uniform, # 7
		hash_buffer_uniform, # 8
		hash_sum_buffer_uniform, # 9
		hash_prefix_sum_buffer_uniform, # 10
		hash_index_tracker_buffer_uniform, # 11
		hash_reindex_buffer_uniform, # 12
	]
	
	image_bindings = [
		agent_data_1_buffer_uniform
	]
	
	#uniform_set = rendering_device.uniform_set_create(agent_bindings, agent_compute_shader, 0)
	agent_set = rendering_device.uniform_set_create(agent_bindings, agent_compute_shader, 0)
	hash_set = rendering_device.uniform_set_create(hash_bindings, agent_compute_shader, 1)
	image_set = rendering_device.uniform_set_create(image_bindings, agent_compute_shader, 2)
	

func generate_packed_array_buffer(data) -> RID:
	var data_bytes: PackedByteArray = data.to_byte_array()
	var data_buffer: RID = rendering_device.storage_buffer_create(data_bytes.size(), data_bytes)
	return data_buffer

func generate_int_buffer(size: int):
	var data = []
	data.resize(size)
	var data_buffer_bytes = PackedInt32Array(data).to_byte_array()
	var data_buffer = rendering_device.storage_buffer_create(data_buffer_bytes.size(), data_buffer_bytes)
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
	rendering_device.free_rid(agent_preferred_velocity_buffer)
	rendering_device.free_rid(delta_corrections_buffer)
	rendering_device.free_rid(locomotion_targets_buffer)
	rendering_device.free_rid(agent_position_buffer)
	rendering_device.free_rid(uniform_set)
	rendering_device.free_rid(hash_set)
	rendering_device.free_rid(agent_set)
	rendering_device.free_rid(image_set)
	rendering_device.free_rid(agent_pipeline)
	rendering_device.free_rid(agent_compute_shader)
	rendering_device.free_rid(hash_buffer)
	rendering_device.free_rid(hash_sum_buffer)
	rendering_device.free_rid(hash_params_buffer)
	rendering_device.free_rid(hash_reindex_buffer)
	rendering_device.free_rid(hash_prefix_sum_buffer)
	rendering_device.free_rid(hash_index_tracker_buffer)
