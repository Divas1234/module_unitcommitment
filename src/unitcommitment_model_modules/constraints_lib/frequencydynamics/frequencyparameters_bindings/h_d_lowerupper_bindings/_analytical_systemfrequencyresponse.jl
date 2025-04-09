using DataFrames

# function inertia_damping_fittingfunction(
# 		damping, factorial_coefficient, time_content, droop)
# 	# fit the a, and b using GLM
# 	inertia = generate_extreme_inertia(
# 		factorial_coefficient, time_content, droop, delta_p, damping)

# end

# Function to generate extreme inertia values based on given parameters
function generate_extreme_inertia(
		initial_inertia, factorial_coefficient, time_content, droop,
		delta_p, damping, inertia_updown_bindings,
		converter_vsm_parameters,
		converter_droop_parameters,
		flag_converter::Int64)
	ll = 25

	nadir_vector, inertia_vector, extreme_inertia, selected_ids = zeros(
		length(damping), ll),
	zeros(length(damping), ll), zeros(length(damping), 1), zeros(length(damping), 1)

	if flag_converter == 0
		frequency_nadir_threshold = 0.25 # for traditiaonal power grids
	else
		frequency_nadir_threshold = 0.1750 # for modern power grids
	end

	@show (damping[1] + factorial_coefficient) * time_content / 2

	for i in eachindex(damping)
		candidate_inertia = collect(range(start = inertia_updown_bindings[i, 2],
			stop = inertia_updown_bindings[i, 1], length = ll + 10))

		candidate_inertia = candidate_inertia[5:(end - 6)]
		inertia_vector[i, :] = candidate_inertia
		# nadir_vector = zeros(length(candidate_inertia))

		for tem_inertia in eachindex(candidate_inertia)
			# println([i tem_inertia])
			tem_nadir = calculate_frequencynadir(
				candidate_inertia[tem_inertia], factorial_coefficient, time_content,
				droop, delta_p, damping[i],
				converter_vsm_parameters, converter_droop_parameters, flag_converter::Int64)
			nadir_vector[i, tem_inertia] = tem_nadir
			# if tem_nadir > frequency_nadir_threshold
			# 	extreme_inertia[i] = candidate_inertia[tem_inertia]
			# 	break
			# end
		end

		# # println(nadir_vector)

		id = findfirst(x -> x < frequency_nadir_threshold, nadir_vector[i, :])
		# # @show id
		if id !== nothing
			extreme_inertia[i] = candidate_inertia[id]
			selected_ids[i] = id
		else
			# println("the seting of damping and inertia parameters is not correct")
			error("The setting of damping and inertia parameters is not correct")
		end
	end

	return extreme_inertia, nadir_vector, inertia_vector, selected_ids
end

# Function to calculate the frequency nadir
function calculate_frequencynadir(
		inertia, factorial_coefficient, time_content, droop, delta_p, damping,
		converter_vsm_parameters, converter_droop_parameters, flag_converter::Int64)

	# Define the parameters
	# inertia = 0.1:0.1:5
	# factorial_coefficient = 0.1:0.1:5
	# time_content = 0.1:0.1:5
	# droop = 0.1:0.1:5
	# Check for invalid inputs
	if inertia <= 0 || time_content <= 0 || damping < 0 || droop < 0 ||
	   factorial_coefficient < 0 || delta_p < 0
		return NaN # Or throw an error
	end

	if flag_converter == 0
		ζ = (2 * inertia + time_content * (damping + factorial_coefficient)) /
			(2 * sqrt(2 * inertia * time_content * (damping + droop)))

		# Check for NaN or Inf
		if isnan(ζ) || isinf(ζ)
			return NaN
		end

		ωₙ = sqrt((damping + droop) / (2 * inertia * time_content))

		# Check for NaN or Inf
		if isnan(ωₙ) || isinf(ωₙ)
			return NaN
		end

		# @assert inertia * 2 < (damping * factorial_coefficient) * time_content
		@assert droop > factorial_coefficient

		ωₜ = ωₙ * sqrt(1 - ζ^2)

		k = 0 # default the value of k to 1
		# time to frequency nadir
		t = 1 / ωₜ * atan(ωₜ / (ζ * ωₙ - time_content^(-1))) + (k * 2 * π / ωₜ)

		res = delta_p / (damping + droop) *
			  (1 +
			   (-1)^(k) *
			   sqrt(time_content * (droop - factorial_coefficient) / (2 * inertia)) *
			   exp(-1 * ζ * ωₙ * t))

	else
		combinded_inertia = (inertia + converter_vsm_parameters["inertia"])
		combinded_damping = (damping + converter_vsm_parameters["damping"] +
							 1 / converter_droop_parameters["droop"])
		ζ = (2 * (combinded_inertia) +
			 time_content * (combinded_damping +
							 factorial_coefficient)) /
			(2 * sqrt(2 * combinded_inertia * time_content * (combinded_damping + droop)))

		# Check for NaN or Inf
		if isnan(ζ) || isinf(ζ)
			return NaN
		end

		ωₙ = sqrt((combinded_damping + droop) / (2 * combinded_inertia * time_content))

		# Check for NaN or Inf
		if isnan(ωₙ) || isinf(ωₙ)
			return NaN
		end

		# @assert inertia * 2 < (damping * factorial_coefficient) * time_content
		@assert droop > factorial_coefficient

		ωₜ = ωₙ * sqrt(1 - ζ^2)

		k = 0 # default the value of k to 1
		# time to frequency nadir
		t = 1 / ωₜ * atan(ωₜ / (ζ * ωₙ - time_content^(-1))) + (k * 2 * π / ωₜ)

		res = delta_p / (combinded_damping + droop) *
			  (1 +
			   (-1)^(k) *
			   sqrt(time_content * (droop - factorial_coefficient) /
					(2 * combinded_inertia)) *
			   exp(-1 * ζ * ωₙ * t))
	end
	return res
end
