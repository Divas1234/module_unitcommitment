# Bender Decomposition Framework
# This module provides a framework for solving stochastic optimization problems using Bender's decomposition.
include("add_cut_constraints.jl")
using Printf

"""
`bd_framework(scuc_masterproblem::Model, scuc_subproblem::Model)`

Implements Bender's decomposition algorithm to solve a two-stage stochastic SCUC problem.

# Arguments
- `scuc_masterproblem::Model`: The JuMP model for the master problem.
- `scuc_subproblem::Model`: The JuMP model for the subproblem.
"""
function bd_framework(scuc_masterproblem::Model, scuc_subproblem::Model)
	# Constants and parameters
	MAXIMUM_ITERATIONS = 10000 # Maximum number of iterations for Bender's decomposition
	ABSOLUTE_OPTIMIZATION_GAP = 1e-3 # Absolute gap for optimality
	NUMERICAL_TOLERANCE = 1e-6 # Numerical tolerance for stability
	@assert !is_mixed_integer_problem(scuc_subproblem)

	# Initialize bounds
	best_upper_bound = Inf
	best_lower_bound = -Inf

	# Iteration loop
	for iteration in 1:MAXIMUM_ITERATIONS
		# Solve the master problem
		optimize!(scuc_masterproblem)

		# Check solution status
		assert_is_solved_and_feasible(scuc_masterproblem)

		# Get lower bound from master problem
		lower_bound = objective_value(scuc_masterproblem)

		# Extract solution from master problem
		x⁽⁰⁾ = value.(scuc_masterproblem[:x]) # Commitment decisions
		u⁽⁰⁾ = value.(scuc_masterproblem[:u]) # Dispatch decisions
		v⁽⁰⁾ = value.(scuc_masterproblem[:v]) # Voltage angle decisions
		iter_value = (x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)
		# Solve subproblem with feasibility cut
		ret = solve_subproblem_with_feasibility_cut(scuc_subproblem, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

		# Check if subproblem is feasible
		if ret.is_feasible
			# Update bounds
			current_upper_bound = sum(objective_value(scuc_masterproblem) .- JuMP.value.(scuc_masterproblem[:θ])) + ret.θ[1]
			best_upper_bound = min(best_upper_bound, current_upper_bound)[1]
			best_lower_bound = max(best_lower_bound, lower_bound)[1]

			# Calculate gap with best bounds
			gap = abs(best_upper_bound - best_lower_bound) / (abs(best_upper_bound) + NUMERICAL_TOLERANCE)
			# @show typeof(current_upper_bound)
			# @show typeof(gap)
			# @show typeof(best_upper_bound)
			# @show typeof(best_lower_bound)

			# Print iteration results
			# print_iteration(iteration, lower_bound, upper_bound, gap)
			# println("ITER:", [current_upper_bound best_lower_bound best_upper_bound gap])
			print_iteration([iteration, current_upper_bound, best_lower_bound, best_upper_bound, gap])

			# Check convergence
			if gap < ABSOLUTE_OPTIMIZATION_GAP || abs(best_upper_bound - best_lower_bound) < NUMERICAL_TOLERANCE
				println("Convergence achieved - Optimal solution found")
				println("Final upper bound: ", best_upper_bound)
				println("Final lower bound: ", best_lower_bound)
				println("Final gap: ", gap)
				break
			end

			# Add optimality cut to master problem
			# @constraint(scuc_masterproblem,
			# 	scuc_masterproblem[:θ] >=
			# 		ret.θ + sum(
			# 		ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) +
			# 		ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)
			# 	))

			add_optimitycut_constraints!(scuc_masterproblem, scuc_subproblem, ret, iter_value)
		else
			# Bender feasibility cut
			# cut = @constraint(scuc_masterproblem,
			# 	ret.dual_θ + sum(
			# 		ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) +
			# 		ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)
			# 	) <= 0)
			add_feasibilitycut_constraints!(scuc_masterproblem, scuc_subproblem, ret, iter_value)
			# @info "Adding the feasibility cut $(cut)"
		end

		# # Extract the dual variables from the master problem (commented out)
		# dual_θ = dual_objective_value(scuc_masterproblem)
		# dual_x = dual.(scuc_masterproblem[:x])
		# dual_u = dual.(scuc_masterproblem[:u])
		# dual_v = dual.(scuc_masterproblem[:v])
	end
end

"""
`solve_subproblem_with_feasibility_cut(scuc_subproblem::Model, x, u, v)`

Solves the subproblem with fixed values for the first-stage variables and returns feasibility information.

# Arguments
- `scuc_subproblem::Model`: The JuMP model for the subproblem.
- `x`: Fixed values for commitment decisions.
- `u`: Fixed values for dispatch decisions.
- `v`: Fixed values for voltage angle decisions.
"""
function solve_subproblem_with_feasibility_cut(scuc_subproblem::Model, x, u, v)
	# Fix variables in subproblem
	fix.(scuc_subproblem[:x], x; force = true)
	fix.(scuc_subproblem[:u], u; force = true)
	fix.(scuc_subproblem[:v], v; force = true)
	# fix.(scuc_subproblem[:relaxed_su₀], su₀) # commented out
	# fix.(scuc_subproblem[:relaxed_sd₀], sd₀) # commented out

	set_optimizer_attribute(scuc_subproblem, "InfUnbdInfo", 1)
	set_optimizer_attribute(scuc_subproblem, "DualReductions", 0)
	# Optimize subproblem
	optimize!(scuc_subproblem)

	# Check if subproblem is solved and feasible
	if is_solved_and_feasible(scuc_subproblem; dual = true)
		# Return solution information with scaled duals for numerical stability
		return (
			is_feasible = true,
			θ = objective_value(scuc_subproblem),
			ray_x = reduced_cost.(scuc_subproblem[:x]),
			ray_u = reduced_cost.(scuc_subproblem[:u]),
			ray_v = reduced_cost.(scuc_subproblem[:v])
		)
	else
		# Get Farkas certificate (dual rays) for infeasibility
		# farkas_dual = MOI.get(scuc_subproblem, MOI.FarkasDual())

		# Scale and process the Farkas certificate
		return (
			is_feasible = false,
			dual_θ = dual_objective_value(scuc_subproblem),
			ray_x = reduced_cost.(scuc_subproblem[:x]),
			ray_u = reduced_cost.(scuc_subproblem[:u]),
			ray_v = reduced_cost.(scuc_subproblem[:v])            # ray_x=scale_duals(farkas_dual[1:length(scuc_subproblem[:x])]),            # ray_u=scale_duals(farkas_dual[(length(scuc_subproblem[:x])+1):(length(scuc_subproblem[:x])+length(scuc_subproblem[:u]))]),            # ray_v=scale_duals(farkas_dual[(length(scuc_subproblem[:x])+length(scuc_subproblem[:u])+1):end])
		)
	end
end

"""
`print_iteration(k, args...)`

Prints the iteration number and other information.

# Arguments
- `k`: The iteration number.
- `args...`: The values to print.
"""
function print_iteration(numbers, col_width = 15)
	# f(x) = Printf.@sprintf("%12.4e", x)
	# println(lpad(k, 9), " ", join(f.(args), " "))
	# 设定每列占用的字符宽度
	# 格式化输出，每个数字占 col_width 的宽度，保留两位小数
	for num in numbers
		print(rpad(@sprintf("%.*g", 6, num), col_width))
	end
	println()
	return nothing
end

"""
scale_duals(duals; scale_factor=1e3, min_magnitude=1e-10)

Scales dual values to improve numerical stability while preserving their signs.

# Arguments
- `duals`: Array of dual values to scale
- `scale_factor`: Factor to scale large values down by
- `min_magnitude`: Minimum absolute value to consider significant
"""
function scale_duals(duals; scale_factor = 1e3, min_magnitude = 1e-10)
	scaled_duals = similar(duals)
	for i in eachindex(duals)
		magnitude = abs(duals[i])
		if magnitude > scale_factor
			scaled_duals[i] = sign(duals[i]) * (magnitude / scale_factor)
		elseif magnitude < min_magnitude
			scaled_duals[i] = 0.0
		else
			scaled_duals[i] = duals[i]
		end
	end
	return scaled_duals
end
