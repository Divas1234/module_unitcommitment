include("frequencyparameters_bindings/h_d_lowerupper_bindings/h_d_utils.jl")
include("frequencyparameters_bindings/h_d_visulazations/h_d_vismodule.jl")

# --- sudmodule Script Execution ---

function get_inertiatodamping_functions(droop_parameters)

	# converter_formming_configuations
	controller_config = converter_formming_configuations()

	flag_converter = Int64(0)

	converter_vsm_parameters = get(controller_config, "VSM", Dict())["control_parameters"]
	converter_droop_parameters = get(controller_config, "Droop", Dict())["control_parameters"]

	# Get parameters from boundary conditions
	initial_inertia, factorial_coefficient, time_constant, droop, ROCOF_threshold, NADIR_threshold, power_deviation = get_parmeters(flag_converter)

	droop = droop_parameters

	# Calculate inertia parameters

	inertia_updown_bindings, extreme_inertia, nadir_vector, inertia_vector, selected_ids = calculate_inertia_parameters(
		initial_inertia, factorial_coefficient, time_constant, droop, power_deviation,
		DAMPING_RANGE, converter_vsm_parameters, converter_droop_parameters,
		flag_converter)

	# Estimate inertia limits
	min_inertia, max_inertia = estimate_inertia_limits(ROCOF_threshold, power_deviation, DAMPING_RANGE, factorial_coefficient, time_constant, droop)

	min_damping, max_damping = 2.5, 12

	# NOTE type functions: c + b * damping a * damping^2
	fittingparameters = calculate_fittingparameters(extreme_inertia, DAMPING_RANGE)

	p1 = sub_data_visualization(DAMPING_RANGE, min_inertia, max_inertia, inertia_updown_bindings,
		extreme_inertia, nadir_vector, inertia_vector, selected_ids, min_damping, max_damping, droop, fittingparameters)

	# p1 = data_visualization(DAMPING_RANGE, inertia_updown_bindings, extreme_inertia,
	# 	nadir_vector, inertia_vector, selected_ids)

	vertexs = calculate_vertex(DAMPING_RANGE, inertia_updown_bindings, fittingparameters,
		min_inertia, max_inertia, min_damping, max_damping, droop)

	return p1, vertexs
end

function sub_data_visualization(damping, min_inertia, max_inertia, inertia_updown_bindings,
		extreme_inertia, nadir_vector, inertia_vector, selected_ids, min_damping, max_damping, droop, fittingparameters)

	# fittingparameters = calculate_fittingparameters(extreme_inertia, damping)

	fillarea = zeros(length(damping))
	for i in eachindex(damping)
		str = fittingparameters[1] .+ fittingparameters[2] .* damping[i] .+
			  fittingparameters[3] .* (damping[i] .^ 2)
		if str > min_inertia
			fillarea[i] = str
		else
			fillarea[i] = min_inertia
		end
	end

	@show seq = fittingparameters[1] .+ fittingparameters[2] .* damping .+
				fittingparameters[3] .* damping .^ 2 .- max_inertia

	# if seq[1] > 0
	# 	interaction_point = findfirst(x -> x < 0, seq)[1]
	# else
	# 	interaction_point = findfirst(x -> x > 0, seq)[1]
	# end

	sy1 = Plots.plot(damping, inertia_updown_bindings[:, 1]; framestyle = :box,
		ylims = (0, maximum(inertia_updown_bindings[:, 1])),
		xlabel = "damping / p.u.", ylabel = "max inertia / p.u.", lw = 3, label = "upper_bound_1")
	sy1 = Plots.plot!(damping, inertia_updown_bindings[:, 2]; lw = 3,
		label = "lower_bound_2", color = :forestgreen)

	# sy1 = Plots.plot!(damping, inertia_updown_bindings[:, 1], fillrange = fillarea,
	# fillalpha = 0.3, label = "", color = :skyblue)

	# sy1 = Plots.plot!(
	# 	damping[interaction_point:end], max_inertia[interaction_point:end],
	# 	fillrange = fillarea[interaction_point:end],
	# 	fillalpha = 0.5, label = "Interaction", color = :red)
	# sy1 = Plots.plot(damping, extreme_inertia, lw = 2, label = "extreme_inertia");
	# FIXME - add the following line to the plot, solved!
	# println("==================================================================================")
	# @show size(fittingparameters[1] * ones(length(damping)))
	# @show size(fittingparameters[2] .* damping)
	# @show size(fittingparameters[1] .+ fittingparameters[2] .* damping .+ fittingparameters[3] .* damping .^ 2)
	# println("==================================================================================")

	sy1 = Plots.plot!(damping,
		fittingparameters[1] .+ fittingparameters[2] .* damping .+ fittingparameters[3] .* damping .^ 2, ; lw = 3)
	sy1 = Plots.hline!([min_inertia]; lw = 3, label = "min_inertia")
	sy1 = Plots.plot!(damping, max_inertia; lw = 3, label = "max_inertia")

	# add additional information
	sy1 = Plots.vline!([12.0]; lw = 3, label = "damping_min_binding")
	sy1 = Plots.vline!([2.5]; lw = 3, label = "damping_max_binding")

	# vertexs = calculate_vertex(DAMPING_RANGE, inertia_updown_bindings, fittingparameters,
	# 	min_inertia, max_inertia, min_damping, max_damping, droop)

	return sy1
