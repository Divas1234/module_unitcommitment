using JuMP

export add_unit_operation_constraints!, add_generator_power_constraints!,
	add_ramp_constraints!, add_pwl_constraints!

# Helper function for unit operational constraints (min up/down, binary logic, costs)
function add_unit_operation_constraints!(scuc::Model, NT, NG, units, onoffinit)
	x = scuc[:x]
	u = scuc[:u]
	v = scuc[:v]
	su₀ = scuc[:su₀]
	sd₀ = scuc[:sd₀]

	onoffinit = zeros(NG, 1)
	Lupmin = zeros(NG, 1)     # Minimum startup time
	Ldownmin = zeros(NG, 1)   # Minimum shutdown time

	for i in 1:NG
		# Uncomment if initial status is provided
		# onoffinit[i] = ((units.x_0[i, 1] > 0.5) ? 1 : 0)
		# Calculate minimum up/down time limits
		Lupmin[i] = min(NT, units.min_shutup_time[i] * onoffinit[i])
		Ldownmin[i] = min(NT, (units.min_shutdown_time[i, 1]) * (1 - onoffinit[i]))
	end

	# Min up/down time
	for i in 1:NG
		for t in Int64(max(1, Lupmin[i])):NT
			base_name_con₁ = "units_min_up_time" * "_" * string(i) * "_" * string(t)
			LB = Int64(max(t - units.min_shutup_time[i, 1] + 1, 1))
			@constraint(scuc, sum(u[i, r] for r in LB:t) <= x[i, t], base_name = base_name_con₁)
		end

		for t in Int64(max(1, Ldownmin[i])):NT
			base_name_con₂ = "units_min_down_time" * "_" * string(i) * "_" * string(t)
			LB = Int64(max(t - units.min_shutup_time[i, 1] + 1, 1))
			@constraint(scuc, sum(v[i, r] for r in LB:t) <= (1 - x[i, t]), base_name = base_name_con₂)
		end
	end

	println("\t constraints: 1) minimum shutup/shutdown time limits\t\t\t done")

	# Binary variable logic
	@constraint(scuc,
		[i = 1:NG, t = 1:NT],
		u[i, t] - v[i, t] == x[i, t] - ((t == 1) ? onoffinit[i] : x[i, t - 1]))
	@constraint(scuc, [i = 1:NG, t = 1:NT], u[i, t] + v[i, t] <= 1)

	println("\t constraints: 2) binary variable logic\t\t\t\t\t done")

	# Startup/shutdown cost
	shutupcost = units.coffi_cold_shutup_1
	shutdowncost = units.coffi_cold_shutdown_1
	@constraint(scuc, units_initial_upcost, su₀[:, 1] .>= shutupcost .* (x[:, 1] - onoffinit[:, 1]))
	@constraint(scuc, units_initial_dwcost, sd₀[:, 1] .>= shutdowncost .* (onoffinit[:, 1] - x[:, 1]))
	@constraint(scuc, units_upcost[t = 2:NT], su₀[:, t] .>= shutupcost .* u[:, t])
	@constraint(scuc, units_dwcost[t = 2:NT], sd₀[:, t] .>= shutdowncost .* v[:, t])

	return println("\t constraints: 3) shutup/shutdown cost\t\t\t\t\t done")
end

# Helper function for generator power limits
function add_generator_power_constraints!(scuc::Model, NT, NG, NS, units)
	x = scuc[:x]
	pg₀ = scuc[:pg₀]
	sr⁺ = scuc[:sr⁺]
	sr⁻ = scuc[:sr⁻]

	@constraint(scuc,
		units_maxpower_bound[s = 1:NS, t = 1:NT],
		pg₀[(1 + (s - 1) * NG):(s * NG), t] +
		sr⁺[(1 + (s - 1) * NG):(s * NG), t] .<=
			units.p_max[:, 1] .* x[:, t])
	@constraint(scuc,
		units_minpower_bound[s = 1:NS, t = 1:NT],
		pg₀[(1 + (s - 1) * NG):(s * NG), t] -
		sr⁻[(1 + (s - 1) * NG):(s * NG), t] .>=
			units.p_min[:, 1] .* x[:, t])

	return println("\t constraints: 5) generatos power limits\t\t\t\t\t done")
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

	@constraint(scuc,
		units_upramp_bound[s = 1:NS, t = 1:NT],
		pg₀[(1 + (s - 1) * NG):(s * NG), t] -
		((t == 1) ? units.p_0[:, 1] :
		 pg₀[(1 + (s - 1) * NG):(s * NG),
			t - 1]) .<=
			ramp_up[:, 1] .* ((t == 1) ? onoffinit[:, 1] : x[:, t - 1]) +
		shut_up[:, 1] .* ((t == 1) ? ones(NG, 1) : u[:, t - 1]) +
		p_max[:, 1] .* (ones(NG, 1) - ((t == 1) ? onoffinit[:, 1] : x[:, t - 1])))
	@constraint(scuc,
		units_dwramp_bound[s = 1:NS, t = 1:NT],
		((t == 1) ? units.p_0[:, 1] : pg₀[(1 + (s - 1) * NG):(s * NG), t - 1]) -
		pg₀[(1 + (s - 1) * NG):(s * NG),
			t] .<=
			ramp_down[:, 1] .* x[:, t] +
		shut_down[:, 1] .* v[:, t] +
		p_max[:, 1] .* (x[:, t]))

	return println("\t constraints: 8) ramp-up/ramp-down constraints\t\t\t\t done")
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

	@constraint(scuc,
		units_pwl_cons1[s = 1:NS, t = 1:NT, i = 1:NG],
		pg₀[i + (s - 1) * NG,
			t] .==
			p_min[i, 1] * x[i, t] + sum(pgₖ[i + (s - 1) * NG, t, k] for k in 1:num_segments))
	@constraint(scuc,
		units_pwl_cons2[s = 1:NS, t = 1:NT, i = 1:NG, k = 1:num_segments],
		pgₖ[i + (s - 1) * NG, t, k] <= eachsegment[i, 1] * x[i, t])
	@constraint(scuc, # Ensure segments are non-negative
		units_pwl_cons3[s = 1:NS, t = 1:NT, i = 1:NG, k = 1:num_segments],
		pgₖ[i + (s - 1) * NG, t, k] >= 0)

	return println("\t constraints: 9) piece linearization constraints\t\t\t done")
end
