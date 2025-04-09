function get_parmeters(flag_converter)

	f_base = 50.0

	if flag_converter == 0 # better performance for traditiaonal power grids
		initial_inertia = 8.0
		# OCGT parameter 0.35; CCGT parameter 0.15
		factorial_coefficient = 0.350
		time_content = 0.25
		droop = 1 / 0.030
		ROCOF_threshold = 0.5
		NADIR_threshold = 0.5
		delta_p = 3.50 # no more than 3.5(MW)  nuclear power plant
	else # better performance for modern power grids
		initial_inertia = 8.0
		factorial_coefficient = 0.350
		time_content = 0.25
		droop = 1 / 0.030
		ROCOF_threshold = 0.5
		NADIR_threshold = 0.5
		delta_p = 3.50 # no more than 3.5(MW)  nuclear power plant
	end
	@assert droop > factorial_coefficient
	# @assert inertia * 2 < (damping * factorial_coefficient) * time_content

	return initial_inertia,
	factorial_coefficient, time_content, droop, ROCOF_threshold, NADIR_threshold, delta_p
end

# test
# boundary conditons
# initial_inertia       = 1.56
# factorial_coefficient = 0.72
# time_content          = 8.0
# droop                 = 1 / 0.5
# ROCOF_threshold       = 0.5
# NADIR_threshold       = 0.5
# delta_p               = 0.5

# boundary conditons
# initial_inertia       = 4.5 / 2
# factorial_coefficient = 0.25
# time_content          = 8.0
# droop                 = 1 / 0.04
# ROCOF_threshold       = 0.5
# NADIR_threshold       = 0.5
# delta_p               = 2.50

# initial_inertia       = 4.5
# factorial_coefficient = 0.5
# time_content          = 1.250
# droop                 = 1 / 0.35
# ROCOF_threshold       = 0.5
# NADIR_threshold       = 0.5
# delta_p               = 1.0 / 2

# # better performance：recommanded
# initial_inertia = 8.0
# factorial_coefficient = 0.4
# time_content = 0.5 * 2
# droop = 1 / 0.050
# ROCOF_threshold = 0.5
# NADIR_threshold = 0.5
# delta_p = 2.0
