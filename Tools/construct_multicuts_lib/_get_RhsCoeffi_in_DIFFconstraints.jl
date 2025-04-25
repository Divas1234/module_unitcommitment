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
	coeffs = zeros(NG * NT, 1)
	# sort_order = 0
	# default value for sort_order
	# NOTE - if sort_order == 0, it means the cureent constraints does not constains x

	sort_order = -1
	is_included_in_current_constr = true # check current variable is in the constraint or not

	try
		for t in 1:NT
			if is_included_in_current_constr == false
				break
			end

			for g in 1:NG
				target_var = current_model[:v][g, t]
				idx = JuMP.index(constr[NG * (t - 1) + g])
				func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)

				im_idx = JuMP.index(constr[NT * (g - 1) + t])
				im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)

				f = get_coeff_from_constr(func, target_var)
				res = (!isnothing(f)) ? f : get_coeff_from_constr(im_func, target_var)

				if !isnothing(f) || !isnothing(im_f)
					res = (!isnothing(f)) ? f : im_f
					sort_order = (!isnothing(f)) ? 0 : 1
				else
					is_included_in_current_constr = false
				end

				# sort_order = (!isnothing(f)) ? 0 : 1

				# println("this is:", res)
				if sort_order == 0
					coeffs[NG * (t - 1) + g, 1] = res
				else
					coeffs[NT * (g - 1) + t, 1] = res
				end
			end
		end
	catch e
		# println("\t v in not in current constraint\t", nam)
		# @info "v coeffs = zeros, default"
	end
	return coeffs, sort_order
end

function get_u_coeff_vectors_from_constr(nam, current_model, constr, NT, NG)
	coeffs = zeros(NG * NT, 1)
	# sort_order = 0
	sort_order = -1
	is_included_in_current_constr = true # check current variable is in the constraint or not

	try
		for t in 2:NT
			if is_included_in_current_constr == false
				break
			end

			for g in 1:NG
				target_var = current_model[:u][g, t]
				idx = JuMP.index(constr[NG * (t - 1) + g])
				func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)

				im_idx = JuMP.index(constr[NT * (g - 1) + t])
				im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)

				f = get_coeff_from_constr(func, target_var)
				im_f = get_coeff_from_constr(im_func, target_var)

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
			end
		end

		# initial time constraints
		if is_included_in_current_constr == true
			t = 1
			for g in 1:NG
				target_var = current_model[:u][g, t]
				idx = JuMP.index(constr[NG * (t - 1) + g])
				func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)

				im_idx = JuMP.index(constr[NT * (g - 1) + t])
				im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)

				f = get_coeff_from_constr(func, target_var)
				im_f = get_coeff_from_constr(im_func, target_var)
				res = (!isnothing(f)) ? f : im_f

				# println("this is:", res)
				if sort_order == 0
                    coeffs[NG*(t-1)+g, 1] = !isnothing(res) ? res : 0
				else
                    coeffs[NT*(g-1)+t, 1] = !isnothing(res) ? res : 0
				end
			end
		end

	catch e
		# println("\t u in not in current constraint\t", nam)
		# @info "coeffs = zeros, default"
	end
	return coeffs, sort_order
end

function get_x_coeff_vectors_from_constr(nam, current_model, constr, NT, NG)
	coeffs = zeros(NG * NT, 1)
	sort_order = -1
	is_included_in_current_constr = true # check current variable is in the constraint or not

	try
		for t in 2:NT
			if is_included_in_current_constr == false
				break
			end

			for g in 1:NG
				# println("t:", t, "g:", g)
				target_var = current_model[:x][g, t]
				idx = JuMP.index(constr[NG * (t - 1) + g])
				func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)

				im_idx = JuMP.index(constr[NT * (g - 1) + t])
				im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)

				f = get_coeff_from_constr(func, target_var)
				im_f = get_coeff_from_constr(im_func, target_var)
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
			end
		end

		# initial time constraints
		if is_included_in_current_constr == true
			t = 1
			for g in 1:NG
				target_var = current_model[:x][g, t]
				idx = JuMP.index(constr[NG * (t - 1) + g])
				func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)

				im_idx = JuMP.index(constr[NT * (g - 1) + t])
				im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)

				f = get_coeff_from_constr(func, target_var)
				im_f = get_coeff_from_constr(im_func, target_var)
				res = (!isnothing(f)) ? f : im_f

				# println("this is:", res)
				if sort_order == 0
                    coeffs[NG*(t-1)+g, 1] = !isnothing(res) ? res : 0
				else
                    coeffs[NT*(g-1)+t, 1] = !isnothing(res) ? res : 0
				end
			end
		end
	catch e
		# println("\t x in not in current constraint\t", nam)
		# @info "x coeffs = zeros, default"
	end
	return coeffs, sort_order
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
