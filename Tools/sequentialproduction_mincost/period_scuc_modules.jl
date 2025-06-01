using JuMP, Gurobi, Test, DelimitedFiles

#---------------------------------------------------------------------------------------------------
# Module Dependencies and Includes
#---------------------------------------------------------------------------------------------------

# Include necessary model components
include(joinpath(pwd(), "src", "environment_config.jl"));
include(joinpath(pwd(), "src/unitcommitment_model_modules", "constraints_lib", "constraints.jl"));
include(joinpath(pwd(), "src/unitcommitment_model_modules", "objectives_lib", "objections.jl"));
include(joinpath(pwd(), "src/unitcommitment_model_modules", "utilitie_modules_lib", "utilities.jl"));
include(joinpath(pwd(), "src/unitcommitment_model_modules", "tests_lib", "tests.jl"));
#---------------------------------------------------------------------------------------------------

"""
	SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL)

Stochastic Unit Commitment (SUC) model for power system optimization (Refactored & Modularized).

#NOTE -  Arguments
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
# NOTE - update boundary conditions
function update_boundary_conditions(
    interval_scheduling_id, NG::Int64, NT::Int64, units::unit, loads::load,
    winds::wind, results::Dict{String,Array{Float64}})

    # FIXME -  update generators parameter_value
    mini_units = deepcopy(units)
    if interval_scheduling_id != 1
        res_up, res_down = get_generators_upoff_durations(units, results["u₀"], results["v₀"], NG)
        # mini_units = deepcopy(units)
        mini_units.x_0 = results["x₀"][:, NT]
        mini_units.p_0 = results["p₀"][:, NT]
        mini_units.t_0 = res_up[:, 1]
        mini_units.t_1 = res_down[:, 1]
    end
    # onoffinit = calculate_initial_unit_status(mini_units, NG)

    from_time = (interval_scheduling_id - 1) * NT + 1
    to_time = interval_scheduling_id * NT
    # FIXME - update loads parameter_value
    mini_loads = deepcopy(loads)
    mini_loads.load_curve = loads.load_curve[:, from_time:to_time]

    # FIXME - update wind parameter_value
    mini_winds = deepcopy(winds)
    mini_winds.scenarios_curve = winds.scenarios_curve[:, from_time:to_time]

    return mini_units, mini_loads, mini_winds
end

function get_generators_upoff_durations(units, shutup_states, shutdown_states, NG)
    res_up, res_down = zeros(NG, 1), zeros(NG, 1)
    for i in 1:NG
        res_up[i, 1] = min(units.min_shutup_time[i, 1], findlast(x -> x > 0.5, shutup_states[i, :]))
        res_down[i, 1] = min(units.min_shutdown_time[i, 1], findlast(x -> x > 0.5, shutdown_states[i, :]))
    end
    res_up = convert(Matrix{Int64}, res_up)
    res_down = convert(Matrix{Int64}, res_down)
    return res_up, res_down
end

# NOTE - baseline UC function module
function each_period_scucmodel_modules(NT::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64,
    ND2::Int64, units::unit, loads::load,
    winds::wind, lines::transmissionline, DataCentras::data_centra, config_param::config,
    stroges::Any, scenarios_prob::Float64, NL::Int64, interval_scheduling_id::Int64, hydros::hydro, NH::Int64)
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
    # set_silent(scuc)
    # --- Define Variables ---
    # Define decision variables for the optimization model
    # define_decision_variables!(scuc, NT, NG, ND, NC, ND2, NS, NW, config_param)
    define_decision_variables!(scuc, NT, NG, ND, NC, ND2, NS, NW, NH, config_param)
    # --- Set Objective ---
    # Set the objective function to be minimized
    set_objective!(scuc, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)

    println("subject to.") # Indicate the start of constraint definitions

    # --- Add Constraints ---
    # Add the constraints to the optimization model
    add_unit_operation_constraints!(scuc, NT, NG, units, onoffinit)
    add_curtailment_constraints!(scuc, NT, ND, NW, NS, loads, winds)
    add_generator_power_constraints!(scuc, NT, NG, NS, units)
    add_reserve_constraints!(scuc, NT, NG, NC, NS, units, loads, winds, config_param)
    add_power_balance_constraints!(scuc, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)
    add_ramp_constraints!(scuc, NT, NG, NS, units, onoffinit)
    add_pwl_constraints!(scuc, NT, NG, NS, units)
    add_transmission_constraints!(scuc, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, stroges, Gsdf, config_param, ND2, DataCentras, hydros)
    add_storage_constraints!(scuc, NT, NC, NS, config_param, stroges)
    add_datacentra_constraints!(scuc, NT, NS, config_param, ND2, DataCentras)
    add_frequency_constraints!(scuc, NT, NG, NC, NS, units, stroges, config_param, Δp_contingency)
    add_hydros_constraints!(scuc::Model, NT, NH, NS, hydros)
    # --- Solve and Extract Results ---
    # Solve the optimization model and extract the results
    try
        # Attempt to solve the SCUC model
        results = solve_and_extract_results(
            scuc, NT, NG, ND, NC, NW, NS, ND2, NH, scenarios_prob, eachslope, refcost, config_param,
            interval_scheduling_id)

        # --- Return Results ---
        # Check if the optimization was successful
        if results !== nothing
            return results # Return the dictionary containing the optimization results
        else
            # Handle optimization failure
            println("Optimization failed, returning nothing.")
            return nothing
        end
    catch e
        # Catch any errors that occur during the optimization process
        println("An error occurred during optimization: ", e)
        return nothing
    end
end # end SUC_scucmodel function