end

function calculate_vertex(DAMPING_RANGE, inertia_updown_bindings, fittingparameters,
		min_inertia, max_inertia, min_damping, max_damping, droop)

	# --- Input Validation ---
	if length(fittingparameters) < 3
		error("fittingparameters must have at least 3 elements")
	end
	if isempty(DAMPING_RANGE)
		error("DAMPING_RANGE cannot be empty")
	end

	# --- Helper Functions ---
	function find_damping_index(predicate, damping_range)
		index = findfirst(predicate, damping_range)
		if index === nothing
			error("No damping value found satisfying the condition.")
		end
		return index
	end

	function calculate_tem_sequence(fitting_params, damping_range)
		return fitting_params[1] .+ fitting_params[2] .* damping_range .+
			   fitting_params[3] .* damping_range .^ 2
	end

	function create_vertex(droop, damping, inertia)
		return (droop, damping, inertia)  # Using a tuple for immutability
	end

	# --- Main Logic ---

	# Find indices for max and min damping
	max_damping_index = find_damping_index(x -> x > max_damping, DAMPING_RANGE) - 1
	min_damping_index = find_damping_index(x -> x > min_damping, DAMPING_RANGE) - 1

	# Pre-calculate damping values to avoid repetition
	max_damping_value = DAMPING_RANGE[max_damping_index]
	min_damping_value = DAMPING_RANGE[min_damping_index]

	# Calculate vertices related to max and min damping
	vertex_max_damping_min_inertia = create_vertex(droop, max_damping_value, min_inertia)
	vertex_max_damping_max_inertia = create_vertex(droop, max_damping_value, max_inertia[max_damping_index])
	vertex_min_damping_max_inertia = create_vertex(droop, min_damping_value, max_inertia[min_damping_index])
	vertex_min_damping_min_inertia = create_vertex(droop, min_damping_value, min_inertia)

	# Calculate the temporary sequence
	tem_sequence = calculate_tem_sequence(fittingparameters, DAMPING_RANGE)
	vertex_min_damping_tem_sequence = create_vertex(droop, min_damping_value, tem_sequence[min_damping_index])

	# Determine the result based on vertex comparisons
	if vertex_min_damping_min_inertia > vertex_min_damping_tem_sequence
		# Initialize with known type and size
		res = Vector{typeof(vertex_min_damping_min_inertia)}(undef, 4)
		res[1] = vertex_max_damping_max_inertia
		res[2] = vertex_max_damping_min_inertia
		res[3] = vertex_min_damping_min_inertia
		res[4] = vertex_min_damping_max_inertia
		return res
	else
		min_inertia_index = findfirst(x -> x < min_inertia, tem_sequence)
		if min_inertia_index === nothing
			# Handle the case where no value in tem_sequence is less than min_inertia
			# Option 1: Throw an error
			# error("No value in tem_sequence is less than min_inertia")

			# Option 2: Use the last index as a fallback (adjust logic as needed)
			min_inertia_index = lastindex(tem_sequence)
		else
			min_inertia_index -= 1
		end

		vertex_min_inertia = create_vertex(droop, DAMPING_RANGE[min_inertia_index], min_inertia)

		if vertex_min_damping_max_inertia > vertex_min_damping_tem_sequence
			# Initialize with known type and size
			res = Vector{typeof(vertex_min_damping_min_inertia)}(undef, 5)
			res[1] = vertex_max_damping_max_inertia
			res[2] = vertex_max_damping_min_inertia
			res[3] = vertex_min_inertia
			res[4] = vertex_min_damping_tem_sequence
			res[5] = vertex_min_damping_max_inertia
			return res
		else
			max_inertia_diff_index = findfirst(x -> x < 0, tem_sequence - max_inertia)
			if max_inertia_diff_index === nothing
				# Handle case where no value is less than 0
				# Option 1: Throw an error
				# error("No value in tem_sequence - max_inertia is less than 0")

				# Option 2: Use the last index (adjust logic as needed)
				max_inertia_diff_index = lastindex(tem_sequence)
			else
				max_inertia_diff_index = max_inertia_diff_index[1] - 1
			end

			vertex_tem_sequence = create_vertex(droop, DAMPING_RANGE[max_inertia_diff_index],
				tem_sequence[max_inertia_diff_index])
			# Initialize with known type and size
			res = Vector{typeof(vertex_min_damping_min_inertia)}(undef, 4)
			res[1] = vertex_max_damping_max_inertia
			res[2] = vertex_max_damping_min_inertia
			res[3] = vertex_min_inertia
			res[4] = vertex_tem_sequence
			return res
		end
	end
