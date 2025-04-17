include(joinpath(pwd(), "src", "environment_config.jl"));
include(joinpath(pwd(), "src", "renewableresource_modules", "stochasticsimulation.jl"));
include(joinpath(pwd(), "src", "read_inputdata_modules", "readdatas.jl"));
include(joinpath(pwd(), "src", "unitcommitment_model_modules", "SUCuccommitmentmodel.jl"));

include("define_masterproblem.jl")
include("define_subproblem.jl")
include("benderdecomposition_module.jl")

# Destructure directly from function call for clarity
# Read data from Excel sheet

UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet();

# Form input data for the model
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, DataCentras = forminputdata(
	DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data);

# Generate wind scenarios
winds, NW = genscenario(WindsFreqParam, 1);

# Apply boundary conditions
boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, stroges);

# Run the SUC-SCUC model
# Define scenario probability (assuming equal probability)
scenarios_prob = 1.0 / winds.scenarios_nums;
@show NS = Int64(winds.scenarios_nums);

refcost, eachslope = linearizationfuelcurve(units, NG);
scuc_masterproblem = bd_masterfunction(NT, NB, NG, ND, NC, ND2, NS, units, config_param);
scuc_subproblem = bd_subfunction(
	NT::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NS::Int64, NW::Int64, units::unit, config_param::config)
# Create dual subproblem with all necessary parameters
# include("define_dual_subproblem.jl")

# scuc_subproblem = bd_dual_subfunction(NT, NB, NG, ND, NC, ND2, NS, NW, units, config_param)

# Make sure refcost and eachslope are defined before using them in the subproblem
if !@isdefined(scenarios_prob)
	println("Warning: scenarios_prob not defined, setting to default value")
	scenarios_prob = 1.0 / NS
end

# DEBUG - benderdecomposition_module

# First optimize the master problem
optimize!(scuc_masterproblem)

# duals = model.getAttr("Pi", model.getConstrs())

# Check solution status of master problem
try
	assert_is_solved_and_feasible(scuc_masterproblem)
	println("Master problem is solved and feasible")
catch e
	println("Error in master problem: ", e)
	error("Master problem failed to solve or is infeasible")
end

# Get lower bound from master problem
lower_bound = objective_function(scuc_masterproblem)

# Extract solution from master problem
@show x⁽⁰⁾ = value.(scuc_masterproblem[:x]) # Commitment decisions
@show u⁽⁰⁾ = value.(scuc_masterproblem[:u]) # Dispatch decisions
@show v⁽⁰⁾ = value.(scuc_masterproblem[:v]) # Voltage angle decisions

fix.(scuc_subproblem[:x], x⁽⁰⁾; force = true)
fix.(scuc_subproblem[:u], u⁽⁰⁾; force = true)
fix.(scuc_subproblem[:v], v⁽⁰⁾; force = true)

# x⁽⁰⁾ = ones(3, 24)
# Solve subproblem with feasibility cut
# ret = solve_subproblem_with_feasibility_cut(scuc_subproblem, x⁽⁰⁾, u⁽⁰⁾, v⁽⁰⁾)

# Fix variables in subproblem - using the broadcast fix method
# Note: This should work if dimensions match correctly
# Fix first-stage variables from master problem to subproblem
try
	# Fix binary commitment variables
	for i in 1:NG, t in 1:NT
		fix(scuc_subproblem[:x][i, t], value(scuc_masterproblem[:x][i, t]); force = true)
		fix(scuc_subproblem[:u][i, t], value(scuc_masterproblem[:u][i, t]); force = true)
		fix(scuc_subproblem[:v][i, t], value(scuc_masterproblem[:v][i, t]); force = true)
	end

	# Fix startup/shutdown cost variables
	for i in 1:NG, t in 1:NT
		fix(scuc_subproblem[:su₀][i, t], value(scuc_masterproblem[:su₀][i, t]); force = true)
		fix(scuc_subproblem[:sd₀][i, t], value(scuc_masterproblem[:sd₀][i, t]); force = true)
	end
	println("Successfully fixed all first-stage variables")
