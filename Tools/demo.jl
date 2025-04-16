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
