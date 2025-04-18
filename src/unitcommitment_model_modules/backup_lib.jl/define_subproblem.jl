"""
	bd_subfunction(NT, NB, NG, ND, NC, ND2, NS, NW, units, config_param)

This function defines the subproblem for the Bender's decomposition algorithm.

# Arguments
- `NT::Int64`: Number of time periods.
- `NB::Int64`: Number of buses.
- `NG::Int64`: Number of generators.
- `ND::Int64`: Number of loads.
- `NC::Int64`: Number of storage units.
- `ND2::Int64`: Number of data centers.
- `NS::Int64`: Number of scenarios.
- `NW::Int64`: Number of wind power plants.
- `units::unit`: Unit data structure.
- `config_param::config`: Configuration parameters.

# Returns
- `scuc_subproblem::Model`: The JuMP model for the subproblem.
"""
function bd_subfunction(
	NT::Int64, NB::Int64, NL::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NS::Int64, NW::Int64, units::unit, winds::wind,
	loads::load, lines::transmissionline, DataCentras::data_centra, psses::pss, scenarios_prob::Float64, config_param::config
)
	# println("this is the sub function of the bender decomposition process")
	# Δp_contingency = define_contingency_size(units, NG)
	scuc_subproblem = Model(Gurobi.Optimizer)
	set_silent(scuc_subproblem)
	# set_silent(scuc_subproblem)
	# --- Define Variables ---
	# Define decision variables for the optimization model
	define_subproblem_decision_variables!(
		scuc_subproblem::Model, NT, NG, ND, NC, ND2, NS, NW, config_param
	)

	# --- Set Objective ---
	# Set the objective function to be minimized
	set_subproblem_objective_economic!(
		scuc_subproblem::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob
	)

	# NS = winds.scenarios_nums
	# NW = length(winds.index)
	Gsdf = calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)

	# println("subject to.") # Indicate the start of constraint definitions
	onoffinit = calculate_initial_unit_status(units, NG)
	Δp_contingency = define_contingency_size(units, NG)

	# --- Add Constraints ---
	all_constr_sets = []
	# Add the constraints to the optimization model
	units_minuptime_constr, units_mindowntime_constr, units_init_stateslogic_consist_constr, units_states_consist_constr, units_init_shutup_cost_constr, units_init_shutdown_cost_costr, units_shutup_cost_constr,
	units_shutdown_cost_constr = add_unit_operation_constraints!(scuc_subproblem, NT, NG, units, onoffinit)
	winds_curt_constr, loads_curt_const = add_curtailment_constraints!(scuc_subproblem, NT, ND, NW, NS, loads, winds)
	units_minpower_constr, units_maxpower_constr = add_generator_power_constraints!(scuc_subproblem, NT, NG, NS, units)
	sys_upreserve_constr, sys_down_reserve_constr = add_reserve_constraints!(scuc_subproblem, NT, NG, NC, NS, units, loads, winds, config_param)
	sys_balance_constr = add_power_balance_constraints!(scuc_subproblem, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)
	units_upramp_constr, units_downramp_constr = add_ramp_constraints!(scuc_subproblem, NT, NG, NS, units, onoffinit)
	units_pwlpower_sum_constr, units_pwlblock_upbound_constr, units_pwlblock_dwbound_constr = add_pwl_constraints!(scuc_subproblem, NT, NG, NS, units)
	transmissionline_powerflow_upbound_constr, transmissionline_powerflow_downbound_constr = add_transmission_constraints!(
		scuc_subproblem, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, psses, Gsdf, config_param, ND2, DataCentras)
	# add_storage_constraints!(scuc_subproblem, NT, NC, NS, config_param, psses)
	# add_datacentra_constraints!(scuc_subproblem, NT, NS, config_param, ND2, DataCentras)
	# add_frequency_constraints!(scuc_subproblem, NT, NG, NC, NS, units, psses, config_param, Δp_contingency)
	# @show model_summary(scuc_subproblem)

	# @show typeof(units_minuptime_constr)
	# @show typeof(units_mindowntime_constr)
	# @show typeof(units_init_stateslogic_consist_constr)
	# @show typeof(units_states_consist_constr)
	# @show typeof(units_init_shutup_cost_constr)
	# @show typeof(units_init_shutdown_cost_costr)
	# @show typeof(units_shutup_cost_constr)
	# @show typeof(units_shutdown_cost_constr)

	# typeof(vec(sys_balance_constr[1])) <: AbstractVector

	all_constraints_dict = Dict{Symbol, Any}()

	# vec(units_init_stateslogic_consist_constr)
	# vec(units_states_consist_constr)
	# vec(units_init_shutup_cost_constr)
	# vec(units_init_shutdown_cost_costr)
	# vec(collect(Iterators.flatten(units_shutup_cost_constr.data)))
	# vec(collect(Iterators.flatten(units_shutdown_cost_constr.data)))
	# vec(winds_curt_constr)
	# vec(loads_curt_const)
	# vec(units_minpower_constr)
	# vec(units_maxpower_constr)
	# vec(sys_upreserve_constr)
	# vec(sys_down_reserve_constr)
	# vec(units_upramp_constr)
	# vec(units_downramp_constr)
	# vec(units_pwlpower_sum_constr)
	# vec(units_pwlblock_upbound_constr)
	# vec(units_pwlblock_dwbound_constr)
	# vec(transmissionline_powerflow_upbound_constr[1])
	# vec(transmissionline_powerflow_downbound_constr[1])
	# vec(convert_constraints_type_to_vector(sys_balance_constr))

	all_constraints_dict[:units_minuptime_constr] = vec(units_minuptime_constr)
	all_constraints_dict[:units_mindowntime_constr] = vec(units_mindowntime_constr)
	all_constraints_dict[:units_init_stateslogic_consist_constr] = vec(units_init_stateslogic_consist_constr)
	all_constraints_dict[:units_states_consist_constr] = vec(units_states_consist_constr)
	all_constraints_dict[:units_init_shutup_cost_constr] = vec(units_init_shutup_cost_constr)
	all_constraints_dict[:units_init_shutdown_cost_costr] = vec(units_init_shutdown_cost_costr)
	all_constraints_dict[:units_shutup_cost_constr] = vec(collect(Iterators.flatten(units_shutup_cost_constr.data)))
	all_constraints_dict[:units_shutdown_cost_constr] = vec(collect(Iterators.flatten(units_shutdown_cost_constr.data)))
	all_constraints_dict[:winds_curt_constr] = vec(collect(Iterators.flatten(winds_curt_constr)))
	all_constraints_dict[:loads_curt_const] = vec(collect(Iterators.flatten(loads_curt_const)))
	all_constraints_dict[:units_minpower_constr] = vec(collect(Iterators.flatten(units_minpower_constr)))
	all_constraints_dict[:units_maxpower_constr] = vec(collect(Iterators.flatten(units_maxpower_constr)))
	all_constraints_dict[:sys_upreserve_constr] = vec(sys_upreserve_constr)
	all_constraints_dict[:sys_down_reserve_constr] = vec(sys_down_reserve_constr)
	all_constraints_dict[:units_upramp_constr] = vec(collect(Iterators.flatten(units_upramp_constr)))
	all_constraints_dict[:units_downramp_constr] = vec(collect(Iterators.flatten(units_downramp_constr)))
	all_constraints_dict[:units_pwlpower_sum_constr] = vec(units_pwlpower_sum_constr)
	all_constraints_dict[:units_pwlblock_upbound_constr] = vec(units_pwlblock_upbound_constr)
	all_constraints_dict[:units_pwlblock_dwbound_constr] = vec(units_pwlblock_dwbound_constr)
	all_constraints_dict[:balance_constr] = vec(convert_constraints_type_to_vector(sys_balance_constr))
	all_constraints_dict[:transmissionline_powerflow_upbound_constr] = vec(transmissionline_powerflow_upbound_constr[1])
	all_constraints_dict[:transmissionline_powerflow_dwbound_constr] = vec(transmissionline_powerflow_downbound_constr[1])

	all_constr_lessthan_sets, all_constr_greaterthan_sets, all_constr_equalto_sets = reorginze_constraints_sets(all_constraints_dict)

	all_reorginzed_constraints_dict = Dict{Symbol, Any}()
	all_reorginzed_constraints_dict[:LessThan] = collect(Iterators.flatten(all_constr_lessthan_sets))
	all_reorginzed_constraints_dict[:GreaterThan] = collect(Iterators.flatten(all_constr_greaterthan_sets))
	all_reorginzed_constraints_dict[:EqualTo] = collect(Iterators.flatten(all_constr_equalto_sets))

	return scuc_subproblem, all_reorginzed_constraints_dict