end

"""
	vertices_to_matrix(vertices::AbstractVector)

Converts a vector of vertex matrices (or vectors of tuples) to a single matrix.

# Arguments
- `vertices::AbstractVector`: A vector where each element is a vector of tuples (or a matrix).

# Returns
- `Matrix{Float64}`: A matrix containing all the vertices.
  Returns an empty matrix if the input is empty.
  Returns `nothing` if the input has inconsistent data types or dimensions.
"""
function vertices_to_matrix(vertices::AbstractVector)
	# Handle the edge case of an empty vertices array.
	if isempty(vertices)
		@warn "Input 'vertices' is empty. Returning an empty matrix."
		return Matrix{Float64}(undef, 0, 3) # Return an empty matrix of the correct type
	end

	# Check if all elements are of the same type and have consistent dimensions
	first_element = first(vertices)
	if !(eltype(first_element) <: Tuple)
		@error "Input 'vertices' must contain vectors of tuples."
		return nothing
	end

	first_tuple_length = length(first(first_element))
	if !all(all(length(v) == first_tuple_length for v in sub_vertices)
	for sub_vertices in vertices)
		@error "Inconsistent tuple lengths in 'vertices'."
		return nothing
	end

	if first_tuple_length != 3
		@error "Tuples in 'vertices' must have length 3."
		return nothing
	end

	# Pre-allocate the matrix with the correct size and type.
	total_points = sum(length(v) for v in vertices)
	matrix = Matrix{Float64}(undef, total_points, 3)

	# Populate the matrix efficiently.
	current_row = 1
	for sub_vertices in vertices
		num_rows = length(sub_vertices)
		for (i, vertex) in enumerate(sub_vertices)
			matrix[current_row + i - 1, :] = collect(vertex)
		end
		current_row += num_rows
	end

	return matrix
end

"""
	write_vertices_to_file(all_vertices, base_path::String, rel_path::String)

Writes the `all_vertices` data to a text file.

# Arguments
- `all_vertices`: The data to write (expected to be a matrix-like structure).
- `base_path`: The base directory for the output file.
- `rel_path`: The relative path to the output file from the base directory.
"""
function write_vertices_to_file(all_vertices, base_path::String, rel_path::String)
	output_path = joinpath(base_path, rel_path)
	output_dir = dirname(output_path)

	# Create the output directory if it doesn't exist
	if !isdir(output_dir)
		mkpath(output_dir)
	end

	open(output_path, "w") do file
		for row in eachrow(all_vertices)
			# Ensure row has at least three elements
			if length(row) >= 3
				write(file, "$(row[1]) $(row[2]) $(row[3])\n")
			else
				@warn "Row does not contain at least three elements: $row"
			end
		end
	end
end
