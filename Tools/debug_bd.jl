include("mainfunc.jl")
scuc_masterproblem, scuc_subproblem, master_allconstr_sets, sub_allconstr_sets, scenarios_prob, refcost, eachslope, units, lines, loads,
winds, config_param = main();

# DEBUG - benderdecomposition_module
bd_framework(scuc_masterproblem::Model, scuc_subproblem::Model, master_allconstr_sets, sub_allconstr_sets)
