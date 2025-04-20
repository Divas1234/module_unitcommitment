include(joinpath(pwd(), "src", "environment_config.jl"))
include(joinpath(pwd(), "src", "unitcommitment_model_modules", "SUCuccommitmentmodel.jl"))

function bd_masterfunction(
	NT::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NS::Int64, units::unit, config_param::config, scenarios_prob::Float64)
	println("this is the master function of the bender decomposition process")
	Δp_contingency = define_contingency_size(units, NG)
	scuc_masterproblem = Model(Gurobi.Optimizer)
	set_silent(scuc_masterproblem)

	# set_silent(scuc_masterproblem)
	# --- Define Variables ---
	# Define decision variables for the optimization model
	scuc_masterproblem, x, u, v, su₀, sd₀, θ = define_masterproblem_decision_variables!(
		scuc_masterproblem::Model, NT, NG, ND, NC, ND2, NS, NW, config_param)
	pg₀ = sr⁺ = sr⁻ = Δpd = Δpw = κ⁺ = κ⁻ = pc⁺ = pc⁻ = qc = pss_sumchargeenergy = α = β = Matrix{VariableRef}(undef, 0, 0)
	pgₖ = Array{VariableRef, 3}(undef, 0, 0, 0)
	# NOTE - save the decision variables in a dictionary for easy access
	# master_vars = SCUCModel_decision_variables(u, x, v, su₀, sd₀, pg₀, pgₖ, sr⁺, sr⁻, Δpd, Δpw, κ⁺, κ⁻, pc⁺, pc⁻, qc, pss_sumchargeenergy, α, β, θ)
	master_vars = build_decision_variables(; u, x, v, su₀, sd₀)

	# --- Set Objective ---
	# Set the objective function to be minimized
	scuc_masterproblem, obj = set_masterproblem_objective_economic!(
		scuc_masterproblem::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob)
	# NOTE - save the objective function in a dictionary for easy access
	master_obj = SCUCModel_objective_function(obj)

	# println("subject to.") # Indicate the start of constraint definitions

	# M = 1e3
	all_constr_sets = []
	onoffinit = calculate_initial_unit_status(units, NG)

	# --- Add Constraints ---
	# Add the constraints to the optimization model
	scuc_masterproblem, _units_minuptime_constr, _units_mindowntime_constr, _units_init_stateslogic_consist_constr, _units_states_consist_constr, _units_init_shutup_cost_constr, _units_init_shutdown_cost_constr, _units_shutup_cost_constr,
	_units_shutdown_cost_constr = add_unit_operation_constraints!(scuc_masterproblem, NT, NG, units, onoffinit)
	# add_curtailment_constraints!(scuc_masterproblem, NT, ND, NW, NS, loads, winds)
	# add_generator_power_constraints!(scuc_masterproblem, NT, NG, NS, units)
	# add_reserve_constraints!(scuc_masterproblem, NT, NG, NC, NS, units, loads, winds, config_param)
	# add_power_balance_constraints!(scuc_masterproblem, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)
	# add_ramp_constraints!(scuc_masterproblem, NT, NG, NS, units, onoffinit)
	# add_pwl_constraints!(scuc_masterproblem, NT, NG, NS, units)
	# add_transmission_constraints!(scuc_masterproblem, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, stroges, Gsdf, config_param, ND2, DataCentras)
	# add_storage_constraints!(scuc_masterproblem, NT, NC, NS, config_param, stroges)
	# add_datacentra_constraints!(scuc_masterproblem, NT, NS, config_param, ND2, DataCentras)
	# add_frequency_constraints!(scuc_masterproblem, NT, NG, NC, NS, units, stroges, config_param, Δp_contingency)

	println("\n")
	@show scuc_masterproblem
	println("\n")

	all_constraints_dict = Dict{Symbol, Any}()
	all_constraints_dict[:key_units_minuptime_constr] = vec(_units_minuptime_constr)
	all_constraints_dict[:key_units_mindowntime_constr] = vec(_units_mindowntime_constr)
	all_constraints_dict[:key_units_init_stateslogic_consist_constr] = vec(_units_init_stateslogic_consist_constr)
	all_constraints_dict[:key_units_states_consist_constr] = vec(_units_states_consist_constr)
	all_constraints_dict[:key_units_init_shutup_cost_constr] = vec(_units_init_shutup_cost_constr)
	all_constraints_dict[:key_units_init_shutdown_cost_constr] = vec(_units_init_shutdown_cost_constr)
	all_constraints_dict[:key_units_shutup_cost_constr] = vec(collect(Iterators.flatten(_units_shutup_cost_constr.data)))
	all_constraints_dict[:key_units_shutdown_cost_constr] = vec(collect(Iterators.flatten(_units_shutdown_cost_constr.data)))

	fields = [Symbol(string(k)[5:end]) for k in keys(all_constraints_dict) if startswith(string(k), "key_")]
	master_cons = build_constraints(; (
		f => all_constraints_dict[Symbol("key_", f)]
		for f in fields
	)...)

	all_constr_lessthan_sets, all_constr_greaterthan_sets, all_constr_equalto_sets = reorginze_constraints_sets(all_constraints_dict)

	all_reorginzed_constraints_dict = Dict{Symbol, Any}()
	all_reorginzed_constraints_dict[:LessThan] = collect(Iterators.flatten(all_constr_lessthan_sets))
	all_reorginzed_constraints_dict[:GreaterThan] = collect(Iterators.flatten(all_constr_greaterthan_sets))
	all_reorginzed_constraints_dict[:EqualTo] = collect(Iterators.flatten(all_constr_equalto_sets))

	# NOTE - save the reformated constraints in a dictionary for easy access
	master_reformat_cons = SCUCModel_reformat_constraints(
		[vec(all_reorginzed_constraints_dict[key])
		 for key in [
			:EqualTo, :GreaterThan, :LessThan
		]]...
	)

	# NOTE - save all scuc model components in struct! SCUC_model
	master_scuc_struct = SCUC_Model(
		scuc_masterproblem::Model,
		master_vars::SCUCModel_decision_variables,
		master_obj::SCUCModel_objective_function,
		master_cons::SCUCModel_constraints,
		master_reformat_cons::SCUCModel_reformat_constraints
	)

	return scuc_masterproblem, master_scuc_struct
