extends Node2D

@onready var agent_particles: GPUParticles2D = %AgentParticles

const AGENT_COUNT = 65536
const MAX_VELOCITY: float = 4.0
var agent_positions: PackedVector2Array = []
var agent_velocities: PackedVector2Array = []
# Color is stored as bytes, holding either 1s or 0s. The value is used to deterine the red channel
# of the agents. 
var agent_colors: PackedByteArray = []

# The above variable is used in this one to communicate to the GPU
var agent_data_texture_rd: Texture2DRD = Texture2DRD.new()

# Equivalent to vulkan logical device
var rendering_device: RenderingDevice

func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	
	generate_agents()
	
	agent_particles.amount = AGENT_COUNT;
	RenderingServer.call_on_render_thread(setup_compute)

func generate_agents():
	for agent in AGENT_COUNT:
		agent_positions.append(Vector2(randf() * get_viewport_rect().size.x, randf() * get_viewport_rect().size.y))
		agent_velocities.append(Vector2(randf_range(-1.0, 1.0 * MAX_VELOCITY), randf_range(-1.0, 1.0 * MAX_VELOCITY)))
		agent_colors.append(1 if randf() > 0.5 else 0)

func _process(delta: float) -> void:
	pass

func setup_compute():
	rendering_device = RenderingServer.get_rendering_device()
	