catch e
	println("Error fixing first-stage variables: ", e)
	error("Failed to fix first-stage variables from master to subproblem")
end

# @show fix_modelvariable(scuc_subproblem[:x], x⁽⁰⁾)
# function fix_modelvariable(x, x_copy)
# 	row_num, col_num = size(x_copy)
# 	for i in 1:row_num
# 		for j in 1:col_num
# 			fix(x[i, j], x_copy[i, j]; force = true)
# 		end
# 	end
# end

is_fixed.(scuc_subproblem[:x])

optimize!(scuc_subproblem)





dual(UpperBoundRef(scuc_subproblem[:x]))

# DEBUG - solver settings (only Gurobi for now)
set_optimizer(scuc_subproblem, solver)
set_optimizer_attribute(scuc_subproblem, "Method", 2)
set_optimizer_attribute(scuc_subproblem, "Crossover", 0)
set_optimizer_attribute(scuc_subproblem, "BarConvTol", opt_gap)
#set_optimizer_attribute(scuc_subproblem,"NumericFocus",2)

is_solved_and_feasible(scuc_subproblem; dual = true)
JuMP.set_optimizer(scuc_subproblem, Gurobi.Optimizer)
set_optimizer_attribute(scuc_subproblem, "Method", 2)
set_optimizer_attribute(scuc_subproblem, "Crossover", 0)
# set_optimizer_attribute(scuc_subproblem, "BarConvTol", opt_gap)

dual(UpperBoundRef(scuc_subproblem[:x]))

dual.(scuc_subproblem[:x])

# MOI.get(scuc_subproblem, Gurobi.ModelAttribute("ObjVal"))
MOI.get(scuc_subproblem, Gurobi.VariableAttribute("RC"), scuc_subproblem[:x][1, 1])

MOI.get(basic_uc_model, Gurobi.ModelAttribute("ObjVal")) # Objective value for current solution
MOI.get(basic_uc_model, Gurobi.VariableAttribute("Obj"), p_g[2, 2]) # Linear objective coefficient

MOI.get(basic_uc_model, Gurobi.ConstraintAttribute("Slack"), upper_band_1[1]) #

MOI.get(basic_uc_model, Gurobi.ConstraintAttribute("Slack"), lower_band[2, 2]) #
MOI.get(basic_uc_model, Gurobi.ConstraintAttribute("Pi"), upper_band[2, 2]) # Dual value (also known as the shadow price)

lldual_status(basic_uc_model)
JuMP.dual_status(basic_uc_model)  # MOI.NO_SOLUTION

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
		ray_v = reduced_cost.(scuc_subproblem[:v])
	)
end

JuMP.objective_value(basic_uc_model)

MOI.get(basic_uc_model, Gurobi.ModelAttribute("ObjVal")) # Objective value for current solution
MOI.get(basic_uc_model, Gurobi.VariableAttribute("Obj"), p_g[2, 2]) # Linear objective coefficient
MOI.get(basic_uc_model, Gurobi.ConstraintAttribute("Slack"), lower_band[2, 2]) #
MOI.get(basic_uc_model, Gurobi.ConstraintAttribute("Pi"), upper_band[2, 2]) # Dual value (also known as the shadow price)

dual_status(basic_uc_model)
JuMP.dual_status(basic_uc_model)  # MOI.NO_SOLUTION

# We should optimize the subproblem here, not the master problem again
optimize!(scuc_subproblem)
duals = scuc_subproblem.getAttr("Pi", MOI.getConstrs())

include("define_dual_subproblem.jl")
bd_dual_subfunction(
	NT::Int64,
	NB::Int64,
	NG::Int64,
	ND::Int64,
	NC::Int64,
	ND2::Int64,
	NS::Int64,
	NW::Int64,
	units::unit,
	config_param::config
)
optimize!(dual_subproblem)

# Optimize subproblem - we already did this above, no need to do it again
# optimize!(scuc_subproblem)

