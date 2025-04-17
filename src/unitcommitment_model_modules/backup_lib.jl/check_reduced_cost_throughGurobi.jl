using Gurobi
using JuMP

# Create the model (example MILP problem)
model = Model(Gurobi.Optimizer)

# Define variables and constraints for the original problem
@variable(model, x>=0)
@variable(model, y>=0)
@constraint(model, x + 2y<=10)
@constraint(model, x - y>=2)

# Set objective function
@objective(model, Min, x+y)

# Optimize the model
optimize!(model)

# Extract dual variables (Lagrange multipliers) from the constraints
if termination_status(model) == MOI.OPTIMAL
	println("Dual Variables for Constraints:")

	# Extracting dual variables (Pi) for constraints
	for (i, constr) in enumerate(all_constraints(model, include_variable_in_set_constraints = false))
		println("Constraint ", i, " Dual Variable (Pi): ", dual(constr))
	end

	# Farkas' Multipliers (Extreme Rays) are not directly accessible in JuMP
	# You would typically obtain them from the solver if the problem is infeasible
	println("Farkas' Multipliers (Extreme Rays) are not directly accessible in JuMP.")
else
	println("No optimal solution found.")
end

using JuMP, Gurobi, Test

model = direct_model(Gurobi.Optimizer())
@variable(model, 0<=x<=2.5, Int)
@variable(model, 0<=y<=2.5, Int)
@objective(model, Max, y)
cb_calls = Cint[]
function my_callback_function(cb_data, cb_where::Cint)
	# You can reference variables outside the function as normal
	push!(cb_calls, cb_where)
	# You can select where the callback is run
	if cb_where != GRB_CB_MIPSOL && cb_where != GRB_CB_MIPNODE
		return
	end
	# You can query a callback attribute using GRBcbget
	if cb_where == GRB_CB_MIPNODE
		resultP = Ref{Cint}()
		GRBcbget(cb_data, cb_where, GRB_CB_MIPNODE_STATUS, resultP)
		if resultP[] != GRB_OPTIMAL
			return  # Solution is something other than optimal.
		end
	end
	# Before querying `callback_value`, you must call:
	Gurobi.load_callback_variable_primal(cb_data, cb_where)
	x_val = callback_value(cb_data, x)
	y_val = callback_value(cb_data, y)
	# You can submit solver-independent MathOptInterface attributes such as
	# lazy constraints, user-cuts, and heuristic solutions.
	if y_val - x_val > 1 + 1e-6
		con = @build_constraint(y - x<=1)
		MOI.submit(model, MOI.LazyConstraint(cb_data), con)
	elseif y_val + x_val > 3 + 1e-6
		con = @build_constraint(y + x<=3)
		MOI.submit(model, MOI.LazyConstraint(cb_data), con)
	end
	if rand() < 0.1
		# You can terminate the callback as follows:
		GRBterminate(backend(model))
	end
	return
end
# You _must_ set this parameter if using lazy constraints.
MOI.set(model, MOI.RawOptimizerAttribute("LazyConstraints"), 1)
MOI.set(model, Gurobi.CallbackFunction(), my_callback_function)
optimize!(model)

@test termination_status(model) == MOI.OPTIMAL
@test primal_status(model) == MOI.FEASIBLE_POINT
@test value(x) == 1
@test value(y) == 2

using Gurobi
using JuMP

# define a simple UC problem

n_u = 8
n_t = 4
U = collect(1:n_u) # num units
T = collect(1:n_t) # num time steps
p_g_min = round.(0.3rand(n_u), digits = 2)
p_g_max = 1 .+ round.(rand(n_u), digits = 2)
cost_g = 10 .+ round.(10.0rand(n_u), digits = 1)
cost_g0 = round.(3.0rand(n_u), digits = 1)
d0 = rand((sum(p_g_min):0.01:(0.5sum(p_g_max))), n_t)

# basic_uc_model = Model(Gurobi.Optimizer)
basic_uc_model = direct_model(Gurobi.Optimizer())
@variable(basic_uc_model, p_g[i in U, t in T])
@variable(basic_uc_model, I_g[i in U, t in T])
@constraint(basic_uc_model, lower_band[i in U, t in T], p_g[i, t]>=p_g_min[i] * I_g[i, t])
@constraint(basic_uc_model, upper_band[i in U, t in T], p_g[i, t]<=p_g_max[i] * I_g[i, t], base_name="upper_band_1")
@constraint(basic_uc_model, demand[t in T], sum(p_g[i, t] for i in U)==d0[t])
@objective(basic_uc_model, Min, sum(p_g[i, t] * cost_g[i] + I_g[i, t] * cost_g0[i] for i in U, t in T))

# @constraint(basic_uc_model, [i in U, t in T], p_g[i, t]>=p_g_min[i] * I_g[i, t], base_name="lower_band_1")

# @constraint(basic_uc_model, upper_band[i in U, t in T], p_g[i, t]<=p_g_max[i] * I_g[i, t])

# MOI.get(basic_uc_model, Gurobi.ConstraintAttribute("Slack"), upper_bound[2, 2]) #

optimize!(basic_uc_model)
JuMP.objective_value(basic_uc_model)
JuMP.value.(p_g)
JuMP.value.(I_g)

reduced_cost(p_g[1, 2])

MOI.get(basic_uc_model, Gurobi.ModelAttribute("ObjVal")) # Objective value for current solution
MOI.get(basic_uc_model, Gurobi.VariableAttribute("Obj"), p_g[2, 2]) # Linear objective coefficient
MOI.get(basic_uc_model, Gurobi.VariableAttribute("RC"), p_g[1, 4]) # Linear objective coefficient

MOI.get(basic_uc_model, Gurobi.ConstraintAttribute("Slack"), upper_band_1[1]) #

