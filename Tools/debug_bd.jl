ENV["JULIA_SHOW_ASCII"] = true

include("mainfunc.jl");

scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_sub_model_struct_dic, config_param, units,
lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main();

bd_framework(scuc_masterproblem, scuc_subproblem, master_model_struct,
	batch_sub_model_struct_dic, winds, config_param)

# DEBUG - benderdecomposition_module
optimize!(scuc_masterproblem)

# Check solution status
assert_is_solved_and_feasible(scuc_masterproblem)

# Get lower bound from master problem
lower_bound = objective_value(scuc_masterproblem) # NOTE - lower bound from master problem

# Extract solution from master problem
x⁽⁰⁾ = value.(scuc_masterproblem[:x])
u⁽⁰⁾ = value.(scuc_masterproblem[:u])
v⁽⁰⁾ = value.(scuc_masterproblem[:v])
iter_value = (x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

# Solve subproblem with feasibility cut

batch_scuc_subproblem_dic = batch_sub_model_struct_dic
ret_dic = (config_param.is_ConsiderMultiCUTs == 1) ?
		  batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾, NS) :
		  batch_solve_subproblem_with_feasibility_cut(batch_scuc_subproblem_dic, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

# Update bounds
batch_subproblem_nummber = length(ret_dic)
if ((config_param.is_ConsiderMultiCUTs == 1) ? batch_subproblem_nummber == NS : batch_subproblem_nummber == Int64(1)) == false
	println("Error: The number of batch_subproblems does not match the expected number.")
	return nothing
end

best_upper_bound, best_lower_bound, current_upper_bound,
all_subproblems_feasibility_flag = get_upper_lower_bounds(
	scuc_masterproblem, ret_dic, best_upper_bound, best_lower_bound, lower_bound, scenarios_prob
) # NOTE - upper bound from subproblem

for (s, ret) in ret_dic
	if ret.is_feasible == true
		println("Subproblem ", s, " is feasible.")
		scuc_masterproblem, add_optimity_cut = add_optimitycut_constraints!(scuc_masterproblem, batch_scuc_subproblem_dic[s], ret, iter_value)
	else
		scuc_masterproblem,
		add_feasibility_cut = add_feasibilitycut_constraints!(scuc_masterproblem, batch_scuc_subproblem_dic[s], ret, iter_value)
	end
end

ret = ret_dic[1]
s = 1
scuc_masterproblem, add_optimity_cut = add_optimitycut_constraints!(scuc_masterproblem, batch_scuc_subproblem_dic[s], ret, iter_value)

ret.dual_coeffs
typeof(ret.dual_coeffs)
@show coeff = ret.dual_coeffs[:key_units_downramp_constr]

get_cut_expression(scuc_masterproblem::JuMP.Model, sub_model_struct::SCUC_Model, coeff)

x_coefficient, u_coefficient, v_coefficient = coeff.x, coeff.u, coeff.v # coefficients for x, u, v variables
x_order, u_order, v_order = coeff.x_sort_order, coeff.u_sort_order, coeff.v_sort_order # sorted order for x, u, v variables
rhs = coeff.rhs # right-hand side value
dual_coefficient = coeff.dual_coeffVector # dual coefficient value
operator_precedence = coeff.operator_associativity # operator precedence for the expression: _equal_to to 1, _greater_than to -1, _less_than to 1
@show dual_express = @expression(scuc_masterproblem,
	sum(sum(
			(
				(max(x_order, u_order, v_order) <= 0) ?
				dual_coefficient[(t - 1) * NG + g, 1] .* (
				((x_order < 0) ? 0 : operator_precedence[(t - 1) * NG + g, 1] .* x_coefficient[(t - 1) * NG + g, 1] .* scuc_masterproblem[:x][g, t]) +
				((u_order < 0) ? 0 : operator_precedence[(t - 1) * NG + g, 1] .* u_coefficient[(t - 1) * NG + g, 1] .* scuc_masterproblem[:u][g, t]) +
				((v_order < 0) ? 0 : operator_precedence[(t - 1) * NG + g, 1] .* v_coefficient[(t - 1) * NG + g, 1] .* scuc_masterproblem[:v][g, t]) +
				rhs[(t - 1) * NG + g, 1]
			)
				:
				dual_coefficient[(g - 1) * NT + g, 1] * (
				((x_order < 0) ? 0 : operator_precedence[(g - 1) * NT + g, 1] .* x_coefficient[(g - 1) * NT + g, 1] .* scuc_masterproblem[:x][g, t]) +
				((u_order < 0) ? 0 : operator_precedence[(g - 1) * NT + g, 1] .* u_coefficient[(g - 1) * NT + g, 1] .* scuc_masterproblem[:u][g, t]) +
				((v_order < 0) ? 0 : operator_precedence[(g - 1) * NT + g, 1] .* v_coefficient[(g - 1) * NT + g, 1] .* scuc_masterproblem[:v][g, t]) +
				rhs[(g - 1) * NT + g, 1]
			)
			) for g ∈ 1:NG) for t ∈ 1:NT));

operator_precedence

function get_cut_expression(scuc_masterproblem::JuMP.Model, sub_model_struct::SCUC_Model, coeff)
	x_coefficient, u_coefficient, v_coefficient = coeff.x, coeff.u, coeff.v # coefficients for x, u, v variables
	x_order, u_order, v_order = coeff.x_sort_order, coeff.u_sort_order, coeff.v_sort_order # sorted order for x, u, v variables
	rhs = coeff.rhs # right-hand side value
	dual_coefficient = coeff.dual_coeffVector # dual coefficient value
	operator_precedence = coeff.operator_associatively # operator precedence for the expression: _equal_to to 1, _greater_than to -1, _less_than to 1
	dual_express = @expression(scuc_masterproblem,
		operator_precedence * sum(
		(
			(max(x_order, u_order, v_order) <= 0) ?
			dual_coefficient[(t - 1) * NG + g, 1] .* (
			((x_order < 0) ? 0 : x_coefficient[(t - 1) * NG + g, 1] .* scuc_masterproblem[:x][g, t]) +
			((u_order < 0) ? 0 : u_coefficient[(t - 1) * NG + g, 1] .* scuc_masterproblem[:u][g, t]) +
			((v_order < 0) ? 0 : v_coefficient[(t - 1) * NG + g, 1] .* scuc_masterproblem[:v][g, t])
		)
			:
			dual_coefficient[(g - 1) * NT + g, 1] * (
			((x_order < 0) ? 0 : x_coefficient[(g - 1) * NT + g, 1] .* scuc_masterproblem[:x][g, t]) +
			((u_order < 0) ? 0 : u_coefficient[(g - 1) * NT + g, 1] .* scuc_masterproblem[:u][g, t]) +
			((v_order < 0) ? 0 : v_coefficient[(g - 1) * NT + g, 1] .* scuc_masterproblem[:v][g, t])
		)
		) for g ∈ 1:NG, t ∈ 1:NT))

	return dual_express
end
