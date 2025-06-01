using JuMP

export add_unit_operation_constraints!, add_generator_power_constraints!,
	   add_ramp_constraints!, add_pwl_constraints!

function estimate_initial_status(units, NG, NT, onoffinit, units_initial_startup_time, units_initial_shutdown_time = zeros(NG, 1))

	# onoffinit = zeros(NG, 1)
	Lupmin = zeros(NG, 1)     # Minimum startup time
	Ldownmin = zeros(NG, 1)   # Minimum shutdown time

	for i in 1:NG
		# Calculate minimum up/down time limits
		Lupmin[i] = min(NT, Int64(units.min_shutup_time[i, 1] - units_initial_startup_time[i, 1] + 1) * onoffinit[i])
		Ldownmin[i] = min(NT, Int64(units.min_shutdown_time[i, 1] - units_initial_shutdown_time[i, 1] + 1) * (1 - onoffinit[i]))
	end
	return Lupmin, Ldownmin
end

# Helper function for unit operational constraints (min up/down, binary logic, costs)
function add_unit_operation_constraints!(scuc::Model, NT, NG, units, onoffinit)
	x = scuc[:x]
	u = scuc[:u]
	v = scuc[:v]
	su₀ = scuc[:su₀]
	sd₀ = scuc[:sd₀]

	units_initial_startup_time = units.t_0
	units_initial_shutdown_time = units.t_1
	Lupmin, Ldownmin = estimate_initial_status(units, NG, NT, onoffinit, units_initial_startup_time, units_initial_shutdown_time)

	units_minuptime_constr = Vector{ConType}()
	units_mindowntime_constr = Vector{ConType}()

	# Min up/down time
	for i in 1:NG
		for t in Int64(max(1, Lupmin[i])):NT
			# base_name_con₁ = "units_min_up_time" * "_" * string(i) * "_" * string(t)
			LB = Int64(max(t - units.min_shutup_time[i, 1] + 1, 1))
			con = @constraint(scuc, sum(u[i, r] for r in LB:t) <= x[i, t])
			# push!(units_minuptime_constr, con)
			push!(units_minuptime_constr, con)
		end

		for t in Int64(max(1, Ldownmin[i])):NT
			# base_name_con₂ = "units_min_down_time" * "_" * string(i) * "_" * string(t)
			LB = Int64(max(t - units.min_shutup_time[i, 1] + 1, 1))
			con = @constraint(scuc, sum(v[i, r] for r in LB:t) <= (1 - x[i, t]))
			# push!(units_mindowntime_constr, con)
			push!(units_mindowntime_constr, con)
		end
	end

	println("\t constraints: 1) minimum shutup/shutdown time limits\t\t\t done")

	# Binary variable logic
	units_init_stateslogic_consist_constr = @constraint(scuc,
		[i = 1:NG, t = 1:NT],
		u[i, t] - v[i, t] == x[i, t] - ((t == 1) ? onoffinit[i] : x[i, t - 1]))
	units_states_consist_constr = @constraint(scuc, [i = 1:NG, t = 1:NT], u[i, t] + v[i, t] <= 1)

	println("\t constraints: 2) binary variable logic\t\t\t\t\t done")

	# Startup/shutdown cost
	shutupcost = units.coffi_cold_shutup_1
	shutdowncost = units.coffi_cold_shutdown_1
	units_init_shutup_cost_constr = @constraint(scuc, su₀[:, 1] .>= shutupcost .* (x[:, 1] - onoffinit[:, 1]))
	units_init_shutdown_cost_costr = @constraint(scuc, sd₀[:, 1] .>= shutdowncost .* (onoffinit[:, 1] - x[:, 1]))
	units_shutup_cost_constr = @constraint(scuc, [t = 2:NT], su₀[:, t] .>= shutupcost .* u[:, t])
	units_shutdown_cost_constr = @constraint(scuc, [t = 2:NT], sd₀[:, t] .>= shutdowncost .* v[:, t])

	println("\t constraints: 3) shutup/shutdown cost\t\t\t\t\t done")
	return scuc, units_minuptime_constr,
	units_mindowntime_constr, units_init_stateslogic_consist_constr, units_states_consist_constr, units_init_shutup_cost_constr,
	units_init_shutdown_cost_costr, units_shutup_cost_constr,
	units_shutdown_cost_constr
end

# Helper function for generator power limits
function add_generator_power_constraints!(scuc::Model, NT, NG, NS, units)
	x = scuc[:x]
	pg₀ = scuc[:pg₀]
	sr⁺ = scuc[:sr⁺]
	sr⁻ = scuc[:sr⁻]

	units_minpower_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT],
		pg₀[(1 + (s - 1) * NG):(s * NG), t] +
		sr⁺[(1 + (s - 1) * NG):(s * NG), t] .<=
		units.p_max[:, 1] .* x[:, t])
	units_maxpower_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT],
		pg₀[(1 + (s - 1) * NG):(s * NG), t] -
		sr⁻[(1 + (s - 1) * NG):(s * NG), t] .>=
		units.p_min[:, 1] .* x[:, t])
	println("\t constraints: 5) generatos power limits\t\t\t\t\t done")
	return scuc, units_minpower_constr, units_maxpower_constr
