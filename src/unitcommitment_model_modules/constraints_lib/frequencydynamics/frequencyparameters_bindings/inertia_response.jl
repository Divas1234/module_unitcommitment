"""
	min_inertia_estimation(ROCOF_threshold, delta_p, damping, factorial_coefficient, time_content, droop)

Estimate the minimum inertia based on given parameters.

# Arguments
- `ROCOF_threshold`: Rate of change of frequency threshold.
- `delta_p`: Change in power.
- `damping`: Damping coefficient array.
- `factorial_coefficient`: Factorial coefficient.
- `time_content`: Time content.
- `droop`: Droop characteristic.

# Returns
- `lower_bound`: Lower bound of inertia estimation.
- `upper_bound`: Upper bound of inertia estimation.
"""
function min_inertia_estimation(
		ROCOF_threshold,
		delta_p,
		damping,
		factorial_coefficient,
		time_content,
		droop
)

	# Input validation
	if ROCOF_threshold == 0
		error("ROCOF_threshold cannot be zero.")
	end
	if isempty(damping)
		error("Damping array cannot be empty.")
	end

	# Lower bound calculation
	lower_bound = 0.5 * (delta_p * PERCENTAGE_BASE) / (ROCOF_threshold * FREQUENCY_BASE)
	# lower_bound = 0.5 * (delta_p * 1) / (ROCOF_threshold * 1)  # Commented-out alternative calculation

	# Upper bound calculation (vectorized)
	damping_length = length(damping)
	upper_bound = zeros(damping_length, 1)

	# Upper bound vectorized calculation
	upper_bound .= (PERCENTAGE_BASE / FREQUENCY_BASE) *
				   (droop .+ damping .+ factorial_coefficient) .* (time_content / 2)

	return lower_bound, upper_bound
end
