extends Node
class_name AgentGenerator

func distance_constraint(red_black_agents: RedBlackAgents):
	red_black_agents.count = red_black_agents.agent_count
	for agent in red_black_agents.agent_count:
		var starting_position: Vector2 = Vector2(red_black_agents.rng.randf() * red_black_agents.world_size.x, red_black_agents.rng.randf() * red_black_agents.world_size.y)
		red_black_agents.agent_positions.append(starting_position)
		var starting_vel: Vector2 = Vector2(red_black_agents.rng.randf_range(-1.0, 1.0) * red_black_agents.max_velocity, red_black_agents.rng.randf_range(-1.0, 1.0) * red_black_agents.max_velocity)
		red_black_agents.agent_velocities.append(starting_vel)
		red_black_agents.agent_preferred_velocities.append(starting_vel)
		red_black_agents.delta_corrections.append(Vector4.ZERO)
		red_black_agents.locomotion_targets.append(Vector2.ZERO)
		red_black_agents.agent_tracked.append(0.0)
		red_black_agents.agent_inv_mass.append(red_black_agents.rng.randf_range(0.2, 0.4)) # Unsure as of yet if this range is correct. 
		#agent_radii.append(radius)

func opposing_agents(red_black_agents: RedBlackAgents):
	red_black_agents.agent_count = 2
	red_black_agents.count = red_black_agents.agent_count
	red_black_agents.agent_positions.append_array([
		Vector2(200, 200),
		Vector2(500, 200)
		])
	red_black_agents.agent_velocities.append_array([
		Vector2(20, 0),
		Vector2(-20, 0)
		])
	red_black_agents.agent_preferred_velocities.append_array([
		Vector2(20, 0),
		Vector2(-20, 0)
		])
	red_black_agents.delta_corrections.append_array([
		Vector4.ZERO,
		Vector4.ZERO
		])
	red_black_agents.locomotion_targets.append_array([Vector2.ZERO, Vector2.ZERO])
	red_black_agents.agent_tracked.append_array([0.0, 0.0])
	red_black_agents.agent_inv_mass.append_array([
		0.2,
		0.2
	])

func opposing_groups(red_black_agents: RedBlackAgents, small: bool):
	red_black_agents.count = red_black_agents.agent_count
	var agents_per_group: int = red_black_agents.count / 2
	var agents_per_row: int = 0
	var rows: int = 0
	
	if small:
		agents_per_row = sqrt(agents_per_group) * 2
		rows = sqrt(agents_per_group) / 2
	else:
		agents_per_row = sqrt(agents_per_group) / 2
		rows = sqrt(agents_per_group) * 2
	
	var agent_gap: Vector2 = Vector2(red_black_agents.radius * 2 * 1.25, red_black_agents.radius * 2 * 1.25)
	var group_positions: Array[Vector2] = [
		Vector2(100, 200),
		Vector2(100 + agents_per_row * agent_gap.x + red_black_agents.parameters["opposing_groups_x_distance"], 200 + red_black_agents.parameters["opposing_groups_y_offset"])
		]
	var group_velocities: Array[Vector2] = [Vector2(red_black_agents.max_velocity, 0), Vector2(-red_black_agents.max_velocity, 0)]
	for z in 2:
		for row in rows:
			for row_position in agents_per_row:
				red_black_agents.agent_positions.append(group_positions[z] + Vector2(row_position * agent_gap.x, row * agent_gap.y))
				red_black_agents.agent_velocities.append(group_velocities[z])
				red_black_agents.agent_preferred_velocities.append(group_velocities[z])
				red_black_agents.delta_corrections.append(Vector4.ZERO)
				red_black_agents.locomotion_targets.append(Vector2.ZERO)
				red_black_agents.agent_tracked.append(0.0)
				red_black_agents.agent_inv_mass.append(0.5)

func circle_position_exchange(red_black_agents: RedBlackAgents):
	red_black_agents.use_locomotion_targets = true
	
	red_black_agents.count = red_black_agents.agent_count
	var circle_radius: float = red_black_agents.parameters["circle_radius"]
	var circle_center: Vector2 = Vector2(circle_radius, circle_radius) + Vector2(256, 256)
	var angle_offset: float = 0.0
	
	for agent in red_black_agents.agent_count:
		var starting_position: Vector2 = Vector2(
			sin(angle_offset),
			cos(angle_offset)
		) * circle_radius + circle_center
		
		red_black_agents.agent_positions.append(starting_position)
		
		red_black_agents.locomotion_targets.append(Vector2(
			sin(angle_offset + PI),
			cos(angle_offset + PI)
		) * circle_radius + circle_center)
		
		#red_black_agents.locomotion_targets.append(starting_position + Vector2(20, 20))
		
		var starting_vel: Vector2 = Vector2(red_black_agents.max_velocity, 0)
		red_black_agents.agent_velocities.append(starting_vel)
		red_black_agents.agent_preferred_velocities.append(starting_vel)
		red_black_agents.delta_corrections.append(Vector4.ZERO)
		red_black_agents.agent_tracked.append(0.0)
		red_black_agents.agent_inv_mass.append(red_black_agents.rng.randf_range(0.2, 0.4)) # Unsure as of yet if this range is correct. 
		
		
		angle_offset += deg_to_rad(360.0 / red_black_agents.agent_count)

func generate_agents(red_black_agents: RedBlackAgents):
	red_black_agents.agent_positions.clear()
	red_black_agents.agent_velocities.clear()
	red_black_agents.agent_preferred_velocities.clear()
	red_black_agents.delta_corrections.clear()
	red_black_agents.agent_tracked.clear()
	red_black_agents.agent_inv_mass.clear()
	
	match red_black_agents.scenario:
		RedBlackAgents.Scenarios.DISTANCE_CONSTRAINT:
			distance_constraint(red_black_agents)
		RedBlackAgents.Scenarios.OPPOSING_AGENTS:
			opposing_agents(red_black_agents)
		RedBlackAgents.Scenarios.OPPOSING_SMALL_GROUPS:
			opposing_groups(red_black_agents, true)
		RedBlackAgents.Scenarios.OPPOSING_LARGE_GROUPS:
			opposing_groups(red_black_agents, false)
		RedBlackAgents.Scenarios.CIRCLE_POSITION_EXCHANGE:
			circle_position_exchange(red_black_agents)
