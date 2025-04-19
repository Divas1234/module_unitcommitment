using JuMP

export add_curtailment_constraints!, add_reserve_constraints!,
	add_power_balance_constraints!, add_frequency_constraints!

# Helper function for curtailment limits
function add_curtailment_constraints!(scuc::Model, NT, ND, NW, NS, loads, winds)
	# Check if variables exist
	if isempty(scuc[:Δpd])
		return println("\t constraints: 4) Curtailment skipped (Δpd not defined)")
	end

	Δpd = scuc[:Δpd]
	Δpw = scuc[:Δpw]

	wind_pmax = winds.p_max
	load_curve = loads.load_curve

	winds_curt_constr = @constraint(scuc,
		winds_curt_constr_for_eachscenario[s = 1:NS, t = 1:NT],
		Δpw[(1 + (s - 1) * NW):(s * NW), t] .<=
			winds.scenarios_curve[s, t] * wind_pmax[:, 1])
	loads_curt_const = @constraint(scuc,
		[s = 1:NS, t = 1:NT],
		Δpd[(1 + (s - 1) * ND):(s * ND), t] .<= load_curve[:, t])
	println("\t constraints: 4) loadcurtailments and spoliedwinds\t\t\t done")
	return scuc, winds_curt_constr, loads_curt_const
end

# Helper function for system reserve limits
function add_reserve_constraints!(scuc::Model, NT, NG, NC, NS, units, loads, winds, config_param)
	# Check if variables exist
	if isempty(scuc[:sr⁺])
		return println("\t constraints: 6) Reserves skipped (sr⁺ not defined)")
	end

	x = scuc[:x]
	sr⁺ = scuc[:sr⁺]
	sr⁻ = scuc[:sr⁻]
	pc⁺ = check_var_exists(scuc, "pc⁺") ? scuc[:pc⁺] : nothing # Storage might not exist
	pc⁻ = check_var_exists(scuc, "pc⁻") ? scuc[:pc⁻] : nothing # Storage might not exist

	wind_pmax = winds.p_max
	alpha_res = config_param.is_Alpha
	beta_res = config_param.is_Belta
	load_curve = loads.load_curve
	unit_pmax = units.p_max

	forcast_error = 0.05 # Consider making this a config_param
	forcast_reserve = winds.scenarios_curve * sum(wind_pmax[:, 1]) * forcast_error

	# Up-reserve constraint: Sum over all generators and storage discharge must meet a minimum requirement per running unit 'i'.
	# Sum generator reserve + storage discharge (if available)
	sys_upreserve_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT, i = 1:NG],
		sum(sr⁺[(1 + (s - 1) * NG):(s * NG), t]) +
		(NC > 0 && pc⁻ !== nothing ? sum(pc⁻[(NC * (s - 1) + 1):(s * NC), t]) : 0.0) >=
			0.5 * unit_pmax[i, 1] * x[i, t]) # Original formulation used 0.5, keeping it

	# Down-reserve constraint
	# Assuming 1.0 multiplier is intentional
	# Sum generator reserve + storage charge (if available)
	sys_down_reserve_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT],
		sum(sr⁻[(1 + (s - 1) * NG):(s * NG), t]) +
		(NC > 0 && pc⁺ !== nothing ? sum(pc⁺[(NC * (s - 1) + 1):(s * NC), t]) :
		 0.0) >=
			1.0 * (alpha_res * forcast_reserve[s, t] + beta_res * sum(load_curve[:, t])))
	println("\t constraints: 6) system reserves limits\t\t\t\t\t done")
	return scuc, sys_upreserve_constr, sys_down_reserve_constr
end

# Helper function for power balance constraints
function add_power_balance_constraints!(scuc::Model, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2 = nothing) # Added ND2
	# Check if variables exist
	if isempty(scuc[:pg₀])
		return println("\t constraints: 7) Power balance skipped (pg₀ not defined)")
	end

	pg₀ = scuc[:pg₀]
	Δpd = scuc[:Δpd]
	Δpw = scuc[:Δpw]
	pc⁺ = check_var_exists(scuc, "pc⁺") ? scuc[:pc⁺] : nothing # Storage might not exist
	pc⁻ = check_var_exists(scuc, "pc⁻") ? scuc[:pc⁻] : nothing # Storage might not exist
	# pc⁺ = scuc[:pc⁺]
	# pc⁻ = scuc[:pc⁻]

	wind_pmax = winds.p_max
	load_curve = loads.load_curve

	# Base power balance without data centers
	if config_param.is_ConsiderBESS == 0
		common_balance = @expression(scuc, [s = 1:NS, t = 1:NT],
			sum(pg₀[(1 + (s - 1) * NG):(s * NG), t]) +
			sum(winds.scenarios_curve[s, t] * wind_pmax[w, 1] - Δpw[(s - 1) * NW + w, t]
				for w in 1:NW) -
				sum(load_curve[d, t] - Δpd[(s - 1) * ND + d, t] for d in 1:ND)) # Net Load
	else
		common_balance = @expression(scuc, [s = 1:NS, t = 1:NT],
			sum(pg₀[(1 + (s - 1) * NG):(s * NG), t]) +
			sum(winds.scenarios_curve[s, t] * wind_pmax[w, 1] - Δpw[(s - 1) * NW + w, t] for w in 1:NW) -
			sum(load_curve[d, t] - Δpd[(s - 1) * ND + d, t] for d in 1:ND) +
			(NC > 0 && pc⁻ !== nothing ? sum(pc⁻[((s - 1) * NC + 1):(s * NC), t]) :
			 0.0) -
				(NC > 0 && pc⁺ !== nothing ? sum(pc⁺[((s - 1) * NC + 1):(s * NC), t]) : 0.0))
	end

	sys_balance_constr = []
	if config_param.is_ConsiderDataCentra == 1 && ND2 > 0 && !isempty(scuc[:dc_p])
		dc_p = scuc[:dc_p]
		# Add data center load if considered
		push!(sys_balance_constr, @constraint(scuc, [s = 1:NS, t = 1:NT], common_balance[s, t] - sum(dc_p[((s - 1) * ND2 + 1):(s * ND2), t]) == 0))
	else
		# Constraint without data center load
		push!(sys_balance_constr, @constraint(scuc, [s = 1:NS, t = 1:NT], common_balance[s, t] == 0))
		if config_param.is_ConsiderDataCentra == 1 && (ND2 == 0 || dc_p === nothing)
			println("Warning: is_ConsiderDataCentra is true, but ND2 is 0 or dc_p missing. Data center load ignored.")
		end
	end
	println("\t constraints: 7) power balance constraints\t\t\t\t done")
	return scuc, sys_balance_constr
end

function check_var_exists(model::Model, name::String)
	return any(v -> v == name, all_variables(model))
end
