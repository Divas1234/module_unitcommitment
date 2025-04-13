include("_automatic_workflow.jl")

# Define droop parameters. Consider moving this to a separate configuration file or a dedicated section.
const DROOP_PARAMETERS = collect(range(33, 40; length = 20))

"""
	plot_inertia_damping(droop_parameters::AbstractVector)

Generates and plots the inertia-damping functions for a given set of droop parameters.

# Arguments
- `droop_parameters::AbstractVector`: A vector of droop parameters.

# Returns
- `Tuple{Plots.Plot, Vector{Vector{Tuple{Float64, Float64, Float64}}}}`: A tuple containing the plot and a vector of vertices.
  Returns `(nothing, nothing)` if `droop_parameters` is empty or if no valid plots are generated.
"""
function plot_inertia_damping(droop_parameters::AbstractVector)
	if isempty(droop_parameters)
		@warn "droop_parameters is empty. No plot will be generated."
		return nothing, nothing  # Return nothing for both plot and vertices
	end
	return _plot_inertia_damping(droop_parameters) # Internal plotting function
end

"""
	_plot_inertia_damping(droop_parameters::AbstractVector)

Internal function to generate and plot the inertia-damping functions.
"""
function _plot_inertia_damping(droop_parameters::AbstractVector)
	plots = []
	labels = []
	all_vertices = []

	for param in droop_parameters
		try
			p, sub_vertices = get_inertiatodamping_functions(param)
			if isnothing(p) || isnothing(sub_vertices) || isempty(sub_vertices)
				@warn "get_inertiatodamping_functions returned invalid data for parameter $param. Skipping this parameter."
				continue
			end
			push!(plots, p)
			push!(labels, "Droop 1/$(round(1 / param, digits=3))") # More descriptive label
			push!(all_vertices, sub_vertices)

		catch e
			@warn "Error processing parameter $param: $e"
			# Handle the error as needed, e.g., log it, skip the parameter, or rethrow it.
			continue # Skip to the next droop parameter
		end
	end

	if isempty(plots)
		@warn "No valid plots were generated."
		return nothing, nothing # Return nothing if no plots were created
	end

	p1 = Plots.plot(plots...;
		legend = false, size = (1000, 1000),
		xlabel = "Damping", ylabel = "Inertia",
		label = permutedims(labels)) # Correct label orientation

	vertices_matrix = vertices_to_matrix(all_vertices::AbstractVector)

	return p1, vertices_matrix
end

# Call plotting function.
plot_result, all_vertices = plot_inertia_damping(DROOP_PARAMETERS)

if !isnothing(plot_result)
	display(plot_result) # Or save to file: Plots.savefig(p1, "inertia_damping_plot.png")
end

# Display the result.

# if !isnothing(all_vertices)
# 	@show all_vertices
# 	write_vertices_to_file(all_vertices, pwd(), OUTPUT_REL_PATH)
# end

# Display the result.
if !isnothing(all_vertices)
	@show all_vertices
	if !isdir("res")
		mkdir("res")
	end
	current_file_path = joinpath(pwd(), "res")
	input_file_address, output_file_address = current_file_path, current_file_path
	write_vertices_to_file(all_vertices, pwd(), OUTPUT_REL_PATH)
	plot_polygon_figures(input_file_address, output_file_address) # Draw the mesh
	# draw_geometry(OUTPUT_REL_PATH) # Draw the mesh
end