MOI.get(basic_uc_model, Gurobi.ConstraintAttribute("Slack"), lower_band[2, 2]) #
MOI.get(basic_uc_model, Gurobi.ConstraintAttribute("Pi"), upper_band[2, 2]) # Dual value (also known as the shadow price)

lldual_status(basic_uc_model)
JuMP.dual_status(basic_uc_model)  # MOI.NO_SOLUTION

# TODO - -----
using HiGHS
G = [0 3 2 2 0 0 0 0
	 0 0 0 0 5 1 0 0
	 0 0 0 0 1 3 1 0
	 0 0 0 0 0 1 0 0
	 0 0 0 0 0 0 0 4
	 0 0 0 0 0 0 0 2
	 0 0 0 0 0 0 0 4
	 0 0 0 0 0 0 0 0]
n = size(G, 1)
model = Model(HiGHS.Optimizer)
M = -sum(G)
set_silent(model)
@variable(model, x[1:n, 1:n], Bin)
@variable(model, θ>=M)
@constraint(model, sum(x)<=11)
@objective(model, Min, 0.1 * sum(x)+θ)
model

function solve_subproblem(x_bar)
	model = Model(HiGHS.Optimizer)
	set_silent(model)
	@variable(model, x[i in 1:n, j in 1:n]==x_bar[i, j])
	@variable(model, y[1:n, 1:n]>=0)
	@constraint(model, [i = 1:n, j = 1:n], y[i, j]<=G[i, j] * x[i, j])
	@constraint(model, [i = 2:(n - 1)], sum(y[i, :])==sum(y[:, i]))
	@objective(model, Min, -sum(y[1, :]))
	optimize!(model)
	assert_is_solved_and_feasible(model; dual = true)
	return (obj = objective_value(model), y = value.(y), π = reduced_cost.(x))
end

# NOTE ------
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

# Before calling optimize!
set_optimizer_attribute(model, "InfUnbdInfo", 1)
# Or potentially:
# set_optimizer_attribute(model, "Presolve", 0) # This disables presolve entirely

optimize!(model)
# ... rest of the status checking code

reduced_cost(x)

# ----------------

using JuMP
using Gurobi

# Example infeasible model
model = Model(Gurobi.Optimizer)

# --- Tell Gurobi to compute infeasibility information ---
# This parameter asks Gurobi to provide additional information (like Farkas duals)
# when the model is found to be infeasible or unbounded.
set_optimizer_attribute(model, "InfUnbdInfo", 1)

# Alternatively (usually less preferred, disables all presolve):
# set_optimizer_attribute(model, "Presolve", 0)

@variable(model, x >= 0)
@variable(model, y >= 0)

# Give constraints names to easily access their duals
@constraint(model, con1, x + y <= 1)
@constraint(model, con2, x + y >= 2)  # Infeasible constraint

@objective(model, Max, x + y)

# Solve the model
println("Optimizing...")
optimize!(model)
println("Optimization finished.")

# --- Always check status BEFORE accessing solution info ---
term_status = termination_status(model)
prim_status = primal_status(model)
dual_status = dual_status(model) # Crucial for infeasibility certificates

println("\n--- Status ---")
println("Termination Status: ", term_status)
println("Primal Status: ", prim_status)
println("Dual Status: ", dual_status)
println("--------------\n")

if term_status == MOI.OPTIMAL
    println("Model is Optimal.")
    println("Objective value: ", objective_value(model))
    println("Optimal x: ", value(x))
    println("Optimal y: ", value(y))
    # Reduced costs are meaningful here
    println("Reduced cost of x: ", reduced_cost(x))
    println("Reduced cost of y: ", reduced_cost(y))
    println("Shadow price of con1: ", shadow_price(con1))
    println("Shadow price of con2: ", shadow_price(con2))

elseif term_status == MOI.INFEASIBLE
    println("Model is Infeasible.")
    println("Cannot get reduced costs (no optimal primal solution).")

    # Check if the Farkas certificate (dual proof of infeasibility) is available
    if dual_status == MOI.INFEASIBILITY_CERTIFICATE
        println("Farkas dual certificate (infeasibility multipliers) is available:")
        try
            # Use shadow_price (or dual) on the CONSTRAINTS
            println("Farkas dual for con1 (x + y <= 1): ", shadow_price(con1))
            println("Farkas dual for con2 (x + y >= 2): ", shadow_price(con2))
            # Interpretation: A linear combination of the constraints using these
            # duals proves infeasibility.
            # For Ax <= b, find y >= 0 s.t. y'A = 0, y'b < 0
            # Our constraints:
            #  1*x + 1*y <= 1
            # -1*x - 1*y <= -2
            # Farkas duals y1, y2 >= 0
            # y1*(1, 1) + y2*(-1, -1) = (0, 0) => y1 - y2 = 0 => y1 = y2
            # y1*(1) + y2*(-2) < 0 => y1 - 2*y2 < 0 => y1 - 2*y1 < 0 => -y1 < 0 => y1 > 0
            # Expect certificate like (c, c) for c > 0, e.g., (1.0, 1.0)
        catch err
             println("Error accessing shadow price even though status seems correct: ", err)
        end
    else
        println("Farkas dual certificate not available (Dual Status: $dual_status).")
        println("Ensure 'InfUnbdInfo=1' or 'Presolve=0' was set BEFORE optimize!.")
    end

elseif term_status == MOI.DUAL_INFEASIBLE # (Which implies Primal Unbounded)
    println("Model is Unbounded (Dual Infeasible).")
    # Cannot get reduced costs or duals. Can sometimes get a primal ray.

else
    println("Solver finished with status: ", term_status)
    println("Solution information might not be available or meaningful.")
end