end

function define_subproblem_decision_variables!(
	scuc_subproblem::Model,
	NT::Int64,
	NG::Int64,
	ND::Int64,
	NC::Int64,
	ND2::Int64,
	NS::Int64,
	NW::Int64,
	config_param::config
)
	# binary variables
	@variable(scuc_subproblem, x[1:NG, 1:NT])
	@variable(scuc_subproblem, u[1:NG, 1:NT])
	@variable(scuc_subproblem, v[1:NG, 1:NT])
	@variable(scuc_subproblem, su₀[1:NG, 1:NT] >= 0)
	@variable(scuc_subproblem, sd₀[1:NG, 1:NT] >= 0)

	# @variable(scuc_subproblem, θ[NG * NS, 1:NT]>=0)

	# continuous variables
	@variable(scuc_subproblem, pg₀[1:(NG * NS), 1:NT] >= 0)
	@variable(scuc_subproblem, pgₖ[1:(NG * NS), 1:NT, 1:3] >= 0)

	@variable(scuc_subproblem, sr⁺[1:(NG * NS), 1:NT] >= 0)
	@variable(scuc_subproblem, sr⁻[1:(NG * NS), 1:NT] >= 0)
	@variable(scuc_subproblem, Δpd[1:(ND * NS), 1:NT] >= 0)
	@variable(scuc_subproblem, Δpw[1:(NW * NS), 1:NT] >= 0)

	# pss variables
	if config_param.is_ConsiderBESS == 1
		@variable(scuc_subproblem, κ⁺[1:(NC * NS), 1:NT], Bin) # charge status
		@variable(scuc_subproblem, κ⁻[1:(NC * NS), 1:NT], Bin) # discharge status
		@variable(scuc_subproblem, pc⁺[1:(NC * NS), 1:NT] >= 0)# charge power
		@variable(scuc_subproblem, pc⁻[1:(NC * NS), 1:NT] >= 0)# discharge power
		@variable(scuc_subproblem, qc[1:(NC * NS), 1:NT] >= 0) # cumsum power
		# @variable(scuc_subproblem, pss_sumchargeenergy[1:NC * NS, 1] >= 0) # Currently commented out

		# defination charging and discharging of BESS
		@variable(scuc_subproblem, α[1:(NS * NC), 1:NT], Bin)
		@variable(scuc_subproblem, β[1:(NS * NC), 1:NT], Bin)
	end

	# if config_param.is_ConsiderDataCentra == 1
	# 	@variable(scuc_subproblem, dc_p[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc_subproblem, dc_f[1:(ND2 * NS), 1:NT]>=0)
	# 	# @variable(scuc_subproblem, dc_v[1:(ND2 * NS), 1:NT]>=0) # Currently commented out
	# 	@variable(scuc_subproblem, dc_v²[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc_subproblem, dc_λ[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc_subproblem, dc_Δu1[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc_subproblem, dc_Δu2[1:(ND2 * NS), 1:NT]>=0)
	# end

	# # Frequency control related variables (assuming these might be needed based on later constraints)
	# # Check if these are actually used/defined in the constraints file later
	# if config_param.is_ConsiderFrequencyControl == 1 # Assuming flag exists
	# 	@variable(scuc_subproblem, Δf_nadir[1:NS]>=0)
	# 	@variable(scuc_subproblem, Δf_qss[1:NS]>=0)
	# 	@variable(scuc_subproblem, Δp_imbalance[1:NS]>=0) # Placeholder, adjust as needed based on full constraints
	# end

	# println("\t Variables defined.")
	return scuc_subproblem # Return model with variables
