using JuMP
using MathOptInterface

function get_greater_than_constr_rhs(current_model::Model, constr)
	rhs = Float64[]
	for con in constr
		idx = JuMP.index(con)
		push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).lower)
	end
	return rhs
end

function get_smaller_than_constr_rhs(current_model::Model, constr)
	rhs = Float64[]
	for con in constr
		idx = JuMP.index(con)
		push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).upper)
	end
	return rhs
end

function get_equal_to_constr_rhs(current_model::Model, constr)
	# rhs = Float64[]
	# for (_, con) in constr
	# 	idx = JuMP.index(con[1])
	# 	push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).value)
	# end

	rhs = Float64[]
	for con in constr
		idx = JuMP.index(con)
		push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).value)
	end

	return rhs
end

# function get_coeff_from_constr(current_model, constr, target_var)
# 	coeffs = Float64[]
# 	for con in constr
# 		idx = JuMP.index(con)
# 		func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)
# 		coeffi = get(Dict(term.variable => term.coefficient for term in func.terms), JuMP.index(target_var), 0.0)
# 		push!(coeffs, coeffi)
# 	end
# 	return coeffs, length(coeffs)
# end

function get_v_coeff_vectors_from_constr(nam, current_model, constr, NT, NG)
	dec_symbol = "v"

	# try
	# 	alignment_cons, sort_order = check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)
	# 	if !isnothing(alignment_cons)
	# 		for t in 2:NT, g in 1:NG

	# 			target_var = ((alignment_cons == 0) ? current_model[:v][g, t] : current_model[:v][g, t - 1])
	# 			res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
	# 			suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 			suit_term = res
	# 		end

	# 		t = 1
	# 		if alignment_cons == 0
	# 			for g in 1:NG
	# 				target_var = current_model[:v][g, t]
	# 				res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
	# 				suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 				suit_term = res
	# 			end
	# 		else
	# 			res = 0
	# 			suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 			suit_term = res
	# 		end
	# 	end
	# catch e
	# 	coeffs = zeros(NG * NT, 1)
	# 	sort_order = nothing
	# 	# println("\t v in not in current constraint\t", nam)
	# 	# @info "v coeffs = zeros, default"
	# end

	alignment_cons, sort_order = check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)

	if !isnothing(alignment_cons)
		coeffs = zeros(NG * NT, 1)

		for t in 2:NT, g in 1:NG

			target_var = ((alignment_cons == 0) ? current_model[:v][g, t] : current_model[:v][g, t - 1])
			res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
			idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
			coeffs[idx, 1] = res
		end

		t = 1
		if alignment_cons == 0
			for g in 1:NG
				target_var = current_model[:v][g, t]
				res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		else
			res = 0
			for g in 1:NG
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		end
	else
		coeffs = nothing
		sort_order = nothing
	end

	return coeffs, sort_order, alignment_cons
end

function get_u_coeff_vectors_from_constr(nam, current_model, constr, NT, NG)
	dec_symbol = "u"

	# try
	# 	alignment_cons, sort_order = check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)
	# 	if !isnothing(alignment_cons)
	# 		for t in 2:NT, g in 1:NG

	# 			target_var = ((alignment_cons == 0) ? current_model[:u][g, t] : current_model[:u][g, t - 1])
	# 			res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
	# 			suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 			suit_term = res
	# 		end

	# 		t = 1
	# 		if alignment_cons == 0
	# 			for g in 1:NG
	# 				target_var = current_model[:u][g, t]
	# 				res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
	# 				suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 				suit_term = res
	# 			end
	# 		else
	# 			res = 0
	# 			suit_term = ((sort_order == 0) ? coeffs[NG * (t - 1) + g, 1] : coeffs[NT * (g - 1) + g, 1])
	# 			suit_term = res
	# 		end
	# 	end
	# catch e
	# 	coeffs = zeros(NG * NT, 1)
	# 	sort_order = nothing
	# 	# println("\t u in not in current constraint\t", nam)
	# 	# @info "coeffs = zeros, default"
	# end

	alignment_cons, sort_order = check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)

	if !isnothing(alignment_cons)
		coeffs = zeros(NG * NT, 1)

		for t in 2:NT, g in 1:NG

			target_var = ((alignment_cons == 0) ? current_model[:u][g, t] : current_model[:u][g, t - 1])
			res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
			idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
			coeffs[idx, 1] = res
		end

		t = 1
		if alignment_cons == 0
			for g in 1:NG
				target_var = current_model[:u][g, t]
				res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		else
			res = 0
			for g in 1:NG
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		end
	else
		coeffs = nothing
		sort_order = nothing
	end

	return coeffs, sort_order, alignment_cons
end

