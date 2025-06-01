using JuMP

"""
	get_dual_constrs_coefficients(
		current_model::SCUC_Model,
		constrs::Dict{Symbol, <:ConstraintRef},
		opti_termination_status::Bool,
		NT::Int, # Pass NT as argument
		NG::Int  # Pass NG as argument
	)::Dict{Symbol, dual_subprob_expr_coefficient}

Calculates the coefficients for constructing dual feasibility or optimality cuts
based on the constraints of a subproblem model.

Args:
	current_model: The SCUC_Model containing the solved JuMP model.
	constrs: A dictionary mapping constraint names (Symbols) to their JuMP ConstraintRef objects.
	opti_termination_status: Boolean indicating if the optimization terminated successfully (true)
							 or if shadow prices should be used (false, e.g., infeasible/unbounded).
	NT: Number of time periods (passed as argument).
	NG: Number of generators (passed as argument).

Returns:
	A dictionary mapping constraint names (Symbols) to their corresponding
	`dual_subprob_expr_coefficient` structs containing coefficients for the dual cut expression.
"""

function get_dual_constrs_coefficient(current_model::SCUC_Model, constrs, opti_termination_status)
	dual_results = Dict{Symbol, dual_subprob_expr_coefficient}()

	for (key, value) in constrs
		constr_type_str = string(typeof(value))
		if occursin("EqualTo", constr_type_str)
			rhs_constr = get_equal_to_constr_rhs(current_model.model, value)
			operator_ass = ones(length(rhs_constr)) .* 1.0
		elseif occursin("LessThan", constr_type_str)
			rhs_constr = get_smaller_than_constr_rhs(current_model.model, value)
			operator_ass = ones(length(rhs_constr)) .* -1.0
		elseif occursin("GreaterThan", constr_type_str)
			rhs_constr = get_greater_than_constr_rhs(current_model.model, value)
			operator_ass = ones(length(rhs_constr)) .* 1.0
		end

		x_coeff, x_sort_order, x_alignment_flag = get_x_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)
		u_coeff, u_sort_order, u_alignment_flag = get_u_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)
		v_coeff, v_sort_order, v_alignment_flag = get_v_coeff_vectors_from_constr(key, current_model.model, value, NT, NG)

		#check order is valid
		# @show x_sort_order, u_sort_order, v_sort_order

		@assert length(Set([x_sort_order, u_sort_order, v_sort_order])) <= 2

		if opti_termination_status == true
			dual_coeff = dual.(value) #strong convex
		else
			dual_coeff = shadow_price.(value) #farkas convex
		end

		dual_results[key] = build_dual_cuts_expr_coefficient(
			rhs = rhs_constr,
			x = (!isnothing(x_coeff) ? x_coeff = x_coeff[:, 1] : nothing),
			u = (!isnothing(u_coeff) ? u_coeff = u_coeff[:, 1] : nothing),
			v = (!isnothing(v_coeff) ? v_coeff = v_coeff[:, 1] : nothing),
			x_sort_order = (!isnothing(x_sort_order) ? Int64(x_sort_order) : nothing),
			u_sort_order = (!isnothing(u_sort_order) ? Int64(u_sort_order) : nothing),
			v_sort_order = (!isnothing(v_sort_order) ? Int64(v_sort_order) : nothing),
			x_alignment_flag = (!isnothing(x_alignment_flag) ? x_alignment_flag : nothing),
			u_alignment_flag = (!isnothing(u_alignment_flag) ? u_alignment_flag : nothing),
			v_alignment_flag = (!isnothing(v_alignment_flag) ? v_alignment_flag : nothing),
			dual_coeffVector = dual_coeff,
			operator_associativity = operator_ass
		)
	end

	return dual_results
end
