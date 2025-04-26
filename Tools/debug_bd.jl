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

sub_model_struct.constraints.units_upramp_constr


s = 1
scuc_masterproblem, add_optimity_cut = add_optimitycut_constraints!(scuc_masterproblem, batch_scuc_subproblem_dic[s], ret, iter_value)

@show coeff = ret.dual_coeffs[:key_units_upramp_constr]

typeof(ret.dual_coeffs)

# @show coeff = ret.dual_coeffs[:key_units_downramp_constr]

# get_cut_expression(scuc_masterproblem::JuMP.Model, sub_model_struct::SCUC_Model, coeff)

x_coefficient, u_coefficient, v_coefficient = coeff.x, coeff.u, coeff.v # coefficients for x, u, v variables
x_order, u_order, v_order = coeff.x_sort_order, coeff.u_sort_order, coeff.v_sort_order # sorted order for x, u, v variables
rhs = coeff.rhs # right-hand side value
dual_coefficient = coeff.dual_coeffVector # dual coefficient value
operator_precedence = coeff.operator_associativity # operator precedence for the expression: _equal_to to 1, _greater_than to -1, _less_than to 1

g = 1
t = 2
current_model =sub_model_struct.model
constr = sub_model_struct.constraints.units_upramp_constr
constr[NG * (t - 1) + g]
				# println("t:", t, "g:", g)
target_var = current_model[:x][g, t]
idx = JuMP.index(constr[NG * (t - 1) + g])
func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)

im_idx = JuMP.index(constr[NT * (g - 1) + t])
im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)

@show f = get_coeff_from_constr(func, target_var)
@show im_f = get_coeff_from_constr(im_func, target_var)
# res = (!isnothing(f)) ? f : im_f

if !isnothing(f) || !isnothing(im_f)
	res = (!isnothing(f)) ? f : im_f
	sort_order = (!isnothing(f)) ? 0 : 1
else
	is_included_in_current_constr = false
end

# println("this is:", res)
if sort_order == 0
	coeffs[NG * (t - 1) + g, 1] = res
else
	coeffs[NT * (g - 1) + t, 1] = res
end




































@show dual_express = @expression(scuc_masterproblem,
	sum(sum(
			operator_precedence[(t - 1) * NG + g, 1] * dual_coefficient[(t - 1) * NG + g, 1] * rhs[(t - 1) * NG + g, 1] for g in 1:NG
		) for t in 1:NT))

nam = 1
current_model = sub_model_struct.model
constr = sub_model_struct.constraints.units_upramp_constr
constr[4]
rms, x_order = get_x_coeff_vectors_from_constr(nam, current_model, _value, NT, NG)

	coeffs = zeros(NG * NT, 1)
	sort_order = -1
	is_included_in_current_constr = true # check current variable is in the constraint or not

t = 1
g = 1

constr[NG * (t - 1) + g]

				# println("t:", t, "g:", g)
				target_var = current_model[:x][g, t]
     			idx = JuMP.index(constr[NG * (t - 1) + g])
				func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)


				target_var = current_model[:x][g, t]
				idx = JuMP.index(constr[NG * (t - 1) + g])
				func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)

				im_idx = JuMP.index(constr[NT * (g - 1) + t])
				im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)

@show				f = get_coeff_from_constr(func, target_var)
				@show im_f = get_coeff_from_constr(im_func, target_var)
                # res = (!isnothing(f)) ? f : im_f

				if !isnothing(f) || !isnothing(im_f)
					res = (!isnothing(f)) ? f : im_f
					sort_order = (!isnothing(f)) ? 0 : 1
				else
					is_included_in_current_constr = false
				end




































# for unit-related constraints
"""
	alignment type constraints
	- key_winds_curt_constr # NW * NT
	- key_loads_curt_constr # NW * NT
"""

# for wind power generation constraints
@show dual_express = @expression(scuc_masterproblem,
	sum(sum(
			operator_precedence[(t - 1) * NW + w, 1] * dual_coefficient[(t - 1) * NW + w, 1] * rhs[(t - 1) * NW + w, 1] for w in 1:NW
		) for t in 1:NT))

# for load curtailment constraints
@show dual_express = @expression(scuc_masterproblem,
	sum(sum(
			operator_precedence[(t - 1) * ND + d, 1] * dual_coefficient[(t - 1) * ND + d, 1] * rhs[(t - 1) * ND + d, 1] for d in 1:ND
		) for t in 1:NT))


max(x_order, u_order, v_order) < 0

# for unit-related constraints with NG * NT
"""
	alignment type constraints
	- key_sys_down_reserve_constr
	- key_sys_upreserve_constr
	- key_units_minpower_constr NG * NT
	- key_units_maxpower_constr NG * NT
	- key_units_pwlpower_sum_constr NG * NT * NZ
	- key_balance_constr
	- key_transmissionline_powerflow_upbound_constr
	- key_transmissionline_powerflow_downbound_constr
"""
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
				dual_coefficient[(g - 1) * NT + g, 1] .* (
				((x_order < 0) ? 0 : operator_precedence[(g - 1) * NT + g, 1] .* x_coefficient[(g - 1) * NT + g, 1] .* scuc_masterproblem[:x][g, t]) +
				((u_order < 0) ? 0 : operator_precedence[(g - 1) * NT + g, 1] .* u_coefficient[(g - 1) * NT + g, 1] .* scuc_masterproblem[:u][g, t]) +
				((v_order < 0) ? 0 : operator_precedence[(g - 1) * NT + g, 1] .* v_coefficient[(g - 1) * NT + g, 1] .* scuc_masterproblem[:v][g, t]) +
				rhs[(g - 1) * NT + g, 1]
			)
			) for g ∈ 1:NG) for t ∈ 1:NT));


# for unit-related constraints with NG * NT * NZ
"""
	alignment type constraints
	- key_units_pwlblock_upbound_constr NG * NT * NZ
	- key_units_pwlblock_dwbound_constr NG * NT * NZ
"""
@show dual_express = @expression(scuc_masterproblem,
	sum(sum(
			operator_precedence[(t - 1) * ND + d, 1] * dual_coefficient[(t - 1) * ND + d, 1] * rhs[(t - 1) * ND + d, 1] for d in 1:ND
		) for t in 1:NT))

	# units_pwlblock_upbound_constr = @constraint(scuc,
	# 	[s = 1:NS, t = 1:NT, i = 1:NG, k = 1:num_segments],
	# 	pgₖ[i + (s - 1) * NG, t, k] <= eachsegment[i, 1] * x[i, t])
	# units_pwlblock_dwbound_constr = @constraint(scuc, # Ensure segments are non-negative
	# 	[s = 1:NS, t = 1:NT, i = 1:NG, k = 1:num_segments],
	# 	pgₖ[i + (s - 1) * NG, t, k] >= 0)









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
