include("_objective_econimic.jl")

export set_objective!

function set_objective!(
		scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)
	return set_objective_economic!(
		scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)
end

println("objective functions exported.")
