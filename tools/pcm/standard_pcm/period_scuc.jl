if !isdefined(@__MODULE__, :_PERIOD_SCUC_MODULES_INCLUDED)
    const _PERIOD_SCUC_MODULES_INCLUDED = true

    using JuMP, Test, DelimitedFiles

    #---------------------------------------------------------------------------------------------------
    # Module Dependencies and Includes
    #---------------------------------------------------------------------------------------------------

    include("../../../src/environment_config.jl")
    include("../../../src/unitcommitment_model_modules/constraints_lib/constraints.jl")
    include("../../../src/unitcommitment_model_modules/objectives_lib/objections.jl")
    include("../../../src/unitcommitment_model_modules/utilitie_modules_lib/utilities.jl")
    include("../../../src/unitcommitment_model_modules/tests_lib/tests.jl")
    include("../clustered_pcm/clustered_pcm.jl")
    const PCM_CLUSTER_ATTEMPTS = Ref(0)
    const PCM_CLUSTER_SUCCESSES = Ref(0)
    const PCM_CLUSTER_FALLBACKS = Ref(0)
    const PCM_CLUSTER_PREPROCESS_TIME_SEC = Ref(0.0)
    # 最近一次聚类主问题的真实整数变量数。与仅按 U/Y/Z 估算的
    # commitment 变量数分开记录，因为扩展凸包还包含状态流和出力弧变量。
    const PCM_CLUSTER_EXTENDED_INTEGER_VARIABLES = Ref(0)
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
            interval_scheduling_id, NG::Int64, NT::Int64, units::unit, loads::load, winds::wind, results::Dict{String, Array{Float64}})

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

    """Return consecutive on/off durations at the end of a committed window.

    `t_0` and `t_1` are elapsed-state durations, not remaining dwell times.  Keeping
    this meaning consistent is essential because the next UC window derives its
    mandatory initial residence period from `minimum_time - elapsed_duration`.
    """
    function get_generators_upoff_durations(units, shutup_states, shutdown_states, NG)
        res_up, res_down = zeros(Int64, NG, 1), zeros(Int64, NG, 1)
        NT_window = size(shutup_states, 2)
        for i ∈ 1:NG
            last_u = findlast(x -> x > 0.5, shutup_states[i, :])
            last_v = findlast(x -> x > 0.5, shutdown_states[i, :])

            if last_u === nothing && last_v === nothing
                # No startup/shutdown in this window: state didn't change
                if units.x_0[i] > 0.5
                    res_up[i, 1] = max(0, round(Int, units.t_0[i])) + NT_window
                    res_down[i, 1] = 0
                else
                    res_up[i, 1] = 0
                    res_down[i, 1] = max(0, round(Int, units.t_1[i])) + NT_window
                end
            elseif last_u !== nothing && (last_v === nothing || last_u > last_v)
                # Last event was a startup
                res_up[i, 1] = NT_window - last_u + 1
                res_down[i, 1] = 0
            else
                # Last event was a shutdown
                res_up[i, 1] = 0
                res_down[i, 1] = NT_window - last_v + 1
            end
        end
        return res_up, res_down
    end

    # NOTE - baseline UC function module
    function each_period_scucmodel_modules(NT::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, units::unit, loads::load,
            winds::wind, lines::transmissionline, DataCentras::data_centra, config_param::config, stroges::Any,
            scenarios_prob::Float64, NL::Int64, interval_scheduling_id::Int64, hydros::hydro, NH::Int64;
            formulation::Symbol = :environment)
        println("Step-3: Creating dispatching model (Refactored & Modularized)")

        # --- Input Validation ---
        if !validate_inputs(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL)
            error("Input validation failed. Check your data.")
        end

        # Two solution paths share the same data and rolling-window boundaries:
        # clustered master + physical disaggregation, or the original unit SCUC.
        # This switch therefore changes only the formulation used in the benchmark.
        formulation in (:environment, :standard, :clustered) ||
            throw(ArgumentError("Unsupported PCM formulation: $formulation"))
        clustered_enabled = formulation === :clustered ||
            (formulation === :environment && lowercase(get(ENV, "PCM_USE_CLUSTERED_UC", "false")) in ("1", "true", "yes", "on"))
        if clustered_enabled
            PCM_CLUSTER_ATTEMPTS[] += 1
            clustered_result=solve_true_clustered_pcm_window(NT, NB, NG, ND, units, loads, winds, lines, config_param, NL, hydros,
                NH; optimizer = pcm_optimizer())
            if clustered_result.feasible
                PCM_CLUSTER_SUCCESSES[] += 1
                println("  ✓ True clustered UC completed ($(length(clustered_result.clusters)) virtual units)")
                return clustered_result.results
            end
            # Never export an unverified aggregate schedule. The physical
            # disaggregation is the feasibility certificate for clustered PCM.
            println("  ⚠ True clustered UC failed at $(clustered_result.stage): $(clustered_result.message); falling back to full unit-network SCUC")
            PCM_CLUSTER_FALLBACKS[] += 1
            clustered_enabled=false
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
        scuc = Model(pcm_optimizer())
        if get(task_local_storage(), :is_sampling_running, false)
            set_silent(scuc)
        end
        if pcm_solver_name() == "gurobi"
            set_optimizer_attribute(scuc, "MIPGap", parse(Float64, get(ENV, "PCM_MIP_GAP", "0.015")))
            solver_threads = max(1, parse(Int, get(ENV, "PCM_SOLVER_THREADS", "16")))
            set_optimizer_attribute(scuc, "Threads", solver_threads)
            # 大规模算例可通过环境变量统一限制单个滚动窗口的求解时间。
            # 默认不设上限，以保持既有小规模算例的对外行为不变。
            solver_limit = tryparse(Float64, get(ENV, "PCM_SOLVER_TIME_LIMIT_SECONDS", ""))
            solver_limit !== nothing && solver_limit > 0 &&
                set_optimizer_attribute(scuc, "TimeLimit", solver_limit)
        else
            set_optimizer_attribute(scuc, "tm_lim", 4000)
            set_optimizer_attribute(scuc, "mip_gap", 0.015)
        end
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
        add_reserve_constraints!(scuc, NT, NG, NC, NS, units, loads, winds, config_param, hydros)
        add_power_balance_constraints!(scuc, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)
        add_ramp_constraints!(scuc, NT, NG, NS, units, onoffinit)
        add_pwl_constraints!(scuc, NT, NG, NS, units)
        if clustered_enabled
            println("\t constraints: 10) transmission limits deferred to unit disaggregation")
        else
            add_transmission_constraints!(
                scuc, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, stroges, Gsdf, config_param, ND2, DataCentras, hydros)
        end
        add_storage_constraints!(scuc, NT, NC, NS, config_param, stroges)
        add_datacentra_constraints!(scuc, NT, NS, config_param, ND2, DataCentras)
        add_frequency_constraints!(scuc, NT, NG, NC, NS, units, stroges, config_param, Δp_contingency)
        add_hydros_constraints!(scuc::Model, NT, NH, NS, hydros)
        # --- Solve and Extract Results ---
        # Solve the optimization model and extract the results
        try
            # Attempt to solve the SCUC model
            results = solve_and_extract_results(
                scuc, NT, NG, ND, NC, NW, NS, ND2, NH, scenarios_prob, eachslope, refcost, config_param, interval_scheduling_id)
            # --- Return Results ---
            # Check if the optimization was successful
            if results !== nothing
                if clustered_enabled
                    cluster_strict=lowercase(get(ENV, "PCM_CLUSTER_STRICT", "false")) in ("1", "true", "yes", "on")
                    clustered=apply_clustered_pcm_optimization!(
                        results, units, loads, winds, lines, config_param, NB, NL; optimizer = pcm_optimizer(),
                        strict = cluster_strict, stroges = stroges, data_centers = DataCentras, hydros = hydros)
                    clustered.feasible||error("Clustered PCM disaggregation failed at $(clustered.stage): $(clustered.feedback)")
                    if !clustered.network_feasible && config_param.is_NetWorkCon==1 && NL>0
                        println("  ↻ Network feedback: adding PTDF constraints and re-solving the current PCM window")
                        add_transmission_constraints!(
                            scuc, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, stroges, Gsdf, config_param, ND2, DataCentras, hydros)
                        results=solve_and_extract_results(
                            scuc, NT, NG, ND, NC, NW, NS, ND2, NH, scenarios_prob, eachslope, refcost, config_param, interval_scheduling_id)
                        results===nothing&&error("Network-feedback re-solve failed")
                        repaired_clusters=build_pcm_clusters(units)
                        results["cluster_ids"]=Float64.([only(c.id for c ∈ repaired_clusters if i in c.unit_indices) for i ∈ 1:NG])
                        results["cluster_disaggregation_feasible"]=ones(Float64, NS, 1)
                        clustered=(feasible = true, strictly_feasible = true, network_feasible = true, stage = :network_feedback_repaired,
                            clusters = repaired_clusters, checks = clustered.checks, results = nothing, feedback = nothing)
                    end
                    println("  ✓ Clustered UC residence/network disaggregation completed ($(length(clustered.clusters)) clusters, stage=$(clustered.stage))")
                end
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
end # end guard _PERIOD_SCUC_MODULES_INCLUDED
