# Bender Decomposition Framework
# This module provides a framework for solving stochastic optimization problems using Bender's decomposition.

using Printf

"""
`bd_framework(scuc_masterproblem::Model, scuc_subproblem::Model)`

Implements Bender's decomposition algorithm to solve a two-stage stochastic SCUC problem.

# Arguments
- `scuc_masterproblem::Model`: The JuMP model for the master problem.
- `scuc_subproblem::Model`: The JuMP model for the subproblem.
"""
function bd_framework(scuc_masterproblem::Model, scuc_subproblem::Model)
	# Constants
	MAXIMUM_ITERATIONS = 100 # Maximum number of iterations for Bender's decomposition
	ABSOLUTE_OPTIMIZATION_GAP = 1e-3 # Absolute gap for optimality
	@assert !is_mixed_integer_problem(scuc_subproblem)

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

		# Solve subproblem with feasibility cut
		ret = solve_subproblem_with_feasibility_cut(scuc_subproblem, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

		# Check if subproblem is feasible
		if ret.is_feasible
			# Bender optimality cut
			upper_bound = sum(objective_value(scuc_masterproblem) .- JuMP.value.(scuc_masterproblem[:θ])) + ret.θ[1]
			gap = abs(upper_bound - lower_bound) / abs(upper_bound)

			# Print iteration results
			print_iteration(iteration, lower_bound, upper_bound, gap)

			# Check convergence
			if gap < ABSOLUTE_OPTIMIZATION_GAP
				println("Bender optimality cut is found")
				break
			end

			# Add optimality cut to master problem
			@constraint(scuc_masterproblem,
				scuc_masterproblem[:θ] >=
					ret.θ + sum(
					ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) +
					ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)
				))
		else
			# Bender feasibility cut
			cut = @constraint(scuc_masterproblem,
				ret.dual_θ + sum(
					ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) +
					ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)
				) <= 0)

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
		# Return solution information
		return (
			is_feasible = true,
			θ = objective_value(scuc_subproblem),
			# sr⁺ = value.(scuc_subproblem[:sr⁺]),
			# sr⁻ = value.(scuc_subproblem[:sr⁻]),
			# Δpd = value.(scuc_subproblem[:Δpd]),
			# Δpw = value.(scuc_subproblem[:Δpw]),
			ray_x = reduced_cost.(scuc_subproblem[:x]),
			ray_u = reduced_cost.(scuc_subproblem[:u]),
			ray_v = reduced_cost.(scuc_subproblem[:v])
		)
	else

		# Return infeasibility information
		return (
			is_feasible = false,
			dual_θ = dual_objective_value(scuc_subproblem),
			ray_x = reduced_cost.(scuc_subproblem[:x]),
			ray_u = reduced_cost.(scuc_subproblem[:u]),
			ray_v = reduced_cost.(scuc_subproblem[:v]))
	end
end

"""
`print_iteration(k, args...)`

Prints the iteration number and other information.

# Arguments
- `k`: The iteration number.
- `args...`: The values to print.
"""
function print_iteration(k, args...)
	f(x) = Printf.@sprintf("%12.4e", x)
	println(lpad(k, 9), " ", join(f.(args), " "))
	return nothing
end
