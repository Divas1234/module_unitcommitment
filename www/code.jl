using JuMP
using Gurobi

# Example infeasible model
model = Model(Gurobi.Optimizer)

@variable(model, x >= 0)
@variable(model, y >= 0)

@constraint(model, con1, x + y <= 1)
@constraint(model, con2, x + y >= 2)  # Infeasible constraint

@objective(model, Max, x + y)

# Solve the model
optimize!(model)

# --- Always check status BEFORE accessing solution info ---
term_status = termination_status(model)
prim_status = primal_status(model)
dual_status = dual_status(model)

println("Termination Status: ", term_status)
println("Primal Status: ", prim_status)
println("Dual Status: ", dual_status) # Often INFEASIBILITY_CERTIFICATE for infeasible primals

if term_status == MOI.OPTIMAL
    println("Model is Optimal.")
    println("Objective value: ", objective_value(model))
    println("Optimal x: ", value(x))
    println("Optimal y: ", value(y))
    # Reduced costs are meaningful here
    println("Reduced cost of x: ", reduced_cost(x))
    println("Reduced cost of y: ", reduced_cost(y))
    # Duals (shadow prices) of constraints are also meaningful
    println("Shadow price of con1: ", shadow_price(con1))
    println("Shadow price of con2: ", shadow_price(con2))

elseif term_status == MOI.INFEASIBLE
    println("\nModel is Infeasible.")
    # Cannot get reduced costs because there is no optimal primal solution.
    # Trying to access them will likely error or return NaN.
    # println("Reduced cost of x: ", reduced_cost(x)) # This would likely error

    # Instead, get the Farkas dual certificate (infeasibility multipliers)
    # These are associated with the constraints.
    # Note: Gurobi might return 0.0 if it used a presolve step that
    # detected infeasibility before running the main algorithm needed to compute the certificate.
    # You might need solver-specific options to force computation (e.g., Presolve=0 for Gurobi).
    # Or check dual_status == MOI.INFEASIBILITY_CERTIFICATE
    if dual_status == MOI.INFEASIBILITY_CERTIFICATE
        println("Farkas dual for con1: ", shadow_price(con1)) # Or dual(con1)
        println("Farkas dual for con2: ", shadow_price(con2)) # Or dual(con2)
        # These values form a linear combination of the constraints
        # that proves infeasibility according to Farkas' Lemma.
        # For Ax <= b, find y >= 0 such that y'A = 0 and y'b < 0.
        # For Ax >= b, find y >= 0 such that y'A = 0 and y'b > 0.
        # Here: y1* (x+y) + y2*(-(x+y)) = 0 => y1 - y2 = 0 => y1 = y2
        # And: y1 * 1 + y2 * (-2) < 0 => y1 - 2*y2 < 0 => y1 - 2*y1 < 0 => -y1 < 0 => y1 > 0
        # So expect Farkas duals like (1.0, 1.0) or some positive multiple.
    else
        println("Could not retrieve Farkas certificate (Dual Status: $dual_status).")
        println("Try setting Gurobi parameter Presolve=0 or InfUnbdInfo=1.")
        # Example: set_optimizer_attribute(model, "Presolve", 0) before optimizing
    end


elseif term_status == MOI.DUAL_INFEASIBLE # (Which implies Primal Unbounded)
    println("\nModel is Unbounded (Dual Infeasible).")
    # Cannot get reduced costs or duals. Can sometimes get a primal ray.

else
    println("\nSolver finished with status: ", term_status)
end

# Note: The attribute access x.reduced_cost is deprecated in newer JuMP versions.
# Use the function call reduced_cost(x) instead (when applicable).