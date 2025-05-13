# Simulation Research

This repository contains various simulations using compute shaders in [Godot 4.4.1](https://godotengine.org/download/archive/4.4.1-stable/).

## Red-Black Agents

Simulations involving pathfinding and collision avoidance with agents represented as red and black dots. The logic for this simulation is split across the following files:

* red_black_agents.gd: Sets up the GPU pipelines, uniforms, and buffers to pass data on to the GPU. Also contains some parameters.
* red_black_agents.glsl: The GLSL script file which contains the compute shader itself, as well as some parameters which are only exposed on the GPU-side.
* agent_shared_data.glsl: Another GLSL script file which contains the actual buffers. This is included within the previous file, so this file is not and does not need to be compile-able on its own.

Within Godot itself, more in-depth documentation for the .gd file can be viewed by using the "Search Help" shortcut (F1) and then searching "RedBlackAgents," which goes into more detail about the script's functionality.
