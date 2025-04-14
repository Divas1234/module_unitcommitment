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

    # Iteration loop
    for iteration in 1:MAXIMUM_ITERATIONS
        # Solve the master problem
        optimize!(scuc_masterproblem)

        # Check solution status
        assert_is_solved_and_feasible(scuc_masterproblem)

        # Get lower bound from master problem
        lower_bound = objective_function(scuc_masterproblem)

        # Extract solution from master problem
        x⁽⁰⁾ = value.(scuc_masterproblem[:x]) # Commitment decisions
        u⁽⁰⁾ = value.(scuc_masterproblem[:u]) # Dispatch decisions
        v⁽⁰⁾ = value.(scuc_masterproblem[:v]) # Voltage angle decisions

        # Solve subproblem with feasibility cut
        ret = solve_subproblem_with_feasibility_cut(scuc_subproblem, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

        # Check if subproblem is feasible
        if ret.is_feasible
            # Bender optimality cut
            upper_bound = (objective_value(scuc_masterproblem) - value(scuc_masterproblem[:θ])) + ret.θ
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
                scuc_masterproblem[:θ] >= ret.θ + sum(ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) + ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)))
        else
            # Bender feasibility cut
            cut = @constraint(scuc_masterproblem,
                scuc_masterproblem[:dual_θ] + sum(ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) + ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)) <= 0)
            @info "Adding the feasibility cut $(cut)"
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
    fix.(scuc_subproblem[:relaxed_x], x)
    fix.(scuc_subproblem[:relaxed_u], u)
    fix.(scuc_subproblem[:relaxed_v], v)
    # fix.(scuc_subproblem[:relaxed_su₀], su₀) # commented out
    # fix.(scuc_subproblem[:relaxed_sd₀], sd₀) # commented out

    # Optimize subproblem
    optimize!(scuc_subproblem)

    # Check if subproblem is solved and feasible
    if is_solved_and_feasible(scuc_subproblem; dual = true)
        # Return solution information
        return (
            is_feasible = true,
            θ = value.(scuc_subproblem[:θ]),
            # relaxed_x = value.(scuc_subproblem[:relaxed_x]), # commented out
            # relaxed_u = value.(scuc_subproblem[:relaxed_u]), # commented out
            # relaxed_v = value.(scuc_subproblem[:relaxed_v]), # commented out
            # relaxed_su₀ = value.(scuc_subproblem[:relaxed_su₀]), # commented out
            # relaxed_sd₀ = value.(scuc_subproblem[:relaxed_sd₀]), # commented out
            sr⁺ = value.(scuc_subproblem[:sr⁺]),
            sr⁻ = value.(scuc_subproblem[:sr⁻]),
            Δpd = value.(scuc_subproblem[:Δpd]),
            Δpw = value.(scuc_subproblem[:Δpw]),
            ray_x = reduced_cost.(scuc_subproblem[:relaxed_x]),
            ray_u = reduced_cost.(scuc_subproblem[:relaxed_u]),
            ray_v = reduced_cost.(scuc_subproblem[:relaxed_v])
        )
    end

    # Return infeasibility information
    return (
        is_feasible = false,
        dual_θ = dual_objective_value(scuc_subproblem),
        ray_x = reduced_cost.(scuc_subproblem[:relaxed_x]),
        ray_u = reduced_cost.(scuc_subproblem[:relaxed_u]),
        ray_v = reduced_cost.(scuc_subproblem[:relaxed_v])
    )
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
