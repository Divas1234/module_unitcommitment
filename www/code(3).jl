using JuMP
using Gurobi

# Infeasible LP Model
model_infeasible = Model(Gurobi.Optimizer)
set_optimizer_attribute(model_infeasible, "InfUnbdInfo", 1)  # Important for getting the Farkas certificate

@variable(model_infeasible, x >= 0)
@variable(model_infeasible, y >= 0)

@constraint(model_infeasible, con3, x + y <= 1)
@constraint(model_infeasible, con4, x + y >= 2)  # Infeasible constraint

@objective(model_infeasible, Max, 3x + 2y)

# Solve the infeasible model
optimize!(model_infeasible)

# Check the status (should be INFEASIBLE)
term_status_infeasible = termination_status(model_infeasible)
dual_status_infeasible = dual_status(model_infeasible) # Check for certificate too!
println("Infeasible Model Termination Status: ", term_status_infeasible)
println("Infeasible Model Dual Status: ", dual_status_infeasible)


if term_status_infeasible == MOI.INFEASIBLE && dual_status_infeasible == MOI.INFEASIBILITY_CERTIFICATE
    println("Infeasible Model is Infeasible, and Farkas certificate is available.")

    # Get Farkas dual multipliers for the constraints
    farkas_dual_con3 = shadow_price(con3)  # Or use dual(con3)
    farkas_dual_con4 = shadow_price(con4)  # Or use dual(con4)

    println("Farkas dual multiplier for constraint con3 (x + y <= 1): ", farkas_dual_con3)
    println("Farkas dual multiplier for constraint con4 (x + y >= 2): ", farkas_dual_con4)

    # Interpretation (based on Farkas' Lemma):
    # Consider our constraints:
    # x + y <= 1   (con3)
    # x + y >= 2   (con4)   =>  -x - y <= -2
    # The farkas duals y1 and y2 are nonnegative.
    #  y1(x+y) + y2(-x-y) = 0  => (y1 - y2)x + (y1 - y2)y = 0  => y1 == y2
    #  y1(1) + y2(-2) < 0 => y1 - 2y2 < 0 => y1 < 2y2, but since y1 == y2, then y1 - 2y1 < 0 => -y1 < 0 => y1 > 0
    #So any  y1 == y2 > 0  will be a valid certificate.
    # The shadow prices should thus be equal.


else
    println("Infeasible Model did not solve to infeasibility or Farkas certificate is not available.")
end