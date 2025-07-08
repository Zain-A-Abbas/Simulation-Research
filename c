[1mdiff --git a/Preliminary Simulation/agent_generator.gd b/Preliminary Simulation/agent_generator.gd[m
[1mindex 00cbcc7..61c84a0 100644[m
[1m--- a/Preliminary Simulation/agent_generator.gd[m	
[1m+++ b/Preliminary Simulation/agent_generator.gd[m	
[36m@@ -23,7 +23,7 @@[m [mfunc opposing_agents(red_black_agents: RedBlackAgents):[m
 	red_black_agents.count = red_black_agents.agent_count[m
 	red_black_agents.agent_positions.append_array([[m
 		Vector2(200, 200),[m
[31m-		Vector2(500, 200)[m
[32m+[m		[32mVector2(350, 200)[m
 		])[m
 	red_black_agents.agent_velocities.append_array([[m
 		Vector2(20, 0),[m
