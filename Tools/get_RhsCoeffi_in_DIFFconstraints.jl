using JuMP
using MathOptInterface

function get_greater_than_constr_rhs(current_model, constr)
	rhs = Float64[]
	for con in constr
		idx = JuMP.index(con)
		push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).lower)
	end
	return rhs
end

function get_smaller_than_constr_rhs(current_model, constr)
	rhs = Float64[]
	for con in constr
		idx = JuMP.index(con)
		push!(rhs, MOI.get(JuMP.backend(current_model), MOI.ConstraintSet(), idx).upper)
	end
	return rhs
end

function get_equal_to_constr_rhs(current_model, constr)
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

function get_x_coeff_vectors_from_constr(current_model, constr, NT, NG)
	coeffs = zeros(NG * NT, 1)

	for t in 1:NT
		for g in 1:NG
			target_var = current_model[:x][g, t]
			idx = JuMP.index(constr[NG * (t - 1) + g])
			func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)
			res = get_coeff_from_constr(func, target_var)
			println("this is:", res)
			coeffs[NG * (t - 1) + g, 1]  = res
		end
	end
	return coeffs
end

function get_u_coeff_vectors_from_constr(current_model, constr, NT, NG)
	coeffs = zeros(NG * NT, 1)

	for t in 1:NT
		for g in 1:NG
			target_var = current_model[:u][g, t]
			idx = JuMP.index(constr[NG * (t - 1) + g])
			func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)
			res = get_coeff_from_constr(func, target_var)
			# println("this is:", res)
			coeffs[NG * (t - 1) + g, 1]  = res
		end
	end
	return coeffs
end

function get_x_coeff_vectors_from_constr(current_model, constr, NT, NG)
	coeffs = zeros(NG * NT, 1)

	for t in 1:NT
		for g in 1:NG
			println("t:", t, "g:", g)
			target_var = current_model[:x][g, t]
			idx = JuMP.index(constr[NG * (t - 1) + g])
			func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), idx)

			im_idx = JuMP.index(constr[NT * (g - 1) + t])
			im_func = MOI.get(JuMP.backend(current_model), MOI.ConstraintFunction(), im_idx)
			f = get_coeff_from_constr(func, target_var)
			res = (!isnothing(f)) ? f : get_coeff_from_constr(im_func, target_var)
			println("this is:", res)
			coeffs[NG * (t - 1) + g, 1]  = res
		end
	end
	return coeffs
end


function get_coeff_from_constr(func, target_var)
	for term in func.terms
		if term.variable == JuMP.index(target_var)
			# println("Constraint involving x[$g,$t] → Coefficient: ", term.coefficient)
			return term.coefficient
		end
	end
end
