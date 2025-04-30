function get_benders_multicuts_expression(scuc_masterproblem::JuMP.Model, coeff, keys_name, NG, NT, NW, ND, NL, NC = 3)

	# Unpack coefficients and related metadata from the coeff struct for clarity and maintainability
	x_coefficient = coeff.x
	u_coefficient = coeff.u
	v_coefficient = coeff.v
	x_order = coeff.x_sort_order
	u_order = coeff.u_sort_order
	v_order = coeff.v_sort_order
	rhs = coeff.rhs
	dual_coefficient = coeff.dual_coeffVector
	operator_precedence = coeff.operator_associativity

	if all(x -> x === nothing, (x_order, u_order, v_order))

		# for none unit-related constraints
		"""
			alignment type constraints
			- key_winds_curt_constr # NW * NT
			- key_loads_curt_constr # NW * NT
			- key_balance_constr
			- key_sys_down_reserve_constr
			- key_transmissionline_powerflow_upbound_constr
			- key_transmissionline_powerflow_downbound_constr
		"""

		# for wind power generation constraints
		if occursin("winds_curt_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(sum(
						(operator_precedence[(t - 1) * NW + w, 1] * dual_coefficient[(t - 1) * NW + w, 1] * rhs[(t - 1) * NW + w, 1]) for w in 1:NW
					) for t in 1:NT))
		end

		# for load curtailment constraints
		if occursin("loads_curt_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(sum(
						operator_precedence[(t - 1) * ND + d, 1] * dual_coefficient[(t - 1) * ND + d, 1] * rhs[(t - 1) * ND + d, 1] for d in 1:ND
					) for t in 1:NT))
		end

		# for units_pwlblock_dwbound_constr
		if occursin("units_pwlblock_dwbound_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(sum(sum(
							operator_precedence[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
							rhs[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1]
						for g in 1:NG) for t in 1:NT) for k in 1:NC))
		end

		# for system balance_constr
		if occursin("balance_constr", String(keys_name)) || occursin("sys_down_reserve_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				operator_precedence[t, 1] * dual_coefficient[t, 1] * rhs[t, 1] for t in 1:NT
			))
		end

		# for key_transmissionline_powerflow_upbound_constr and key_transmissionline_powerflow_downbound_constr
		if occursin("transmissionline_powerflow_upbound_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(sum(
						operator_precedence[(t - 1) * NL + l, 1] * dual_coefficient[(t - 1) * NL + l, 1] * rhs[(t - 1) * NL + l, 1] for l in 1:NL
					) for t in 1:NT))
		end

		if occursin("transmissionline_powerflow_downbound_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(sum(
						operator_precedence[(t - 1) * NL + l, 1] * dual_coefficient[(t - 1) * NL + l, 1] * rhs[(t - 1) * NL + l, 1] for l in 1:NL
					) for t in 1:NT))
		end

	else

		# for unit-related constraints with NG * NT
		"""
			alignment type constraints
			- key_sys_down_reserve_constr
			- key_sys_upreserve_constr
			- key_units_minpower_constr NG * NT
			- key_units_maxpower_constr NG * NT
			- key_units_pwlpower_sum_constr NG * NT * NZ
		"""
		# RE_FLAG = occursin("units_minpower_constr", String(keys_name)) || occursin("units_maxpower_constr", String(keys_name)) || occursin("sys_upreserve_constr", String(keys_name)) || occursin("units_downramp_constr", String(keys_name))
		patterns = ["units_minpower_constr", "units_maxpower_constr", "sys_upreserve_constr", "units_downramp_constr", "units_pwlpower_sum_constr"]
		RE_FLAG = any(p -> occursin(p, String(keys_name)), patterns)
		if RE_FLAG
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				sum(
					(isnothing(x_order) ? 0 :
					 (x_order == 0 ?
					  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * x_coefficient[(t - 1) * NG + g, 1] * (1) * scuc_masterproblem[:x][g, t]) :
					  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * x_coefficient[(g - 1) * NT + t, 1] * (1) * scuc_masterproblem[:x][g, t])
					)
					) +
					(isnothing(u_order) ? 0 :
					 (u_order == 0 ?
					  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * u_coefficient[(t - 1) * NG + g, 1] * (1) * scuc_masterproblem[:u][g, t]) :
					  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * u_coefficient[(g - 1) * NT + t, 1] * (1) * scuc_masterproblem[:u][g, t])
					)
					) +
					(isnothing(v_order) ? 0 :
					 (v_order == 0 ?
					  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * v_coefficient[(t - 1) * NG + g, 1] * (1) * scuc_masterproblem[:v][g, t]) :
					  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * v_coefficient[(g - 1) * NT + t, 1] * (1) * scuc_masterproblem[:v][g, t])
					)
					) +
					(
						(isnothing(x_order) ?
						 (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * rhs[(t - 1) * NG + g, 1]) :
						 (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * rhs[(g - 1) * NT + t, 1])
					)
					) for g in 1:NG
				) for t in 1:NT
			))
		end

		# for unit-related constraints with NG * NT * NZ
		# NOTE: Implement the constraints for NG * NT * NZ
		"""
		alignment type constraints
			- key_units_pwlblock_upbound_constr NG * NT * NZ
			- key_units_pwlblock_dwbound_constr NG * NT * NZ (>=0)
		"""
		# key_units_pwlblock_upbound_constr
		if occursin("units_pwlblock_upbound_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(sum(sum(
							(operator_precedence[t, 1] * dual_coefficient[t, 1] * rhs[t, 1]) +
							(x_order == 0 ?
							 (dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * operator_precedence[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
							  x_coefficient[(t - 1) * NG + g, 1] * (1) * scuc_masterproblem[:x][g, t]) :
							 (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] *
							  x_coefficient[(g - 1) * NT + t, 1] * (1) * scuc_masterproblem[:x][g, t])
							) +
							(x_order == 0 ?
							 (dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * operator_precedence[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
							  rhs[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1]) :
							 (dual_coefficient[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] * operator_precedence[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1] *
							  rhs[(NG * NT) * (k - 1) + (g - 1) * NT + t, 1])
							) for g in 1:NG
						) for t in 1:NT
					) for k in 1:NC
			))
		end

		# for units rampingup and ramping down constraints
		# in which, the unit ramping down is regular constraints where unit[g,t] is related to p[g,t], but rampingup constraints not
		# NOTE: Implement the constraints for unit ramping up
		if occursin("units_upramp_constr", String(keys_name))
			dual_expression_cut = @expression(scuc_masterproblem,
				sum(
				sum(
					(isnothing(x_order) ? 0 :
					 (x_order == 0 ?
					  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * x_coefficient[(t - 1) * NG + g, 1] * (-1) *
					   ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])) :
					  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * x_coefficient[(g - 1) * NT + t, 1] * (-1) *
					   ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1]))
					)
					) +
					(isnothing(u_order) ? 0 :
					 (u_order == 0 ?
					  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * u_coefficient[(t - 1) * NG + g, 1] * (-1) *
					   ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])) :
					  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * u_coefficient[(g - 1) * NT + t, 1] * (-1) *
					   ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1]))
					)
					) +
					(isnothing(v_order) ? 0 :
					 (v_order == 0 ?
					  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * v_coefficient[(t - 1) * NG + g, 1] * (-1) *
					   ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])) :
					  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * v_coefficient[(g - 1) * NT + t, 1] * (-1) *
					   ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1]))
					)
					) +
					(
						(isnothing(x_order) ?
						 (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * rhs[(t - 1) * NG + g, 1]) :
						 (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * rhs[(g - 1) * NT + t, 1])
					)
					) for g in 1:NG
				) for t in 1:NT
			))
		end
	end

	return scuc_masterproblem, dual_expression_cut
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

