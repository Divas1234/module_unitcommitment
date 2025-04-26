function get_benders_multicuts_expression(scuc_masterproblem::JuMP.Model, sub_model_struct::SCUC_Model, coeff)

	x_coefficient, u_coefficient, v_coefficient = coeff.x, coeff.u, coeff.v # coefficients for x, u, v variables
	x_order, u_order, v_order = coeff.x_sort_order, coeff.u_sort_order, coeff.v_sort_order # sorted order for x, u, v variables
	rhs = coeff.rhs # right-hand side value
	dual_coefficient = coeff.dual_coeffVector # dual coefficient value
	operator_precedence = coeff.operator_associatively # operator precedence for the expression: _equal_to to 1, _greater_than to -1, _less_than to 1

	# for unit-related constraints
	"""
		alignment type constraints
		- key_winds_curt_constr # NW * NT
		- key_loads_curt_constr # NW * NT
		- key_balance_constr
		- key_transmissionline_powerflow_upbound_constr
		- key_transmissionline_powerflow_downbound_constr
	"""

	# for wind power generation constraints
	if max(x_order, u_order, v_order) < 0
		if key ∈ index_constr_item
			dual_express = @expression(scuc_masterproblem,
				sum(sum(
					operator_precedence[(t-1)*NW+w, 1] * dual_coefficient[(t-1)*NW+w, 1] * rhs[(t-1)*NW+w, 1] for w in 1:NW
				) for t in 1:NT))
		end

		# for load curtailment constraints
		if key ∈ index_constr_item
			dual_express = @expression(scuc_masterproblem,
				sum(sum(
					operator_precedence[(t-1)*ND+d, 1] * dual_coefficient[(t-1)*ND+d, 1] * rhs[(t-1)*ND+d, 1] for d in 1:ND
				) for t in 1:NT))
		end

		# for system balance_constr
		if key ∈ index_constr_item
			dual_express = @expression(scuc_masterproblem,
				sum(
					operator_precedence[t, 1] * dual_coefficient[t, 1] * rhs[t, 1] for t in 1:NT
				))
		end

		# for key_transmissionline_powerflow_upbound_constr and key_transmissionline_powerflow_downbound_constr
		if key ∈ index_constr_item
			dual_express = @expression(scuc_masterproblem,
				sum(sum(
					operator_precedence[(t-1)*NL+l, 1] * dual_coefficient[(t-1)*NL+l, 1] * rhs[(t-1)*NL+l, 1] for l in 1:NL
				) for t in 1:NT))
		end

	end



	if max(x_order, u_order, v_order) >= 0

		# for unit-related constraints with NG * NT
		"""
			alignment type constraints
			- key_sys_down_reserve_constr
			- key_sys_upreserve_constr
			- key_units_minpower_constr NG * NT
			- key_units_maxpower_constr NG * NT
			- key_units_pwlpower_sum_constr NG * NT * NZ
		"""

		if key ∈ index_constr_item

			dual_express = @expression(scuc_masterproblem,
				sum(
					sum(
						(
							(max(x_order, u_order, v_order) <= 0) ?
							dual_coefficient[(t-1)*NG+g, 1] .* (
								((x_order < 0) ? 0 : operator_precedence[(t-1)*NG+g, 1] .* x_coefficient[(t-1)*NG+g, 1] .* scuc_masterproblem[:x][g, t]) +
								((u_order < 0) ? 0 : operator_precedence[(t-1)*NG+g, 1] .* u_coefficient[(t-1)*NG+g, 1] .* scuc_masterproblem[:u][g, t]) +
								((v_order < 0) ? 0 : operator_precedence[(t-1)*NG+g, 1] .* v_coefficient[(t-1)*NG+g, 1] .* scuc_masterproblem[:v][g, t]) +
								rhs[(t-1)*NG+g, 1]
							)
							:
							dual_coefficient[(g-1)*NT+g, 1] .* (
								((x_order < 0) ? 0 : operator_precedence[(g-1)*NT+g, 1] .* x_coefficient[(g-1)*NT+g, 1] .* scuc_masterproblem[:x][g, t]) +
								((u_order < 0) ? 0 : operator_precedence[(g-1)*NT+g, 1] .* u_coefficient[(g-1)*NT+g, 1] .* scuc_masterproblem[:u][g, t]) +
								((v_order < 0) ? 0 : operator_precedence[(g-1)*NT+g, 1] .* v_coefficient[(g-1)*NT+g, 1] .* scuc_masterproblem[:v][g, t]) +
								rhs[(g-1)*NT+g, 1]
							)
						) for g ∈ 1:NG) for t ∈ 1:NT
				))
		end

		# for unit-related constraints with NG * NT * NZ
		# TODO
		"""
			alignment type constraints
			- key_units_pwlblock_upbound_constr NG * NT * NZ
			- key_units_pwlblock_dwbound_constr NG * NT * NZ (>=0)
		"""
		# key_units_pwlblock_upbound_constr
		if key ∈ index_constr_item
			@show dual_express = @expression(scuc_masterproblem,
				sum(sum(
					operator_precedence[(t-1)*NG*NK+(g-1)*NG+k, 1] * dual_coefficient[(t-1)*NG*NK+(g-1)*NG+k, 1] *
					(rhs[(t-1)*NG*NK+(g-1)*NG+k, 1] + x_coefficient[g, t] + rsh((t-1)*NG*NK+(g-1)*NG+k, 1)) for k in 1:NK
				) for g in 1:NG) for t in 1:NT)
		end

		# for units rampingup and ramping down constraints
		# in which, the unit ramping down is regular constraints where unit[g,t] is related to p[g,t], but rampingup constraints not
		# TODO 


	end
	return scuc_masterproblem

end
