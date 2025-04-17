include("mainfunc.jl")

# Get the initial problem setup
scuc_masterproblem, scuc_subproblem, scenarios_prob, refcost, eachslope, units, lines, loads,
winds, config_param = main();

# Enable solver parameters for infeasibility detection
set_optimizer_attribute(scuc_subproblem, "InfUnbdInfo", 1)
set_optimizer_attribute(scuc_subproblem, "DualReductions", 0)

# First optimize the master problem
optimize!(scuc_masterproblem)

# Check solution status of master problem
try
    if termination_status(scuc_masterproblem) == MOI.OPTIMAL
        println("Master problem solved to optimality")
    else
        error("Master problem failed to solve: $(termination_status(scuc_masterproblem))")
    end
catch e
    println("Error in master problem: ", e)
    error("Master problem failed")
end

# Extract solution from master problem
x⁽⁰⁾ = value.(scuc_masterproblem[:x]) # Commitment decisions
u⁽⁰⁾ = value.(scuc_masterproblem[:u]) # Dispatch decisions
v⁽⁰⁾ = value.(scuc_masterproblem[:v]) # Voltage angle decisions

# Fix variables in subproblem
fix.(scuc_subproblem[:x], x⁽⁰⁾; force=true)
fix.(scuc_subproblem[:u], u⁽⁰⁾; force=true)
fix.(scuc_subproblem[:v], v⁽⁰⁾; force=true)

# Optimize subproblem
optimize!(scuc_subproblem)

# Check subproblem status and handle infeasibility
status = termination_status(scuc_subproblem)
println("\nSubproblem Status: ", status)

if status == MOI.OPTIMAL
    println("\nSubproblem is feasible")
    obj_value = objective_value(scuc_subproblem)
    println("Objective value: ", obj_value)

    # Get reduced costs for feasible solution
    x_reduced = reduced_cost.(scuc_subproblem[:x])
    u_reduced = reduced_cost.(scuc_subproblem[:u])
    v_reduced = reduced_cost.(scuc_subproblem[:v])

    println("\nReduced costs summary:")
    println("x variables: ", sum(abs.(x_reduced)))
    println("u variables: ", sum(abs.(u_reduced)))
    println("v variables: ", sum(abs.(v_reduced)))
else
    println("\nSubproblem is infeasible")

    # Get Farkas certificate (dual ray) for infeasible solution
    try
        dual_obj = dual_objective_value(scuc_subproblem)
        println("Dual objective value: ", dual_obj)

        # Get reduced costs (ray components) for infeasible solution
        x_ray = reduced_cost.(scuc_subproblem[:x])
        u_ray = reduced_cost.(scuc_subproblem[:u])
        v_ray = reduced_cost.(scuc_subproblem[:v])

        println("\nFarkas certificate components:")
        println("x variables ray: ", sum(abs.(x_ray)))
        println("u variables ray: ", sum(abs.(u_ray)))
        println("v variables ray: ", sum(abs.(v_ray)))
    catch e
        println("Error getting dual information: ", e)
    end
end