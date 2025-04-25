function add_optimitycut_constraints!(scuc_masterproblem::JuMP.Model, sub_model_struct::SCUC_Model, ret, iter_value)
	# @assert termination_status(sub_model_struct[1].model)
	x⁽⁰⁾ = iter_value[1]
	u⁽⁰⁾ = iter_value[2]
	v⁽⁰⁾ = iter_value[3]
	add_optimity_cut = @constraint(scuc_masterproblem,
		scuc_masterproblem[:θ] >=
		ret.θ + sum(
		ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) +
		ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)
	))
	return scuc_masterproblem, add_optimity_cut
end

function add_feasibilitycut_constraints!(scuc_masterproblem::JuMP.Model, sub_model_struct::SCUC_Model, ret, iter_value)
	@assert !(ret.is_feasible)
	# @assert !termination_status(sub_model_struct[1].model)
	x⁽⁰⁾ = iter_value[1]
	u⁽⁰⁾ = iter_value[2]
	v⁽⁰⁾ = iter_value[3]

	add_feasibility_cut = @constraint(scuc_masterproblem,
		ret.dual_θ + sum(
		ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) + ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)) <= 0)

	return scuc_masterproblem, add_feasibility_cut
end

function get_batch_cut_expressions(scuc_masterproblem::JuMP.Model, sub_model_struct::SCUC_Model, ret)

	# each_dual_result = ret[1]
	# TODO - 
    summarysize_dual_express = []
	for (key, coeff) in ret.dual_coeffs
		# Add the dual constraint to the master problem
		dual_expression = get_cut_expression(scuc_masterproblem::JuMP.Model, sub_model_struct::SCUC_Model, coeff)
		summarysize_dual_express = @expression(scuc_masterproblem,
			summarysize_dual_express + dual_expression)
		return scuc_masterproblem, summarysize_dual_express
	end
end

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

# function construct_benders_cut(scuc_masterproblem::JuMP.Model, units::unit, winds::wind, loads::load, lines::transmission, NG::Int64, NT::Int64, NW::Int64, ND::Int64, NL::Int64, config_param::config)

# 	#NOTE -  Balance constraints
# 	# Calculate the coefficient for the balance constraint in the Benders cut
# 	coefficient_bal_constr = sum(dual_bal_constr[t] * (sum(loads.load_curve[d, t] for d in 1:ND) -
# 													   sum(winds.scenarios_curve[1, t] * wind_pmax[w, 1] for w in 1:NW)) for t in 1:NT)

# 	#NOTE - Conventional generation upper bound constraint
# 	# Calculate the Lagrange term for the conventional generation upper bound constraint
# 	coefficient_con_gen_ub_constr = @expression(sum(scuc_masterproblem, dual_con_gen_up_constr[g, t] * units.p_max[g, 1] * x[g, t] for g in 1:NG, t in 1:NT))

# 	#NOTE - Conventional generation lower bound constraint
# 	# Calculate the Lagrange term for the conventional generation lower bound constraint
# 	coefficient_con_gen_lb_constr = @expression(scuc_masterproblem, sum(dual_con_gen_lb_constr[g, t] * units.p_min[g, 1] * x[g, t] for g in 1:NG, t in 1:NT))

# 	#NOTE - Wind generation upper bound constraint
# 	# Calculate the coefficient for the wind generation upper bound constraint
# 	coefficient_wind_gen_ub_constr = sum(dual_wind_up_constr[w, t] * winds.scenarios_curve[1, t] * wind_pmax[w, 1] for w in 1:NW, t in 1:NT)

# 	#NOTE - Load curtailment constraint
# 	# Calculate the coefficient for the load curtailment constraint
# 	coefficient_load_cut_constr = sum(dual_wind_dw_constr[d, t] * loads.load_curve[d, t] for d in 1:ND, t in 1:NT)

# 	onoffinit = calculate_initial_unit_status(units, NG)

# 	#NOTE - Conventional generator ramping up constraints
# 	# Calculate the Lagrange term for the conventional generator ramping up constraints
# 	coefficient_con_gen_ramp_up_constr = @expression(scuc_masterproblem,
# 		sum(
# 		dual_con_gen_ramp_up_constr[g, t] * (
# 			units.ramp_up[:, 1] .* ((t == 1) ? onoffinit[:, 1] : x[:, t - 1]) +
# 			units.shut_up[:, 1] .* ((t == 1) ? ones(NG, 1) : u[:, t - 1]) +
# 			units.p_max[:, 1] .* (ones(NG, 1) - ((t == 1) ? onoffinit[:, 1] : x[:, t - 1]))
# 		) for g in 1:NG, t in 2:NT
# 	))

# 	#NOTE - Conventional generator ramping down constraints
# 	# Calculate the Lagrange term for the conventional generation ramping down constraints
# 	coefficient_con_gen_ramp_dw_constr = @expression(scuc_masterproblem,
# 		sum(
# 		dual_con_gen_ramp_down_constr[g, t] * (
# 			units.ramp_down[:, 1] .* x[:, t] +
# 			units.shut_down[:, 1] .* v[:, t] + units.p_max[:, 1] .* (x[:, t])
# 		) for g in 1:NG, t in 2:NT
# 	))

# 	#NOTE - Network powerflow constraints
# 	# Calculate the coefficient for the network powerflow constraints
# 	coefficient_term_nw_constr = (config_param.is_NetWorkCon == 0) ? 0.0 :
# 								 sum((dual_nw_powerflow_up_constr[l, t] + dual_nw_powerflow_dw_constr[l, t]) * lines.p_max[l, 1] for l in 1:NL, t in 1:NT)

# 	#NOTE - Combine all cuts
# 	# Sum up all the coefficients to form the combined cut
# 	combined_cuts = @expression(scuc_masterproblem,
# 		coefficient_bal_constr +
# 		coefficient_con_gen_ub_constr +
# 		coefficient_con_gen_lb_constr +
# 		coefficient_wind_gen_ub_constr +
# 		coefficient_load_cut_constr +
# 		coefficient_con_gen_ramp_dw_constr +
# 		coefficient_con_gen_ramp_up_constr +
# 		coefficient_con_gen_ramp_down_constr +
# 		coefficient_term_nw_constr)

# 	return scuc_masterproblem, combined_cuts
# end

