using JuMP

export add_curtailment_constraints!, add_reserve_constraints!,
	   add_power_balance_constraints!, add_frequency_constraints!

# Helper function for curtailment limits
function add_curtailment_constraints!(scuc::Model, NT, ND, NW, NS, loads, winds)
	# Check if variables exist
	# !isdefined(scuc, :Δpd) &&
	# 	return println("\t constraints: 4) Curtailment skipped (Δpd not defined)")

	Δpd = scuc[:Δpd]
	Δpw = scuc[:Δpw]
	# wind_pmax = get(winds, :p_max, fill(Inf, NW)) # Default if missing
	# load_curve = get(loads, :load_curve, zeros(ND, NT)) # Default if missing

	wind_pmax = winds.p_max
	load_curve = loads.load_curve

	@constraint(scuc,
		[s = 1:NS, t = 1:NT],
		Δpw[(1 + (s - 1) * NW):(s * NW), t].<=
		winds.scenarios_curve[s, t] * wind_pmax[:, 1]) # Assuming scenarios_curve exists
	@constraint(scuc,
		[s = 1:NS, t = 1:NT],
		Δpd[(1 + (s - 1) * ND):(s * ND), t].<=load_curve[:, t])
	# Ensure non-negativity (already handled by variable definition >=0)
	println("\t constraints: 4) loadcurtailments and spoliedwinds\t\t\t done")
end

# Helper function for system reserve limits
function add_reserve_constraints!(scuc::Model, NT, NG, NC, NS, units, loads, winds, config_param)
	# Check if variables exist
	# !isdefined(scuc, :sr⁺) &&
	# 	return println("\t constraints: 6) Reserves skipped (sr⁺ not defined)")

	x = scuc[:x]
	sr⁺ = scuc[:sr⁺]
	sr⁻ = scuc[:sr⁻]
	pc⁺ = isdefined(scuc, :pc⁺) ? scuc[:pc⁺] : nothing # Storage might not exist
	pc⁻ = isdefined(scuc, :pc⁻) ? scuc[:pc⁻] : nothing # Storage might not exist

	# Use get for safety
	# wind_pmax = get(winds, :p_max, zeros(length(get(winds, :index, [])), 1)) # Default if missing
	# alpha_res = get(config_param, :is_Alpha, 0.0)
	# beta_res = get(config_param, :is_Belta, 0.0)
	# load_curve = get(loads, :load_curve, zeros(size(scuc[:Δpd],1) ÷ NS, NT)) # Infer ND if possible
	# unit_pmax = get(units, :p_max, ones(NG))

	wind_pmax = winds.p_max
	alpha_res = config_param.is_Alpha
	beta_res = config_param.is_Belta
	load_curve = loads.load_curve
	unit_pmax = units.p_max

	forcast_error = 0.05 # Consider making this a config_param
	forcast_reserve = winds.scenarios_curve * sum(wind_pmax[:, 1]) * forcast_error

	# Up-reserve constraint: Sum over all generators and storage discharge must meet a minimum requirement per running unit 'i'.
	@constraint(scuc,
		[s = 1:NS, t = 1:NT, i = 1:NG],
		# Sum generator reserve + storage discharge (if available)
		sum(sr⁺[(1 + (s - 1) * NG):(s * NG), t]) +
		(NC > 0 && pc⁻ !== nothing ? sum(pc⁻[(NC * (s - 1) + 1):(s * NC), t]) :
		 0.0)>=
		0.5 * unit_pmax[i, 1] * x[i, t]) # Original formulation used 0.5, keeping it

	# Down-reserve constraint
	@constraint(scuc,
		[s = 1:NS, t = 1:NT],
		# Sum generator reserve + storage charge (if available)
		sum(sr⁻[(1 + (s - 1) * NG):(s * NG), t]) +
		(NC > 0 && pc⁺ !== nothing ? sum(pc⁺[(NC * (s - 1) + 1):(s * NC), t]) :
		 0.0)>=
		1.0 * ( # Assuming 1.0 multiplier is intentional
			alpha_res * forcast_reserve[s, t] +
			beta_res * sum(load_curve[:, t])
		))
	println("\t constraints: 6) system reserves limits\t\t\t\t\t done")
end

# Helper function for power balance constraints
function add_power_balance_constraints!(
		scuc::Model, NT, NG, ND, NC, NW, NS, ND2, loads, winds, config_param) # Added ND2
	# Check if variables exist
	# !isdefined(scuc, :pg₀) &&
	# 	return println("\t constraints: 7) Power balance skipped (pg₀ not defined)")

	pg₀ = scuc[:pg₀]
	Δpd = scuc[:Δpd]
	Δpw = scuc[:Δpw]
	pc⁺ = isdefined(scuc, :pc⁺) ? scuc[:pc⁺] : nothing
	pc⁻ = isdefined(scuc, :pc⁻) ? scuc[:pc⁻] : nothing
	dc_p = isdefined(scuc, :dc_p) ? scuc[:dc_p] : nothing

	# wind_pmax = get(winds, :p_max, zeros(NW, 1))
	# load_curve = get(loads, :load_curve, zeros(ND, NT))

	wind_pmax = winds.p_max
	load_curve = loads.load_curve

	# Base power balance without data centers
	common_balance = @expression(scuc, [s = 1:NS, t = 1:NT],
		sum(pg₀[(1 + (s - 1) * NG):(s * NG), t])                                 # Generation
		+
		sum(winds.scenarios_curve[s, t] * wind_pmax[w, 1] - Δpw[(s - 1) * NW + w, t] for w in 1:NW) # Net Wind
		-
		sum(load_curve[d, t] - Δpd[(s - 1) * ND + d, t] for d in 1:ND)         # Net Load
		+
		(NC > 0 && pc⁻ !== nothing ? sum(pc⁻[((s - 1) * NC + 1):(s * NC), t]) :
		 0.0) # Storage Discharge
		-(NC > 0 && pc⁺ !== nothing ? sum(pc⁺[((s - 1) * NC + 1):(s * NC), t]) : 0.0))

	# if config_param.is_ConsiderDataCentra == 1 && ND2 > 0 && dc_p !== nothing
	# 	# Add data center load if considered
	# 	@constraint(scuc, [s = 1:NS, t = 1:NT],
	# 		common_balance[s, t] - sum(dc_p[((s - 1) * ND2 + 1):(s * ND2), t])==0)
	# else
	# 	# Constraint without data center load
	# 	@constraint(scuc, [s = 1:NS, t = 1:NT], common_balance[s, t]==0)
	# 	if config_param.is_ConsiderDataCentra == 1 && (ND2 == 0 || dc_p === nothing)
	# 		println("Warning: is_ConsiderDataCentra is true, but ND2 is 0 or dc_p missing. Data center load ignored.")
	# 	end
	# end
	println("\t constraints: 7) power balance constraints\t\t\t\t done")
end

# Helper function for frequency control constraints (Placeholder)
function add_frequency_constraints!(
		scuc::Model, NT, NG, NC, NS, units, stroges, config_param, Δp_contingency)
	# Requires full definition from original file for accuracy
	println("\t constraints: 13) frequency control constraints (placeholder - needs implementation)\t done")
	# --- Add actual frequency constraints here based on the original code ---
	# Example Placeholder:
	# if isdefined(scuc, :Δf_nadir) && isdefined(config_param, :is_f_nadir_min)
	#     f_nadir_min = config_param.is_f_nadir_min
	#     f_base = 50.0
	#     @constraint(scuc, [s=1:NS], scuc[:Δf_nadir][s] <= f_base - f_nadir_min)
	# end
	# --- End Placeholder ---
end
