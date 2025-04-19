include("mainfunc.jl")
scuc_masterproblem, scuc_subproblem, master_re_constr_sets, sub_re_constr_sets, config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main();

batch_scuc_subproblem_dic =
	(config_param.is_ConsiderMultiCUTs == 1) ?
	get_batch_scuc_subproblems_for_scenario(scuc_subproblem::Model, winds::wind, config_param::config) :
	OrderedDict(1 => scuc_subproblem)













# DEBUG - benderdecomposition_module
# bd_framework(scuc_masterproblem::Model, batch_scuc_subproblem_dic::OrderedDict, master_re_constr_sets, sub_re_constr_sets, winds, config_param)

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
ret_dic = if (config_param.is_ConsiderMultiCUTs == 1)
	batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾, NS)
else
	batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)
end

@show tem = sub_re_constr_sets[:LessThan]

JuMP.constraint_object(tem[100]).set.upper
scuc_subproblem[:units_minuptime_constr]

tem_scuc_subproblem = Model(Gurobi.Optimizer)
set_silent(scuc_subproblem)
@variable(scuc_masterproblem, xx[1:NG, 1:NT], Bin)
@variable(scuc_masterproblem, u[1:NG, 1:NT], Bin)
@variable(scuc_masterproblem, v[1:NG, 1:NT], Bin)

model = Model();
@variable(model, x);
con = @constraint(model, [i = 1:2], x <= i, base_name = "my_con")
constraint_by_name(model, "my_con")
con

scuc_subproblem[:winds_curt_constr_for_eachscenario]
dual.(scuc_subproblem[:winds_curt_constr_for_eachscenario]) # corrected variable name

scuc_subproblem = batch_scuc_subproblem_dic[1]

# Fix variables in subproblem
fix.(scuc_subproblem[:x], x⁽⁰⁾; force = true)
fix.(scuc_subproblem[:u], u⁽⁰⁾; force = true)
fix.(scuc_subproblem[:v], v⁽⁰⁾; force = true)
# fix.(scuc_subproblem[:relaxed_su₀], su₀) # commented out
# fix.(scuc_subproblem[:relaxed_sd₀], sd₀) # commented out

set_optimizer_attribute(scuc_subproblem, "InfUnbdInfo", 1)
set_optimizer_attribute(scuc_subproblem, "DualReductions", 0)
# Optimize subproblem
optimize!(scuc_subproblem)

all_constraints(scuc_subproblem)

is_solved_and_feasible(scuc_subproblem; dual = true)

ray_x = reduced_cost.(scuc_subproblem[:x])
ray_u = reduced_cost.(scuc_subproblem[:u])
ray_v = reduced_cost.(scuc_subproblem[:v])
dual.(scuc_subproblem[:units_minuptime_constr])

# Check if subproblem is solved and feasible
if is_solved_and_feasible(scuc_subproblem; dual = true)
	# Return solution information with scaled duals for numerical stability
	return (
		is_feasible = true,
		θ = objective_value(scuc_subproblem),
		ray_x = reduced_cost.(scuc_subproblem[:x]),
		ray_u = reduced_cost.(scuc_subproblem[:u]),
		ray_v = reduced_cost.(scuc_subproblem[:v]))
else
	# Get Farkas certificate (dual rays) for infeasibility
	# farkas_dual = MOI.get(scuc_subproblem, MOI.FarkasDual())
	# Scale and process the Farkas certificate
	return (
		is_feasible = false,
		dual_θ = dual_objective_value(scuc_subproblem),
		ray_x = reduced_cost.(scuc_subproblem[:x]),
		ray_u = reduced_cost.(scuc_subproblem[:u]),
		ray_v = reduced_cost.(scuc_subproblem[:v]),
		ray_x = scale_duals(farkas_dual[1:length(scuc_subproblem[:x])]),
		ray_u = scale_duals(farkas_dual[(length(scuc_subproblem[:x]) + 1):(length(scuc_subproblem[:x]) + length(scuc_subproblem[:u]))]),
		ray_v = scale_duals(farkas_dual[(length(scuc_subproblem[:x]) + length(scuc_subproblem[:u]) + 1):end])
	)
end

# Update bounds
batch_subproblem_nummber = length(ret_dic)
if ((config_param.is_ConsiderMultiCUTs == 1) ? batch_subproblem_nummber == NS : batch_subproblem_nummber == Int64(1)) == false
	println("Error: The number of batch_subproblems does not match the expected number.")
	return nothing
end
best_upper_bound, best_lower_bound, current_upper_bound, all_subproblems_feasibility_flag = get_upper_lower_bounds(
	scuc_masterproblem, ret_dic, best_upper_bound, best_lower_bound, lower_bound, scenarios_prob
)

# Check for convergence
if all_subproblems_feasibility_flag &&
	check_Bender_convergence(best_upper_bound, best_lower_bound, current_upper_bound, iteration, ABSOLUTE_OPTIMIZATION_GAP, NUMERICAL_TOLERANCE) == 1
	break
end

# Add appropriate Bender's cut based on subproblem feasibility
for (s, ret) in ret_dic
	cut_function = ret.is_feasible ? add_optimitycut_constraints! : add_feasibilitycut_constraints!
	cut_function(scuc_masterproblem, batch_scuc_subproblem_dic[s], ret, iter_value)
end
