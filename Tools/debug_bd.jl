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

batch_sub_model_struct_dic[1].reformated_constraints._greater_than[:key_units_maxpower_constr]
batch_sub_model_struct_dic[1].reformated_constraints._smaller_than[:key_units_minpower_constr]
batch_sub_model_struct_dic[1].reformated_constraints._equal_to[:key_balance_constr]

batch_sub_model_struct_dic[1].model

JuMP.upper_bound.(batch_sub_model_struct_dic[1].reformated_constraints._greater_than[:key_units_maxpower_constr])

tem = batch_sub_model_struct_dic[1].reformated_constraints._greater_than[:key_units_maxpower_constr]

tem = batch_sub_model_struct_dic[1].reformated_constraints._smaller_than[:key_units_minpower_constr]
coefficient(tem[1], x[1, 1])

JuMP.backend(tem[1]).set

using JuMP
using MathOptInterface
MOI.get(batch_sub_model_struct_dic[1].model, MOI.ConstraintSet(), JuMP.index(tem[1])).lower

typeof(tem[1])

MOI.get(batch_sub_model_struct_dic[1].model, MOI.ConstraintSet(), JuMP.index(tem[1])).lower

using JuMP
using MathOptInterface

function get_greater_than_constr_rhs(current_model, constr)
	rhs = Float64[]
	for con in constr
		idx = JuMP.index(con)
		push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).lower)
	end
	return rhs
end

function get_smaller_than_constr_rhs(current_model, constr)
	rhs = Float64[]
	for con in constr
		idx = JuMP.index(con)
		push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).upper)
	end
	return rhs
end

function get_equal_to_constr_rhs(current_model, constr)
	rhs = Float64[]
	for con in constr
		idx = JuMP.index(con)
		push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).value)
	end
	return rhs
end

target_var = batch_sub_model_struct_dic[1].model[:x][1, 1]  # must be a JuMP variable

for con in tem
	println("func = ", con)
	idx = JuMP.index(con)
	func = MOI.get(JuMP.backend(batch_sub_model_struct_dic[1].model), MOI.ConstraintFunction(), idx)

	for term in func.terms
		if term.variable == JuMP.index(target_var)
			println("Constraint involving x[1,1] → Coefficient: ", term.coefficient)
		end
	end
end

idx = JuMP.index(tem[1])
func = MOI.get(JuMP.backend(batch_sub_model_struct_dic[1].model), MOI.ConstraintFunction(), idx)

for term in func.terms
	if term.variable == JuMP.index(target_var)
		println("Constraint involving x[1,1] → Coefficient: ", term.coefficient)
	end
end

tem

function get_x_coeff_vectors_from_constr(current_model, constr, NT, NG)
	coeffs = zeros(NG * NT, 1)

	for t in NT
		for g in NG
			target_var = current_model[:x][g, t]
			idx = JuMP.index(constr[NG * (t - 1) + g])
			func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)
			res = get_coeff_from_constr(func, target_var)
			println("this is:", res)
			coeffs[NG * (t - 1) + g]  = res
		end
	end
	return coeffs
end

# TODO
function get_coeff_from_constr(func, target_var)
	for term in func.terms
		if term.variable == JuMP.index(target_var)
			# println("Constraint involving x[$g,$t] → Coefficient: ", term.coefficient)
			return term.coefficient
		end
	end
end;

get_x_coeff_vectors_from_constr(batch_sub_model_struct_dic[1].model, tem, 24, 3)


tem

current_model = batch_sub_model_struct_dic[1].model
constr = tem
t = 1
g = 2
target_var = current_model[:x][g, t]
@show constr[NG * (t - 1) + g]
idx = JuMP.index(constr[NG * (t - 1) + g])
func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)
coeffs[NG * (t - 1) + g] = get_coeff_from_constr(func, target_var)[1]



func.terms[1].variable == JuMP.index(target_var)
func.terms[1].coefficient













coeffs = zeros(NG * NT, 1)
target_var = current_model[:x][g, t]
idx = JuMP.index(constr[NG * (t - 1) + g])
func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)
get_coeff_from_constr(func, target_var)[1]













tem



constr[NG * (t - 1) + g]

















coeffs = Float64[]
func = MOI.get(JuMP.backend(batch_sub_model_struct_dic[1].model), MOI.ConstraintFunction(), idx)

t = 1
g = 1
target_var = current_model[:x][g, t]
current_constr = constr[NG * (t - 1) + g]
coeffi = get_coeff_from_constr(func, current_constr, target_var)

function get_coeff_from_constr(current_model, constr)
	idx = JuMP.index(tem[1])
	func = MOI.get(JuMP.backend(batch_sub_model_struct_dic[1].model), MOI.ConstraintFunction(), idx)
	func.terms
	coeff = get(Dict(term.variable => term.coefficient for term in func.terms), JuMP.index(target_var), 0.0)
end

target_var = x[1, 1]  # must be a JuMP variable

for con in tem
	index = JuMP.index(con)
	func = MOI.get(batch_sub_model_struct_dic[1].model, MOI.ConstraintFunction(), index)
	coeff = get(func.terms, target_var, 0.0)
	println("Coefficient of x[1,1]: ", coeff)
end

JuMP.lower_bound.(batch_sub_model_struct_dic[1].reformated_constraints._smaller_than[:key_units_minpower_constr])
JuMP.value.(batch_sub_model_struct_dic[1].reformated_constraints._equal_to[:key_balance_constr])

ret_dic[1].dual_equal_to_constr_dic
ret_dic[1].dual_greater_than_constr_dic
ret_dic[1].dual_smaller_than_constr_dic