end

# Helper function to define model variables
function define_masterproblem_decision_variables!(scuc_masterproblem::Model, NT, NG, ND, NC, ND2, NS, NW, config_param)
	# binary variables
	@variable(scuc_masterproblem, x[1:NG, 1:NT], Bin)
	@variable(scuc_masterproblem, u[1:NG, 1:NT], Bin)
	@variable(scuc_masterproblem, v[1:NG, 1:NT], Bin)

	# continuous variables
	# @variable(scuc_masterproblem, pg₀[1:(NG * NS), 1:NT]>=0)
	# @variable(scuc_masterproblem, pgₖ[1:(NG * NS), 1:NT, 1:3]>=0)
	@variable(scuc_masterproblem, su₀[1:NG, 1:NT] >= 0)
	@variable(scuc_masterproblem, sd₀[1:NG, 1:NT] >= 0)

	@variable(scuc_masterproblem, θ >= 1e2)

	# @variable(scuc_masterproblem, pg[1:(NG * NS), 1:NT]>=0)
	# @variable(scuc_masterproblem, sr⁺[1:(NG * NS), 1:NT]>=0)
	# @variable(scuc_masterproblem, sr⁻[1:(NG * NS), 1:NT]>=0)
	# @variable(scuc_masterproblem, Δpd[1:(ND * NS), 1:NT]>=0)
	# @variable(scuc_masterproblem, Δpw[1:(NW * NS), 1:NT]>=0)

	# pss variables
	# @variable(scuc_masterproblem, κ⁺[1:(NC * NS), 1:NT], Bin) # charge status
	# @variable(scuc_masterproblem, κ⁻[1:(NC * NS), 1:NT], Bin) # discharge status
	# @variable(scuc_masterproblem, pc⁺[1:(NC * NS), 1:NT]>=0)# charge power
	# @variable(scuc_masterproblem, pc⁻[1:(NC * NS), 1:NT]>=0)# discharge power
	# @variable(scuc_masterproblem, qc[1:(NC * NS), 1:NT]>=0) # cumsum power
	# # @variable(scuc_masterproblem, pss_sumchargeenergy[1:NC * NS, 1] >= 0) # Currently commented out

	# # defination charging and discharging of BESS
	# @variable(scuc_masterproblem, α[1:(NS * NC), 1:NT], Bin)
	# @variable(scuc_masterproblem, β[1:(NS * NC), 1:NT], Bin)

	# if config_param.is_ConsiderDataCentra == 1
	# 	@variable(scuc_masterproblem, dc_p[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc_masterproblem, dc_f[1:(ND2 * NS), 1:NT]>=0)
	# 	# @variable(scuc_masterproblem, dc_v[1:(ND2 * NS), 1:NT]>=0) # Currently commented out
	# 	@variable(scuc_masterproblem, dc_v²[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc_masterproblem, dc_λ[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc_masterproblem, dc_Δu1[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc_masterproblem, dc_Δu2[1:(ND2 * NS), 1:NT]>=0)
	# end

	# # Frequency control related variables (assuming these might be needed based on later constraints)
	# # Check if these are actually used/defined in the constraints file later
	# if config_param.is_ConsiderFrequencyControl == 1 # Assuming flag exists
	# 	@variable(scuc_masterproblem, Δf_nadir[1:NS]>=0)
	# 	@variable(scuc_masterproblem, Δf_qss[1:NS]>=0)
	# 	@variable(scuc_masterproblem, Δp_imbalance[1:NS]>=0) # Placeholder, adjust as needed based on full constraints
	# end

	# println("\t Variables defined.")
	return scuc_masterproblem, x, u, v, su₀, sd₀, θ
end

function set_masterproblem_objective_economic!(scuc_masterproblem::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob)
	# Cost parameters
	c₀ = config_param.is_CoalPrice  # Base cost of coal
	# pₛ = scenarios_prob  # Probability of scenarios

	# Penalty coefficients for load and wind curtailment
	load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

	ρ⁺ = c₀ * 2
	ρ⁻ = c₀ * 2

	x = scuc_masterproblem[:x]
	su₀ = scuc_masterproblem[:su₀]
	sd₀ = scuc_masterproblem[:sd₀]
	θ = scuc_masterproblem[:θ]
	# pgₖ = scuc_masterproblem[:pgₖ]
	# sr⁺ = scuc_masterproblem[:sr⁺]
	# sr⁻ = scuc_masterproblem[:sr⁻]
	# Δpd = scuc_masterproblem[:Δpd]
	# Δpw = scuc_masterproblem[:Δpw]

	# @objective(scuc_masterproblem,
	# 	Min,
	# 	sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT) + pₛ * c₀ * sum(sum(sum(θ[((s - 1) * NG + 1):(s * NG), t] for t in 1:NT) for s in 1:NS)))
	obj = @objective(scuc_masterproblem,
		Min,
		sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG)
			for t in 1:NT) + c₀ * θ)

	println("\t MILP_type objective_function \t\t\t\t\t\t done")
	return scuc_masterproblem, obj
end
