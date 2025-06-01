include("_define_SCUCmodel_structure.jl")
include("_define_masterproblem.jl")
include("_define_subproblem.jl")
include("_define_batch_subproblems.jl")

export get_batch_scuc_subproblems_for_scenario, modify_winds_constr_rhs!
export bd_masterfunction, bd_subfunction

export SCUCModel_decision_variables, SCUCModel_objective_function, SCUCModel_constraints, SCUCModel_reformat_constraints
export SCUC_Model
export dual_subprob_expr_coefficient

println("\t\u2192 both [batch] subproblems, dual subproblems and master problem are defined...")
