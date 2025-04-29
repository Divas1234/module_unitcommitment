function get_benders_multicuts_expression(scuc_masterproblem::JuMP.Model, sub_model_struct::SCUC_Model, coeff)
	# Unpack coefficients and related metadata from the coeff struct for clarity and maintainability
	x_coefficient = coeff.x
	u_coefficient = coeff.u
	v_coefficient = coeff.v
	x_order = coeff.x_sort_order
	u_order = coeff.u_sort_order
	v_order = coeff.v_sort_order
	rhs = coeff.rhs
	dual_coefficient = coeff.dual_coeffVector
	operator_precedence = coeff.operator_associatively

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
			dual_express = @expression(scuc_masterproblem,
				sum(sum(
						(operator_precedence[(t - 1) * NW + w, 1] * dual_coefficient[(t - 1) * NW + w, 1] * rhs[(t - 1) * NW + w, 1]) for w in 1:NW
					) for t in 1:NT))
		end

		# for load curtailment constraints
		if occursin("loads_curt_constr", String(keys_name))
			dual_express = @expression(scuc_masterproblem,
				sum(sum(
						operator_precedence[(t - 1) * ND + d, 1] * dual_coefficient[(t - 1) * ND + d, 1] * rhs[(t - 1) * ND + d, 1] for d in 1:ND
					) for t in 1:NT))
		end

		# for units_pwlblock_dwbound_constr
		if occursin("units_pwlblock_dwbound_constr", String(keys_name))
			dual_express = @expression(scuc_masterproblem,
				sum(sum(sum(
							operator_precedence[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] * dual_coefficient[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1] *
							rhs[(NG * NT) * (k - 1) + (t - 1) * NG + g, 1]
						for g in 1:NG) for t in 1:NT) for k in 1:NC))
		end

		# for system balance_constr
		if occursin("balance_constr", String(keys_name)) || occursin("sys_down_reserve_constr", String(keys_name))
			dual_express = @expression(scuc_masterproblem,
				sum(
				operator_precedence[t, 1] * dual_coefficient[t, 1] * rhs[t, 1] for t in 1:NT
			))
		end

		# for key_transmissionline_powerflow_upbound_constr and key_transmissionline_powerflow_downbound_constr
		if occursin("transmissionline_powerflow_upbound_constr", String(keys_name))
			dual_express = @expression(scuc_masterproblem,
				sum(sum(
						operator_precedence[(t - 1) * NL + l, 1] * dual_coefficient[(t - 1) * NL + l, 1] * rhs[(t - 1) * NL + l, 1] for l in 1:NL
					) for t in 1:NT))
		end

		if occursin("transmissionline_powerflow_downbound_constr", String(keys_name))
			dual_express = @expression(scuc_masterproblem,
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
			dual_express = @expression(scuc_masterproblem,
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
		end

		# for units rampingup and ramping down constraints
		# in which, the unit ramping down is regular constraints where unit[g,t] is related to p[g,t], but rampingup constraints not
		# NOTE: Implement the constraints for unit ramping up
		if occursin("units_upramp_constr", String(keys_name))
			dual_express = @expression(scuc_masterproblem,
				sum(
				sum(
					(isnothing(x_order) ? 0 :
					 (x_order == 0 ?
					  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * x_coefficient[(t - 1) * NG + g, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])) :
					  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * x_coefficient[(g - 1) * NT + t, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1]))
					)
					) +
					(isnothing(u_order) ? 0 :
					 (u_order == 0 ?
					  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * u_coefficient[(t - 1) * NG + g, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])) :
					  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * u_coefficient[(g - 1) * NT + t, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1]))
					)
					) +
					(isnothing(v_order) ? 0 :
					 (v_order == 0 ?
					  (dual_coefficient[(t - 1) * NG + g, 1] * operator_precedence[(t - 1) * NG + g, 1] * v_coefficient[(t - 1) * NG + g, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1])) :
					  (dual_coefficient[(g - 1) * NT + t, 1] * operator_precedence[(g - 1) * NT + t, 1] * v_coefficient[(g - 1) * NT + t, 1] * ((t == 1) ? 0 : scuc_masterproblem[:x][g, t - 1]))
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
		end
	end

	return scuc_masterproblem
end