function get_x_coeff_vectors_from_constr(nam, current_model, constr, NT, NG)

	# dec_symbol = "x"

	# try
	# 	coeffs = zeros(NG * NT, 1)

	# 	alignment_cons, sort_order = check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)

	# 	if !isnothing(alignment_cons)
	# 		for t in 2:NT, g in 1:NG

	# 			target_var = ((alignment_cons == 0) ? current_model[:x][g, t] : current_model[:x][g, t - 1])
	# 			res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
	# 			idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + g)
	# 			coeffs[idx, 1] = res
	# 		end

	# 		t = 1
	# 		if alignment_cons == 0
	# 			for g in 1:NG
	# 				target_var = current_model[:x][g, t]
	# 				res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
	# 				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + g)
	# 				coeffs[idx, 1] = res
	# 			end
	# 		else
	# 			res = 0
	# 			idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + g)
	# 			coeffs[idx, 1] = res
	# 		end
	# 	end
	# catch e
	# 	coeffs = zeros(NG * NT, 1)
	# 	sort_order = nothing
	# 	# println("\t x in not in current constraint\t", nam)
	# 	# @info "x coeffs = zeros, default"
	# end

	dec_symbol = "x"

	alignment_cons, sort_order = check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)

	if !isnothing(alignment_cons)
		coeffs = zeros(NG * NT, 1)

		for t in 2:NT, g in 1:NG

			target_var = ((alignment_cons == 0) ? current_model[:x][g, t] : current_model[:x][g, t - 1])
			res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
			idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
			coeffs[idx, 1] = res
		end

		t = 1
		if alignment_cons == 0
			for g in 1:NG
				target_var = current_model[:x][g, t]
				res, _, _ = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, sort_order)
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		else
			res = 0
			for g in 1:NG
				idx = ((sort_order == 0) ? NG * (t - 1) + g : NT * (g - 1) + t)
				coeffs[idx, 1] = res
			end
		end
	else
		coeffs = nothing
		sort_order = nothing
	end

	return coeffs, sort_order, alignment_cons
end

# TODO
function check_var_alignment_with_constraints(current_model, constr, NG, NT, dec_symbol)
	g, t = 2, 2
	if dec_symbol == "u"
		target_var = current_model[:u][g, t]
	elseif dec_symbol == "v"
		target_var = current_model[:v][g, t]
	elseif dec_symbol == "x"
		target_var = current_model[:x][g, t]
	end
	_, sort_order_1, is_included_in_current_constr_1 = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, -2)

	if dec_symbol == "u"
		target_var = current_model[:u][g, t - 1]
	elseif dec_symbol == "v"
		target_var = current_model[:v][g, t - 1]
	elseif dec_symbol == "x"
		target_var = current_model[:x][g, t - 1]
	end
	_, sort_order_2, is_included_in_current_constr_2 = get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, -2)

	if is_included_in_current_constr_1 || is_included_in_current_constr_2
		alignment_cons = (is_included_in_current_constr_1) ? 0 : 1 # check current variable decision including mode
		sort_order = (is_included_in_current_constr_1) ? sort_order_1 : sort_order_2
	else
		alignment_cons = nothing
		sort_order = nothing
	end
	return alignment_cons, sort_order
end

function get_index_in_constraint(target_var, current_model, constr, NG, NT, g, t, order = -2)
	if order == -2
		idx = JuMP.index(constr[NG * (t - 1) + g])
		func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)
		f = get_coeff_from_constr(func, target_var)

		if NT * (g - 1) + t < length(constr)
			im_idx = JuMP.index(constr[NT * (g - 1) + t])
			im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)
			im_f = get_coeff_from_constr(im_func, target_var)
		else
			im_f = nothing
		end

		if !isnothing(f) || !isnothing(im_f)
			# NOTE -  1: active order, 1 : inactive order
			res = (!isnothing(f)) ? f : im_f
			sort_order = (!isnothing(f)) ? 0 : 1
			is_included_in_current_constr = true
		else
			res = nothing
			sort_order = nothing
			is_included_in_current_constr = false
		end

	elseif order == -1
		res, sort_order, is_included_in_current_constr = nothing, nothing, false

	elseif order == 0
		idx = JuMP.index(constr[NG * (t - 1) + g])
		func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)
		res = get_coeff_from_constr(func, target_var)
		sort_order = 0
		is_included_in_current_constr = true

	elseif order == 1
		im_idx = JuMP.index(constr[NT * (g - 1) + t])
		im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)
		res = get_coeff_from_constr(im_func, target_var)
		sort_order = 1
		is_included_in_current_constr = true
	end

	return res, sort_order, is_included_in_current_constr
end

function get_coeff_from_constr(func, target_var)
	for term in func.terms
		if term.variable == JuMP.index(target_var)
			# println("Constraint involving x[$g,$t] → Coefficient: ", term.coefficient)
			return term.coefficient
		end
	end
	return nothing
end
