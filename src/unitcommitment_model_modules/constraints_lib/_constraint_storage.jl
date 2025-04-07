using JuMP

export add_storage_constraints!

# Helper function for energy storage constraints
function add_storage_constraints!(scuc::Model, NT, NC, NS, stroges)
	# Check if storage exists before defining constraints
	# if NC == 0 || !isdefined(scuc, :pc⁺) # Check if variables were defined
	#     println("\t constraints: 11) stroges system constraints skipped (NC=0 or variables not defined)")
	#     return # Skip if no storage units or variables missing
	# end

	κ⁺ = scuc[:κ⁺]
	κ⁻ = scuc[:κ⁻]
	pc⁺ = scuc[:pc⁺]
	pc⁻ = scuc[:pc⁻]
	qc = scuc[:qc]
	α = scuc[:α]
	β = scuc[:β]

	# Use get with defaults for robustness against missing fields in stroges struct
	p_plus = stroges.p⁺
	p_minus = stroges.p⁻
	gamma_plus = stroges.γ⁺
	gamma_minus = stroges.γ⁻
	Q_max = stroges.Q_max
	Q_min = stroges.Q_min
	Q_initial = stroges.P₀
	# stroges.Q₀
	P_initial = stroges.P₀
	eta_plus = stroges.η⁺
	eta_minus = stroges.η⁻

	# discharge/charge limits
	@constraint(scuc,
		[s = 1:NS, t = 1:NT],
		pc⁺[((s - 1) * NC + 1):(s * NC), t].<=
		p_plus[:, 1] .* κ⁺[((s - 1) * NC + 1):(s * NC), t]) # charge power
	@constraint(scuc,
		[s = 1:NS, t = 1:NT],
		pc⁻[((s - 1) * NC + 1):(s * NC), t].<=
		p_minus[:, 1] .* κ⁻[((s - 1) * NC + 1):(s * NC), t]) # discharge power

	# coupling limits for adjacent discharge/charge constraints (Ramping for storage)
	@constraint(scuc,
		[s = 1:NS, t = 1:NT],
		pc⁺[((s - 1) * NC + 1):(s * NC), t] -
		((t == 1) ? P_initial[:, 1] : pc⁺[((s - 1) * NC + 1):(s * NC), t - 1]).<=
		gamma_plus[:, 1])
	@constraint(scuc,
		[s = 1:NS, t = 1:NT],
		((t == 1) ? P_initial[:, 1] : pc⁺[((s - 1) * NC + 1):(s * NC), t - 1]) -
		pc⁺[((s - 1) * NC + 1):(s * NC), t].<=gamma_minus[:, 1])

	# Mutual exclusion constraints in charge and discharge states
	@constraint(scuc,
		[s = 1:NS, t = 1:NT, c = 1:NC],
		κ⁺[(s - 1) * NC + c, t] + κ⁻[(s - 1) * NC + c, t]<=1)

	# Energy storage constraint (State of Charge)
	@constraint(scuc,
		[s = 1:NS, t = 1:NT],
		qc[((s - 1) * NC + 1):(s * NC), t].<=Q_max[:, 1])
	@constraint(scuc,
		[s = 1:NS, t = 1:NT],
		qc[((s - 1) * NC + 1):(s * NC), t].>=Q_min[:, 1])
	@constraint(scuc,
		[s = 1:NS, t = 1:NT],
		qc[((s - 1) * NC + 1):(s * NC),
			t].==
		((t == 1) ? Q_initial[:, 1] : qc[((s - 1) * NC + 1):(s * NC), t - 1]) + # Use Q₀ for initial SoC
		eta_plus[:, 1] .* pc⁺[((s - 1) * NC + 1):(s * NC), t] -
		(ones(NC, 1) ./ eta_minus[:, 1]) .* pc⁻[((s - 1) * NC + 1):(s * NC), t]) # Assuming Δt=1hr implicit

	# Initial-time and end-time equality (SoC target relative to initial SoC Q₀)
	@constraint(scuc,
		[s = 1:NS],
		0.99*Q_initial[:, 1].<=
		qc[((s - 1) * NC + 1):(s * NC), NT].<=
		1.01*Q_initial[:, 1])

	# Constraints on charging cycles (α, β logic)
	@constraint(scuc,
		[s = 1:NS, c = 1:NC, t = 1:NT],
		α[(s - 1) * NC + c,
			t]>=κ⁺[(s - 1) * NC + c, t] - ((t == 1) ? 0 : κ⁺[(s - 1) * NC + c, t - 1]))
	@constraint(scuc,
		[s = 1:NS, c = 1:NC, t = 1:NT],
		β[(s - 1) * NC + c,
			t]>=((t == 1) ? 0 : κ⁺[(s - 1) * NC + c, t - 1]) - κ⁺[(s - 1) * NC + c, t])

	@constraint(scuc,
		[s = 1:NS, c = 1:NC],
		sum(α[(s - 1) * NC + c, t] for t in 1:NT)<=5)
	@constraint(scuc,
		[s = 1:NS, c = 1:NC],
		sum(β[(s - 1) * NC + c, t] for t in 1:NT)<=5)

	println("\t constraints: 11) stroges system constraints limits\t\t\t done")
end
