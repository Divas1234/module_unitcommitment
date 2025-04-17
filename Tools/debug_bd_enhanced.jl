include("mainfunc.jl")

# Get the initial problem setup
scuc_masterproblem, scuc_subproblem, scenarios_prob, refcost, eachslope, units, lines, loads,
winds, config_param = main();

# Enable solver parameters for infeasibility detection
set_optimizer_attribute(scuc_subproblem, "InfUnbdInfo", 1)
set_optimizer_attribute(scuc_subproblem, "DualReductions", 0)

# Initialize bounds and iteration counter
lower_bound = -Inf
upper_bound = Inf
global iteration = 1
const MAXIMUM_ITERATIONS = 100
const ABSOLUTE_OPTIMIZATION_GAP = 1e-3

try
    while iteration <= MAXIMUM_ITERATIONS
        println("\nIteration ", iteration)

        # Solve master problem
        optimize!(scuc_masterproblem)

        if termination_status(scuc_masterproblem) != MOI.OPTIMAL
            error("Master problem failed: $(termination_status(scuc_masterproblem))")
        end

        # Update lower bound
        lower_bound = objective_value(scuc_masterproblem)
        println("Lower bound: ", lower_bound)

        # Get master problem solution
        x⁽⁰⁾ = value.(scuc_masterproblem[:x])
        u⁽⁰⁾ = value.(scuc_masterproblem[:u])
        v⁽⁰⁾ = value.(scuc_masterproblem[:v])

        # Fix variables in subproblem
        fix.(scuc_subproblem[:x], x⁽⁰⁾; force=true)
        fix.(scuc_subproblem[:u], u⁽⁰⁾; force=true)
        fix.(scuc_subproblem[:v], v⁽⁰⁾; force=true)

        # Solve subproblem
        optimize!(scuc_subproblem)
        status = termination_status(scuc_subproblem)

        if status == MOI.OPTIMAL
            println("Subproblem is feasible")

            # Update upper bound
            current_obj = objective_value(scuc_subproblem)
            upper_bound = min(upper_bound,
                sum(objective_value(scuc_masterproblem) .- JuMP.value.(scuc_masterproblem[:θ])) + current_obj)

            println("Upper bound: ", upper_bound)

            # Get reduced costs for optimality cut
            ray_x = reduced_cost.(scuc_subproblem[:x])
            ray_u = reduced_cost.(scuc_subproblem[:u])
            ray_v = reduced_cost.(scuc_subproblem[:v])

            # Add optimality cut
            @constraint(scuc_masterproblem,
                scuc_masterproblem[:θ] >= current_obj +
                                          sum(ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) +
                                              ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) +
                                              ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)))

            # Check convergence
            gap = abs(upper_bound - lower_bound) / abs(upper_bound)
            println("Gap: ", gap)

            if gap < ABSOLUTE_OPTIMIZATION_GAP
                println("\nConverged!")
                break
            end
        else
            println("Subproblem is infeasible")

            # Get Farkas certificate
            dual_obj = dual_objective_value(scuc_subproblem)
            ray_x = reduced_cost.(scuc_subproblem[:x])
            ray_u = reduced_cost.(scuc_subproblem[:u])
            ray_v = reduced_cost.(scuc_subproblem[:v])

            println("Farkas certificate magnitude:")
            println("x variables: ", sum(abs.(ray_x)))
            println("u variables: ", sum(abs.(ray_u)))
            println("v variables: ", sum(abs.(ray_v)))

            # Add feasibility cut using Farkas certificate
            @constraint(scuc_masterproblem,
                sum(ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) +
                    ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) +
                    ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)) <= 0)
        end

        global iteration += 1
    end

    if iteration > MAXIMUM_ITERATIONS
        println("\nReached maximum iterations without convergence")
    end
catch e
    println("Error in Benders decomposition: ", e)
    rethrow(e)
end