end

function set_subproblem_objective_economic!(
	scuc_subproblem::Model,
	NT::Int64,
	NG::Int64,
	ND::Int64,
	NW::Int64,
	NS::Int64,
	units::unit,
	config_param::config,
	scenarios_prob)
	# Cost parameters
	c₀ = config_param.is_CoalPrice  # Base cost of coal
	pₛ = scenarios_prob  # Probability of scenarios
	# Penalty coefficients for load and wind curtailment
	load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

	# Constants for reserve cost (can be adjusted based on market conditions)
	RESERVE_COST_POSITIVE = 2 * c₀
	RESERVE_COST_NEGATIVE = 2 * c₀

	ρ⁺ = RESERVE_COST_POSITIVE
	ρ⁻ = RESERVE_COST_NEGATIVE

	x = scuc_subproblem[:x]
	su₀ = scuc_subproblem[:su₀]
	sd₀ = scuc_subproblem[:sd₀]
	pgₖ = scuc_subproblem[:pgₖ]
	sr⁺ = scuc_subproblem[:sr⁺]
	sr⁻ = scuc_subproblem[:sr⁻]
	Δpd = scuc_subproblem[:Δpd]
	Δpw = scuc_subproblem[:Δpw]

	# Linearize fuel cost curve (assuming function is in linearization.jl)
	refcost, eachslope = linearizationfuelcurve(units, NG)

	@objective(scuc_subproblem,
		Min,
		sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT) +
			pₛ * c₀ *
			(
				sum(
					sum(
						sum(sum(pgₖ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT))
						for s in 1:NS
					) for i in 1:NG
				) +
				sum(sum(sum(x[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS) +  # Assumes x is accessible
				sum(
					sum(
						sum(
							ρ⁺ * sr⁺[i + (s - 1) * NG, t] + ρ⁻ * sr⁻[i + (s - 1) * NG, t]
							for i in 1:NG
						) for t in 1:NT
					) for s in 1:NS
				)
			) +
			pₛ * load_curtailment_penalty * sum(sum(sum(Δpd[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS) +
			pₛ * wind_curtailment_penalty * sum(sum(sum(Δpw[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS))
	# println("objective_function")
	return println("\t MILP_type define_subproblem objective_function \t\t\t\t\t\t done")
end