# Check if subproblem is solved and feasible
# Check if subproblem is solved and feasible

# Check master problem solution
master_status = termination_status(scuc_masterproblem)
println("Master problem status: ", master_status)
if master_status == MOI.OPTIMAL
	master_obj = objective_value(scuc_masterproblem)
	println("Master objective value: ", master_obj)
else
	error("Master problem failed to solve optimally: ", master_status)
end

# Check subproblem solution
sub_status = termination_status(scuc_subproblem)
println("Subproblem status: ", sub_status)
is_solved_and_feasible(scuc_subproblem; dual = true)

if sub_status == MOI.OPTIMAL
	# Get primal solution first
	sub_obj = objective_value(scuc_subproblem)
	println("Subproblem objective value: ", sub_obj)

	# Verify dual solutions are available
	if has_duals(scuc_subproblem)
		try
			# Attempt to get dual objective value
			dual_θ = dual_objective_value(scuc_subproblem)
			println("Dual objective value: ", dual_θ)

			# Get reduced costs for sensitivity
			ray_x = reduced_cost.(scuc_subproblem[:x])
			ray_u = reduced_cost.(scuc_subproblem[:u])
			ray_v = reduced_cost.(scuc_subproblem[:v])

			println("Successfully obtained dual information")
		catch e
			println("Error getting dual values: ", e)
			println("Proceeding with primal solution only")
		end
	else
		println("Warning: Dual solutions not available - check solver configuration")
	end

	println("Benders decomposition debug successful!")
else
	error("Subproblem failed to solve optimally: ", sub_status)
end
# ray_x = reduced_cost.(scuc_subproblem[:x]),
# ray_u = reduced_cost.(scuc_subproblem[:u]),
# ray_v = reduced_cost.(scuc_subproblem[:v]),

# if is_solved_and_feasible(scuc_subproblem; dual = true)
# 	# Return solution information
# 	return (
# 		is_feasible = true,
# 		θ = value.(scuc_subproblem[:θ]),
# 		# relaxed_x = value.(scuc_subproblem[:relaxed_x]), # commented out
# 		# relaxed_u = value.(scuc_subproblem[:relaxed_u]), # commented out
# 		# relaxed_v = value.(scuc_subproblem[:relaxed_v]), # commented out
# 		# relaxed_su₀ = value.(scuc_subproblem[:relaxed_su₀]), # commented out
# 		# relaxed_sd₀ = value.(scuc_subproblem[:relaxed_sd₀]), # commented out
# 		sr⁺ = value.(scuc_subproblem[:sr⁺]),
# 		sr⁻ = value.(scuc_subproblem[:sr⁻]),
# 		Δpd = value.(scuc_subproblem[:Δpd]),
# 		Δpw = value.(scuc_subproblem[:Δpw]),
# 		ray_x = reduced_cost.(scuc_subproblem[:x]),
# 		ray_u = reduced_cost.(scuc_subproblem[:u]),
# 		ray_v = reduced_cost.(scuc_subproblem[:v])
# 	)
# else
# 	# Return infeasibility information
# 	return (
# 		is_feasible = false,
# 		dual_θ = dual_objective_value(scuc_subproblem),
# 		ray_x = reduced_cost.(scuc_subproblem[:x]),
# 		ray_u = reduced_cost.(scuc_subproblem[:u]),
# 		ray_v = reduced_cost.(scuc_subproblem[:v])
# 	)
# end

using JuMP
using GLPK  # Or another solver of your choice

# Create a model with a solver
model = Model(GLPK.Optimizer)

# Define variables
@variable(model, x>=0)  # x is non-negative
@variable(model, y>=0)  # y is non-negative

# Define an objective
@objective(model, Min, x+y)

# Add constraints
@constraint(model, x + y==10)

# Fix the value of variable x to be 4
fix(x, 4; force = true)

# Solve the model
optimize!(model)

# Get the value of the variables
println("x: ", value(x))
println("y: ", value(y))
