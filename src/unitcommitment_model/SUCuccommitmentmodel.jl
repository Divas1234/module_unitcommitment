using JuMP, Gurobi, Test, DelimitedFiles

#---------------------------------------------------------------------------------------------------
# Module Dependencies and Includes
#---------------------------------------------------------------------------------------------------

# Include necessary model components
include("constraints_lib/constraints.jl")
include("objectives_lib/objections.jl")
include("utilitie_modules_lib/utilities.jl")
include("tests_lib/tests.jl")

#---------------------------------------------------------------------------------------------------
# Main Model Function
#---------------------------------------------------------------------------------------------------

"""
	SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL)

Stochastic Unit Commitment (SUC) model for power system optimization (Refactored & Modularized).

# Arguments
- `NT::Int64`: Number of time periods
- `NB::Int64`: Number of buses
- `NG::Int64`: Number of generators
- `ND::Int64`: Number of demands/loads
- `NC::Int64`: Number of energy storage units
- `ND2::Int64`: Number of data centers
- `units::unit`: Generator unit data
- `loads::load`: Load data
- `winds::wind`: Wind generation data
- `lines::transmissionline`: Transmission line data
- `DataCentras::data_centra`: Data center data
- `config_param::config`: Configuration parameters
- `stroges::Any`: Storage system data (Type Any for flexibility, consider defining a specific struct)
- `scenarios_prob::Float64`: Probability of scenarios (Assumed equal for now if calculated as 1/NS)
- `NL::Int64`: Number of transmission lines

# Returns
- Dictionary containing optimization results, or nothing if optimization fails.
"""
function SUC_scucmodel(
		NT::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, units::unit, loads::load,
		winds::wind, lines::transmissionline, DataCentras::data_centra, config_param::config,
		stroges::Any, scenarios_prob::Float64, NL::Int64)
	println("Step-3: Creating dispatching model (Refactored & Modularized)")

	# --- Input Validation ---
	if !validate_inputs(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines,
		DataCentras, config_param, stroges, scenarios_prob, NL)
		error("Input validation failed. Check your data.")
	end

	# --- Initialization ---
	NS = winds.scenarios_nums
	NW = length(winds.index)
	Gsdf = calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)

	# Linearize fuel cost curve (assuming function is in linearization.jl)
	refcost, eachslope = linearizationfuelcurve(units, NG)

	onoffinit = calculate_initial_unit_status(units, NG)

	# --- Model Creation ---
	Δp_contingency = define_contingency_size(units, NG)
	scuc = Model(Gurobi.Optimizer)

	# --- Define Variables ---
	# Define decision variables for the optimization model
	define_decision_variables!(scuc, NT, NG, ND, NC, ND2, NS, NW, config_param)

	# --- Set Objective ---
	# Define the objective function to be minimized
	set_objective!(
		scuc, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)

	println("subject to.") # Indicate the start of constraint definitions

	# --- Add Constraints ---
	# Add the constraints to the optimization model
	add_unit_operation_constraints!(scuc, NT, NG, units, onoffinit)
	add_curtailment_constraints!(scuc, NT, ND, NW, NS, loads, winds)
	add_generator_power_constraints!(scuc, NT, NG, NS, units)
	add_reserve_constraints!(scuc, NT, NG, NC, NS, units, loads, winds, config_param)
	add_power_balance_constraints!(scuc, NT, NG, ND, NC, NW, NS, ND2, loads, winds, config_param)
	add_ramp_constraints!(scuc, NT, NG, NS, units, onoffinit)
	add_pwl_constraints!(scuc, NT, NG, NS, units)

	if config_param.is_NetWorkCon == 1 && Gsdf !== nothing && NL > 0
		add_transmission_constraints!(
			scuc, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, stroges, Gsdf)
	else
		println("\t constraints: 10) transmissionline limits skipped (is_NetWorkCon != 1 or Gsdf missing or NL=0)")
	end

	# Pass stroges explicitly
	add_storage_constraints!(scuc, NT, NC, NS, stroges)

	if config_param.is_ConsiderDataCentra == 1
		add_datacentra_constraints!(scuc, NT, ND2, NS, DataCentras)
	else
		println("\t constraints: 12) data centra constraints skipped (is_ConsiderDataCentra != 1)")
	end

	# Check for frequency control flag before adding constraints
	if config_param.is_ConsiderFrequencyControl == 1 # Use get for safety
		add_frequency_constraints!(
			scuc, NT, NG, NC, NS, units, stroges, config_param, Δp_contingency)
	else
		println("\t constraints: 13) frequency control constraints skipped (is_ConsiderFrequencyControl != 1)")
	end

	# --- Solve and Extract Results ---
	# Solve the optimization model and extract the results
	try
		results = solve_and_extract_results(scuc, NT, NG, ND, NC, NW, NS, ND2, scenarios_prob,eachslope, refcost, config_param)

		# --- Return Results ---
		# Return the optimization results
		if results !== nothing
			return results # Return the dictionary
		else
			# Handle optimization failure
			println("Optimization failed, returning nothing.")
			return nothing
		end
	catch e
		println("An error occurred during optimization: ", e)
		return nothing
	end
end # end SUC_scucmodel function
