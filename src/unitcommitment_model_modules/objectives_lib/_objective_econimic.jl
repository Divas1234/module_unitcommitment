using JuMP

export set_objective_economic!

# Helper function to set the objective function
function set_objective_economic!(
		scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)
	# Cost parameters
	c₀ = config_param.is_CoalPrice  # Base cost of coal
	pₛ = scenarios_prob  # Probability of scenarios

	# Penalty coefficients for load and wind curtailment
	load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

	ρ⁺ = c₀ * 2
	ρ⁻ = c₀ * 2

	x = scuc[:x]
	su₀ = scuc[:su₀]
	sd₀ = scuc[:sd₀]
	pgₖ = scuc[:pgₖ]
	sr⁺ = scuc[:sr⁺]
	sr⁻ = scuc[:sr⁻]
	Δpd = scuc[:Δpd]
	Δpw = scuc[:Δpw]

	@objective(scuc,
		Min,
		sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT)+
		pₛ*
		c₀*
		(
			sum(
				sum(
					sum(sum(pgₖ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT))
				for s in 1:NS
				) for i in 1:NG
			)+
			sum(sum(sum(x[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS)+ # Assumes x is accessible
			sum(
				sum(
					sum(
						ρ⁺ * sr⁺[i + (s - 1) * NG, t] + ρ⁻ * sr⁻[i + (s - 1) * NG, t]
					for i in 1:NG
					) for t in 1:NT
				) for s in 1:NS
			)
		)+
		pₛ*
		load_curtailment_penalty*
		sum(sum(sum(Δpd[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS)+
		pₛ*
		wind_curtailment_penalty*
		sum(sum(sum(Δpw[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS))
	println("objective_function")
	println("\t MILP_type objective_function \t\t\t\t\t\t done")
end
