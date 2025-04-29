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

# DEBUG - --------

scuc_subproblem_dic = batch_scuc_subproblem_dic[1]

opti_termination_status = true

constraints = scuc_subproblem_dic.reformated_constraints

scuc_subproblem_dic.constraints.units_pwlblock_dwbound_constr

scuc_subproblem_dic.constraints.units_pwlblock_dwbound_constr

res_smaller_than = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._smaller_than, opti_termination_status)
res_equal_to = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._equal_to, opti_termination_status)
res_greater_than = get_dual_constrs_coefficient(scuc_subproblem_dic, constraints._greater_than, opti_termination_status)

final_dual_subproblem_coefficient_results = merge(res_equal_to, res_smaller_than, res_greater_than)

dual_coeffs = final_dual_subproblem_coefficient_results

coeff = dual_coeffs[:key_units_pwlblock_dwbound_constr]

@show coeff.dual_coeffVector

x_coefficient, u_coefficient, v_coefficient = coeff.x, coeff.u, coeff.v # coefficients for x, u, v variables
x_order, u_order, v_order = coeff.x_sort_order, coeff.u_sort_order, coeff.v_sort_order # sorted order for x, u, v variables
rhs = coeff.rhs # right-hand side value
dual_coefficient = coeff.dual_coeffVector # dual coefficient value
operator_precedence = coeff.operator_associativity # operator precedence for the expression: _equal_to to 1, _greater_than to -1, _less_than to 1

# keys_name = collect(keys(res_smaller_than))

all(x -> x === nothing, (x_order, u_order, v_order))

x_coefficient

dual_express = @expression(scuc_masterproblem,
	sum(sum(sum(
				operator_precedence[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * rhs[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1]
			for g in 1:NG) for t in 1:NT) for k in 1:NC))

# for unit-related constraints with NG * NT

rhs

dual_express = @expression(scuc_masterproblem,
	sum(sum(sum(
				(operator_precedence[t, 1] * dual_coefficient[t, 1] * rhs[t, 1]) +
				(x_order == 0 ?
				 (dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * operator_precedence[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
				  x_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * scuc_masterproblem[:x][g, t]) :
				 (dual_coefficient[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] * operator_precedence[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] *
				  x_coefficient[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] * scuc_masterproblem[:x][g, t])
				) +
				(x_order == 0 ?
				 (dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * rhs[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1]) :
				 (dual_coefficient[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] * rhs[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1])
				) for g in 1:NG
			) for t in 1:NT
		) for k in 1:NC
))

dual_express = @expression(scuc_masterproblem,
	sum(sum(sum(
				(operator_precedence[t, 1] * dual_coefficient[t, 1] * rhs[t, 1]) +
				(x_order == 0 ?
				 (dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * operator_precedence[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
				  x_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * scuc_masterproblem[:x][g, t]) :
				 (dual_coefficient[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] * operator_precedence[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] *
				  x_coefficient[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] * scuc_masterproblem[:x][g, t])
				) +
				(x_order == 0 ?
				 (dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * rhs[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1]) :
				 (dual_coefficient[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] * rhs[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1])
				) for g in 1:NG
			) for t in 1:NT
		) for k in 1:NC
))

@expression(scuc_masterproblem,
	sum(
	sum(
		(isnothing(x_order) ? 0 :
		 (x_order == 0 ?
		  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * x_coefficient[(t - 1) * NG + g, 1] * scuc_masterproblem[:x][g, t]) :
		  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * x_coefficient[(g - 1) * NT + t, 1] * scuc_masterproblem[:x][g, t])
		)
		) +
		(isnothing(u_order) ? 0 :
		 (u_order == 0 ?
		  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * u_coefficient[(t - 1) * NG + g, 1] * scuc_masterproblem[:u][g, t]) :
		  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * u_coefficient[(g - 1) * NT + t, 1] * scuc_masterproblem[:u][g, t])
		)
		) +
		(isnothing(v_order) ? 0 :
		 (v_order == 0 ?
		  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * v_coefficient[(t - 1) * NG + g, 1] * scuc_masterproblem[:v][g, t]) :
		  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * v_coefficient[(g - 1) * NT + t, 1] * scuc_masterproblem[:v][g, t])
		)
		) +
		(
			(isnothing(x_order) ?
			 (dual_coefficient[(t - 1) * NG + g, 1] * rhs[(t - 1) * NG + g, 1]) :
			 (dual_coefficient[(g - 1) * NT + t, 1] * rhs[(g - 1) * NT + t, 1])
		)
		) for g in 1:NG
	) for t in 1:NT
))

