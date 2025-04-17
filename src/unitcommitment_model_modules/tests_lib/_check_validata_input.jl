"""
	validate_inputs(units, loads, winds, lines, DataCentras, config_param)

Validates the input data for the SUC model.

# Arguments
- `units::unit`: Generator unit data
- `loads::load`: Load data
- `winds::wind`: Wind generation data
- `lines::transmissionline`: Transmission line data
- `DataCentras::data_centra`: Data center data
- `config_param::config`: Configuration parameters

# Returns
- `Bool`: True if all checks pass, false otherwise.
"""
function validate_inputs(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines,
		DataCentras, config_param, stroges, scenarios_prob, NL)
	# Check if the number of generators matches the expected value
	if size(units.p_max, 1) != NG
		@warn "Number of generators in `units` ($(size(units.p_max, 1))) does not match NG ($NG). This might lead to errors."
		return false
	end

	if size(loads.index, 1) != ND
		@warn "Number of loads in `loads` ($(size(loads.p_load, 1))) does not match ND ($ND). This might lead to errors."
		return false
	end

	if size(winds.index, 1) != NW
		@warn "Number of wind scenarios in `winds` ($(size(winds.p_wind, 1))) does not match NW ($NW). This might lead to errors."
		return false
	end

	if NL > 0 && size(lines.index, 1) != NL
		@warn "Number of transmission lines in `lines` ($(size(lines.rateA, 1))) does not match NL ($NL). This might lead to errors."
		return false
	end

	# Implement other input validation logic here

	# Return true if all checks pass, false otherwise
	return true
end

