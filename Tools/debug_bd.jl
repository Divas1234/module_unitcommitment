include("mainfunc.jl")
scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_sub_model_struct_dic, config_param, units,
lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main();

# DEBUG - benderdecomposition_module
bd_framework(scuc_masterproblem, scuc_subproblem, master_model_struct,
	batch_sub_model_struct_dic, winds, config_param)

# ---------------------------------------------------------------

batch_sub_model_struct_dic
# Constants and parameters
MAXIMUM_ITERATIONS = 10000 # Maximum number of iterations for Bender's decomposition
ABSOLUTE_OPTIMIZATION_GAP = 1e-3 # Absolute gap for optimality
NUMERICAL_TOLERANCE = 1e-6 # Numerical tolerance for stability

# Initialize bounds
best_upper_bound = Inf
best_lower_bound = -Inf
NS = Int64(winds.scenarios_nums)
scenarios_prob = 1.0 / winds.scenarios_nums

@assert !is_mixed_integer_problem(scuc_subproblem)
println("Starting (Strengthen) Benders decomposition algorithm")
println("iteration start ...\n")
println("====================================================")
println("ITER \t LOWER_bound \t    UPPER_bound   \t GAP")
println("----------------------------------------------------")

# Iteration loop
# Solve the master problem
optimize!(scuc_masterproblem)

# Check solution status
assert_is_solved_and_feasible(scuc_masterproblem)

# Get lower bound from master problem
lower_bound = objective_value(scuc_masterproblem)

# Extract solution from master problem
x⁽⁰⁾ = value.(scuc_masterproblem[:x])
u⁽⁰⁾ = value.(scuc_masterproblem[:u])
v⁽⁰⁾ = value.(scuc_masterproblem[:v])
iter_value = (x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

# Solve subproblem with feasibility cut
ret_dic = (config_param.is_ConsiderMultiCUTs == 1) ?
		  batch_solve_subproblem_with_feasibility_cut(batch_sub_model_struct_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾, NS) :
		  batch_solve_subproblem_with_feasibility_cut(batch_sub_model_struct_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

ret_dic[1].dual_equal_to_constr_dic
ret_dic[1].dual_greater_than_constr_dic
ret_dic[1].dual_smaller_than_constr_dic