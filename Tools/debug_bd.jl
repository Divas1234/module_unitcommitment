include("mainfunc.jl")
scuc_masterproblem, scuc_subproblem, scenarios_prob, refcost, eachslope, units, lines, loads,
winds, config_param = main();

# DEBUG - benderdecomposition_module
bd_framework(scuc_masterproblem::Model, scuc_subproblem::Model)