end

# Helper function for ramp rate constraints
function add_ramp_constraints!(scuc::Model, NT, NG, NS, units, onoffinit)
	x = scuc[:x]
	u = scuc[:u]
	v = scuc[:v]
	pg₀ = scuc[:pg₀]

	p_0 = units.p_0
	ramp_up = units.ramp_up
	ramp_down = units.ramp_down
	shut_up = units.shut_up
	shut_down = units.shut_down
	p_max = units.p_max
	p_min = units.p_min

	units_upramp_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT],
		pg₀[(1 + (s - 1) * NG):(s * NG), t] -
		((t == 1) ? units.p_0[:, 1] :
		 pg₀[(1 + (s - 1) * NG):(s * NG),
			t - 1]) .<=
		ramp_up[:, 1] .* ((t == 1) ? onoffinit[:, 1] : x[:, t - 1]) +
		shut_up[:, 1] .* ((t == 1) ? ones(NG, 1) : u[:, t - 1]) +
		p_max[:, 1] .* (ones(NG, 1) - ((t == 1) ? onoffinit[:, 1] : x[:, t - 1])))

	units_downramp_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT],
		((t == 1) ? units.p_0[:, 1] : pg₀[(1 + (s - 1) * NG):(s * NG), t - 1]) -
		pg₀[(1 + (s - 1) * NG):(s * NG),
			t] .<=
		ramp_down[:, 1] .* x[:, t] +
		shut_down[:, 1] .* v[:, t] +
		p_max[:, 1] .* (x[:, t]))
	println("\t constraints: 8) ramp-up/ramp-down constraints\t\t\t\t done")
	return scuc, units_upramp_constr, units_downramp_constr
end

# Helper function for Piecewise Linear (PWL) cost constraints
function add_pwl_constraints!(scuc::Model, NT, NG, NS, units)
	# Check if PWL variables exist
	if isempty(scuc[:pgₖ])
		return println("\t constraints: 9) PWL skipped (pgₖ not defined)")
	end

	x = scuc[:x]
	pg₀ = scuc[:pg₀]
	pgₖ = scuc[:pgₖ]

	p_max = units.p_max
	p_min = units.p_min

	num_segments = size(pgₖ, 3) # Get number of segments from variable definition

	eachsegment = (p_max - p_min) / num_segments

	units_pwlpower_sum_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT, i = 1:NG],
		pg₀[i + (s - 1) * NG,
			t] .==
		p_min[i, 1] * x[i, t] + sum(pgₖ[i + (s - 1) * NG, t, k] for k in 1:num_segments))
	units_pwlblock_upbound_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT, i = 1:NG, k = 1:num_segments],
		pgₖ[i + (s - 1) * NG, t, k] <= eachsegment[i, 1] * x[i, t])
	units_pwlblock_dwbound_constr = @constraint(scuc, # Ensure segments are non-negative
		[s = 1:NS, t = 1:NT, i = 1:NG, k = 1:num_segments],
		pgₖ[i + (s - 1) * NG, t, k] >= 0)
	println("\t constraints: 9) piece linearization constraints\t\t\t done")
	return scuc, units_pwlpower_sum_constr, units_pwlblock_upbound_constr, units_pwlblock_dwbound_constr
end

# if config_param.is_HydroUnitCon == 1
# 	@variable(scuc, ph[1:(NH * NS), 1:NT] >= 0) # hydro power
# 	@variable(scuc, sh[1:(NH * NS), 1:NT] >= 0) # hydro storage
# end
function add_hydros_constraints!(scuc::Model, NT, NH, NS, hydros)
	# Check if PWL variables exist
	if isempty(scuc[:ph])
		return println("\t constraints: 9) hydro decision variables skipped (pgₖ not defined)")
	end

	ph = scuc[:ph]
	# sh = scuc[:sh]

	p_max = hydros.p_max
	p_min = hydros.p_min
	qmax = hydros.q_max
	q0 = hydros.q_0
	cumsum_resvoir = hydros.reservoircurve

	hydros_minpower_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT],
		ph[((s - 1) * NH + 1):(s * NH), t] .>= p_min[:, 1])
	hydros_maxpower_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT],
		ph[((s - 1) * NH + 1):(s * NH), t] .<= p_max[:, 1])
	hydros_resvoir_constr = @constraint(scuc,
		[s = 1:NS, t = 1:NT],
		ph[((s - 1) * NH + 1):(s * NH), t] .<= cumsum_resvoir[t, 1])

	hydros_cumsum_reservoir_constr = @constraint(scuc,
		[s = 1:NS],
		q0[:, 1] .+ sum(ones(NH, 1) * cumsum_resvoir[t, 1] .- ph[((s - 1) * NH + 1):(s * NH), t] for t in 1:NT) .<= qmax[:, 1])

	println("\t constraints: 14) hydro power limits\t\t\t\t\t done")

	return scuc, hydros_minpower_constr, hydros_maxpower_constr, hydros_resvoir_constr, hydros_cumsum_reservoir_constr
end