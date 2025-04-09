# # FR stage
# """
#     inertia_bindings(damping::Vector{Float64}, factorial_coefficient::Float64, time_content::Float64, droop::Float64) -> Matrix{Float64}

# Calculate the upper and lower inertia bounds for a given set of damping values, factorial coefficient, time content, and droop.

# # Arguments
# - `damping::Vector{Float64}`: A vector of damping values.
# - `factorial_coefficient::Float64`: The factorial coefficient.
# - `time_content::Float64`: The time content value.
# - `droop::Float64`: The droop value.

# # Returns
# - `Matrix{Float64}`: A matrix with two columns containing the upper and lower bounds for each damping value.
# """
function inertia_bindings(damping, factorial_coefficient, time_content, droop, converter_vsm_parameters,
						  converter_droop_parameters,
						  flag)
	tem = zeros(length(damping), 2)
	for i in eachindex(damping)
		upper_bound_1, lower_bound_1 = inertia_damping_relations(damping[i], factorial_coefficient, time_content, droop,
																 converter_vsm_parameters, converter_droop_parameters, flag)
		tem[i, 1] = upper_bound_1
		tem[i, 2] = lower_bound_1
	end
	@assert tem[:, 1] > tem[:, 2]
	return tem
end

# """
#     inertia_damping_relations(damping::Float64, factorial_coefficient::Float64, time_content::Float64, droop::Float64) -> Tuple{Float64, Float64}

# Calculate the upper and lower bounds for inertia given damping, factorial coefficient, time content, and droop.

# # Arguments
# - `damping::Float64`: The damping value.
# - `factorial_coefficient::Float64`: The factorial coefficient.
# - `time_content::Float64`: The time content value.
# - `droop::Float64`: The droop value.

# # Returns
# - `Tuple{Float64, Float64}`: A tuple containing the upper and lower bounds.
# """
function inertia_damping_relations(damping::Float64, factorial_coefficient::Float64,
								   time_content::Float64, droop::Float64, converter_vsm_parameters,
								   converter_droop_parameters,
								   flag::Int64)
	if flag == 0
		tem1 = (damping - factorial_coefficient + 2 * droop)
		tem2 = tem1^2 - (damping + factorial_coefficient)^2
		# @show tem1 = (damping - factorial_coefficient + 2 * droop)
		# @show tem2 = tem1^2 - (damping + factorial_coefficient)^2
	else
		tem1 = (damping + converter_vsm_parameters["damping"] +
				1 / converter_droop_parameters["droop"] - factorial_coefficient + 2 * droop)
		tem2 = tem1^2 -
			   (damping + converter_vsm_parameters["damping"] +
				1 / converter_droop_parameters["droop"]
				+ factorial_coefficient)^2
	end

	@assert tem2 >= 0
	@assert droop > factorial_coefficient

	lower_bound_1 = time_content * (tem1 - sqrt(tem2)) / 2
	upper_bound_1 = time_content * (tem1 + sqrt(tem2)) / 2

	# println("damping = ", damping, ", factorial_coefficient = ", factorial_coefficient, ", droop = ", droop)
	# println("tem1 = ", tem1, ", tem2 = ", tem2)
	# println("upper_bound_1 = ", upper_bound_1, ", lower_bound_1 = ", lower_bound_1)

	return upper_bound_1, lower_bound_1
end

"""
	calculate_inertia_parameters(initial_inertia, factorial_coefficient, time_constant, droop, power_deviation, damping_range,converter_vsm_parameters,
		converter_droop_parameters,
		flag_converter)

Calculate key inertia parameters based on input conditions.

# Arguments
- `initial_inertia`: Initial inertia value.
- `factorial_coefficient`: Factorial coefficient.
- `time_constant`: Time constant.
- `droop`: Droop characteristic.
- `power_deviation`: Deviation in power.
- `damping_range`: Range of damping values.

# Returns
- A tuple containing:
	- `inertia_updown_bindings`: Inertia bindings (view).
	- `extreme_inertia`: Extreme inertia values.
	- `nadir_vector`: Vector of frequency nadir values.
	- `inertia_vector`: Vector of inertia values.
	- `selected_ids`: Selected indices.
"""
function calculate_inertia_parameters(initial_inertia::Float64,
									  factorial_coefficient::Float64,
									  time_constant::Float64,
									  droop::Float64,
									  power_deviation::Float64,
									  damping_range,
									  converter_vsm_parameters,
									  converter_droop_parameters,
									  flag_converter::Int64)
	# Validate inputs (basic checks)
	@assert initial_inertia >= 0.0 "Initial inertia must be non-negative."
	@assert time_constant > 0.0 "Time constant must be positive."
	@assert all(damping_range .>= 0.0) "Damping values must be non-negative."

	# zeta smaller than 1
	inertia_updown_bindings = view(inertia_bindings(damping_range, factorial_coefficient,
													time_constant, droop,
													converter_vsm_parameters,
													converter_droop_parameters,
													flag_converter), :, 1:2)
	@assert all(inertia_updown_bindings[:, 1] .> inertia_updown_bindings[:, 2]) "Inertia up-bindings must be greater than down-bindings."

	extreme_inertia, nadir_vector, inertia_vector, selected_ids = generate_extreme_inertia(initial_inertia, factorial_coefficient, time_constant, droop,
																						   power_deviation, damping_range, inertia_updown_bindings,
																						   converter_vsm_parameters, converter_droop_parameters, flag_converter::Int64)

	# Further validation (example - check dimensions)
	# @assert length(nadir_vector) == length(damping_range) "Nadir vector length should match damping range."

	return inertia_updown_bindings, extreme_inertia, nadir_vector, inertia_vector,
		   selected_ids
end

"""
	estimate_inertia_limits(ROCOF_threshold, power_deviation, damping_range, factorial_coefficient, time_constant, droopg'g

Estimate minimum and maximum inertia based on ROCOF threshold.

# Arguments
- `ROCOF_threshold`: Rate of change of frequency threshold.
- `power_deviation`: Deviation in power.
- `damping_range`: Range of damping values.
- `factorial_coefficient`: Factorial coefficient.
- `time_constant`: Time constant.
- `droop`: Droop characteristic.

# Returns
- A tuple containing:
	- `min_inertia`: Estimated minimum inertia.
	- `max_inertia`: Estimated maximum inertia.
"""
function estimate_inertia_limits(ROCOF_threshold::Float64,
								 power_deviation::Float64,
								 damping_range,
								 factorial_coefficient::Float64,
								 time_constant::Float64,
								 droop::Float64)
	# inertia_response,time-to-frequency nadir larger than zeros
	min_inertia, max_inertia = min_inertia_estimation(ROCOF_threshold, power_deviation, damping_range, factorial_coefficient, time_constant, droop)
	return min_inertia, max_inertia
end
