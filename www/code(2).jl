using JuMP
using Gurobi

# Feasible LP Model
model_feasible = Model(Gurobi.Optimizer)

@variable(model_feasible, x >= 0)
@variable(model_feasible, y >= 0)

@constraint(model_feasible, con1, x + y <= 5)
@constraint(model_feasible, con2, 2x + y <= 8)

@objective(model_feasible, Max, 3x + 2y)

# Solve the feasible model
optimize!(model_feasible)

# Check the status (should be OPTIMAL)
term_status_feasible = termination_status(model_feasible)
println("Feasible Model Termination Status: ", term_status_feasible)

if term_status_feasible == MOI.OPTIMAL
    println("Feasible Model is Optimal.")
    println("Optimal objective value: ", objective_value(model_feasible))
    println("Optimal x: ", value(x))
    println("Optimal y: ", value(y))

    # Get dual variables (shadow prices) for the constraints
    dual_con1 = shadow_price(con1)  # Or use dual(con1)
    dual_con2 = shadow_price(con2)  # Or use dual(con2)

    println("Dual variable (shadow price) for constraint con1 (x + y <= 5): ", dual_con1)
    println("Dual variable (shadow price) for constraint con2 (2x + y <= 8): ", dual_con2)

    # Interpretation:
    #   dual_con1:  If you increase the RHS of x + y <= 5 to 6, the optimal objective
    #               value will increase by approximately dual_con1.
    #   dual_con2:  If you increase the RHS of 2x + y <= 8 to 9, the optimal objective
    #               value will increase by approximately dual_con2.

else
    println("Feasible Model did not solve to optimality.")
end