"""
	alignment type constraints
	- key_sys_down_reserve_constr
	- key_sys_upreserve_constr
	- key_units_minpower_constr NG * NT
	- key_units_maxpower_constr NG * NT
	- key_units_pwlpower_sum_constr NG * NT * NZ
"""

# if occursin("units_minpower_constr", String(keys_name)) || occursin("units_maxpower_constr", String(keys_name))
# @expression(scuc_masterproblem,
# 	sum(
# 	sum(
# 		(isnothing(x_order) ? 0 :
# 		 (x_order == 0 ?
# 		  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * x_coefficient[(t - 1) * NG + g, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t-1])) :
# 		  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * x_coefficient[(g - 1) * NT + t, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t-1]))
# 		)
# 		) +
# 		(isnothing(u_order) ? 0 :
# 		 (u_order == 0 ?
# 		  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * u_coefficient[(t - 1) * NG + g, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t-1])) :
# 		  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * u_coefficient[(g - 1) * NT + t, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t-1]))
# 		)
# 		) +
# 		(isnothing(v_order) ? 0 :
# 		 (v_order == 0 ?
# 		  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * v_coefficient[(t - 1) * NG + g, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t-1])) :
# 		  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * v_coefficient[(g - 1) * NT + t, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t-1]))
# 		)
# 		) +
# 		(
# 			(isnothing(x_order) ?
# 			 (dual_coefficient[(t - 1) * NG + g, 1] * rhs[(t - 1) * NG + g, 1]) :
# 			 (dual_coefficient[(g - 1) * NT + t, 1] * rhs[(g - 1) * NT + t, 1])
# 		)
# 		) for g in 1:NG
# 	) for t in 1:NT
# ))
# end
# if occursin("winds_curt_constr", String(keys_name))
# 	dual_express = @expression(scuc_masterproblem,
# 		sum(sum(
# 				operator_precedence[(t - 1) * NW + w, 1] * dual_coefficient[(t - 1) * NW + w, 1] * rhs[(t - 1) * NW + w, 1] for w in 1:NW
# 			) for t in 1:NT))
# end

# # for load curtailment constraints
# if occursin("loads_curt_constr", String(keys_name))
# 	dual_express = @expression(scuc_masterproblem,
# 		sum(sum(
# 				operator_precedence[(t - 1) * ND + d, 1] * dual_coefficient[(t - 1) * ND + d, 1] * rhs[(t - 1) * ND + d, 1] for d in 1:ND
# 			) for t in 1:NT))
# end

# # for system balance_constr
# if occursin("balance_constr", String(keys_name))
# 	dual_express = @expression(scuc_masterproblem,
# 		sum(
# 		operator_precedence[t, 1] * dual_coefficient[t, 1] * rhs[t, 1] for t in 1:NT
# 	))
# end

# # for key_transmissionline_powerflow_upbound_constr and key_transmissionline_powerflow_downbound_constr
# if occursin("transmissionline_powerflow_upbound_constr", String(keys_name))
# 	dual_express = @expression(scuc_masterproblem,
# 		sum(sum(
# 				operator_precedence[(t - 1) * NL + l, 1] * dual_coefficient[(t - 1) * NL + l, 1] * rhs[(t - 1) * NL + l, 1] for l in 1:NL
# 			) for t in 1:NT))
# end

# if occursin("transmissionline_powerflow_downbound_constr", String(keys_name))
# 	dual_express = @expression(scuc_masterproblem,
# 		sum(sum(
# 				operator_precedence[(t - 1) * NL + l, 1] * dual_coefficient[(t - 1) * NL + l, 1] * rhs[(t - 1) * NL + l, 1] for l in 1:NL
# 			) for t in 1:NT))
# end
