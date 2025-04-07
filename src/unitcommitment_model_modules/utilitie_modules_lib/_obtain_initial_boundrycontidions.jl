function calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)
	Gsdf = nothing # Initialize Gsdf
	if config_param.is_NetWorkCon == 1
		if NL > 0 # Ensure lines exist before calculating power flow
			Adjacmatrix_BtoG, Adjacmatrix_B2D, Gsdf = linearpowerflow(
				units, lines, loads, NG, NB, ND, NL)
		else
			println("Warning: Network constraints enabled (is_NetWorkCon=1), but NL=0. Skipping Gsdf calculation.")
		end
	end
	return Gsdf
end

function calculate_initial_unit_status(units, NG)
	onoffinit = zeros(NG, 1)
	if !isempty(units.x_0) && size(units.x_0, 1) == NG
		for i in 1:NG
			onoffinit[i] = ((units.x_0[i, 1] > 0.5) ? 1 : 0)
		end
	else
		println("Warning: Initial unit status units.x_0 not found or invalid. Assuming all units start offline (onoffinit=0).")
	end
	return onoffinit
end

function define_contingency_size(units, NG)
	Δp_contingency = (NG > 0) ? maximum(units.p_max[:, 1]) * 0.3 : 0.0 # Example: 30% of largest unit, handle NG=0
	return Δp_contingency
end
