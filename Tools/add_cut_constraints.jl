function add_optimitycut_constraints!(scuc_masterproblem::JuMP.Model, scuc_subproblem::JuMP.Model, ret, iter_value)
	# @assert termination_status(scuc_subproblem)
	x⁽⁰⁾ = iter_value[1]
	u⁽⁰⁾ = iter_value[2]
	v⁽⁰⁾ = iter_value[3]
	@constraint(scuc_masterproblem,
		scuc_masterproblem[:θ] >=
			ret.θ + sum(
			ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) +
			ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)
		))
end

function add_feasibilitycut_constraints!(scuc_masterproblem::JuMP.Model, scuc_subproblem::JuMP.Model, ret, iter_value)
	@assert !(ret.is_feasible)
	# @assert !termination_status(scuc_subproblem)
	x⁽⁰⁾ = iter_value[1]
	u⁽⁰⁾ = iter_value[2]
	v⁽⁰⁾ = iter_value[3]

	@constraint(scuc_masterproblem,
		ret.dual_θ + sum(
			ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) + ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)) <= 0)

	# expr = 0.0

	# # 获取所有约束（≥, ≤, =）的对偶变量值
	# all_constr = [
	# 	all_constraints(scuc_subproblem, AffExpr, MOI.GreaterThan{Float64}),
	# 	all_constraints(scuc_subproblem, AffExpr, MOI.LessThan{Float64}),
	# 	all_constraints(scuc_subproblem, AffExpr, MOI.EqualTo{Float64})
	# ]

	# for set in all_constr
	# 	for c in set
	# 		λ = 0.0
	# 		try
	# 			λ = dual(c)
	# 		catch
	# 			λ = 0.0
	# 		end
	# 		if abs(λ) > 1e-6
	# 			rhs_expr = constraint_object(c).func
	# 			expr += -λ * rhs_expr  # 构建 feasibility cut: -λᵗ·rhs(x)
	# 		end
	# 	end
	# end

	# # println("→ 添加可行性割: $expr ≤ 0")
	# @constraint(scuc_masterproblem, expr ≤ 0)
end
