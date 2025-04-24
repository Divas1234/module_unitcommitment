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

