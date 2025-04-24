include("_objective_econimic.jl")

export set_objective!

"""
Sets the objective function for the Security-Constrained Unit Commitment (SCUC) model.

This function serves as a wrapper for the economic objective function.

# Arguments
- `scuc::Model`: The JuMP model for the SCUC problem.
- `NT`: Number of time periods.
- `NG`: Number of generators.
- `ND`: Number of loads.
- `NW`: Number of wind power generators.
- `NS`: Number of scenarios.
- `units`: Unit information.
- `config_param`: Configuration parameters.
- `scenarios_prob`: Scenario probabilities.
- `refcost`: Reference cost.
- `eachslope`: Each slope.
"""
function set_objective!(
		scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)
	# Check if the input model is a JuMP Model
	@assert typeof(scuc) == Model "scuc must be a JuMP Model"

	return set_objective_economic!(
		scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)
end

println("\t\u2192 objective functions exported.")
