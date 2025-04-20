"""
	bd_subfunction(NT, NB, NG, ND, NC, ND2, NS, NW, units, config_param)

This function defines the subproblem for the Bender's decomposition algorithm. It formulates a Security-Constrained Unit Commitment (SCUC) subproblem.

# Arguments
- `NT::Int64`: Number of time periods.
- `NB::Int64`: Number of buses.
- `NG::Int64`: Number of generators.
- `ND::Int64`: Number of loads.
- `NC::Int64`: Number of storage units.
- `ND2::Int64`: Number of data centers.
- `NS::Int64`: Number of scenarios.
- `NW::Int64`: Number of wind power plants.
- `units::unit`: Unit data structure containing generator parameters.
- `winds::wind`: Wind power data structure.
- `loads::load`: Load data structure.
- `lines::transmissionline`: Transmission line data structure.
- `DataCentras::data_centra`: Data center data structure.
- `psses::pss`: Pumped storage system data structure.
- `scenarios_prob::Float64`: Probability of each scenario.
- `config_param::config`: Configuration parameters.

# Returns
- `scuc_subproblem::Model`: The JuMP model for the subproblem.
- `all_reorginzed_constraints_dict::Dict{Symbol, Any}`: A dictionary containing all constraints, reorganized by type.
"""

function bd_subfunction(
		NT::Int64, NB::Int64, NL::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NS::Int64, NW::Int64,
		units::unit, winds::wind, loads::load, lines::transmissionline, DataCentras::data_centra, psses::pss,
		scenarios_prob::Float64, config_param::config
)
	# Input validation
	@assert NT>0 "Number of time periods (NT) must be positive."
	@assert NB>0 "Number of buses (NB) must be positive."
	@assert NG>0 "Number of generators (NG) must be positive."
	@assert ND>=0 "Number of loads (ND) must be non-negative."
	@assert NC>=0 "Number of storage units (NC) must be non-negative."
	@assert ND2>=0 "Number of data centers (ND2) must be non-negative."
	@assert NS>0 "Number of scenarios (NS) must be positive."
	@assert NW>=0 "Number of wind power plants (NW) must be non-negative."
	@assert scenarios_prob >= 0&&scenarios_prob <= 1 "Scenario probability must be between 0 and 1."

	# Create the subproblem model
	scuc_subproblem = Model(Gurobi.Optimizer)
	set_silent(scuc_subproblem)

	# Define decision variables
	scuc_subproblem, x, u, v, su₀, sd₀, pg₀, pgₖ, sr⁺, sr⁻, Δpd, Δpw, κ⁺, κ⁻, pc⁺, pc⁻, qc, pss_sumchargeenergy, α, β = define_subproblem_decision_variables!(
		scuc_subproblem, NT, NG, ND, NC, ND2, NS, NW, config_param
	)
	θ = Matrix{VariableRef}(undef, 0, 0)
	# NOTE - save the decision variables in a dictionary for easy access
	sub_vars = SCUCModel_decision_variables(u, x, v, su₀, sd₀, pg₀, pgₖ, sr⁺, sr⁻, Δpd, Δpw, κ⁺, κ⁻, pc⁺, pc⁻, qc, pss_sumchargeenergy, α, β,θ)

	# Set the objective function
	scuc_subproblem, obj = set_subproblem_objective_economic!(scuc_subproblem, NT, NG, ND, NW, NS, units, config_param, scenarios_prob)
	# @show typeof(obj)
	# NOTE - save the objective function in a dictionary for easy access
	sub_obj = SCUCModel_objective_function(obj)

	# Calculate the Generator Shift Distribution Factor (GSDF)
	gsdf = calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)

	# Calculate initial unit status
	onoffinit = calculate_initial_unit_status(units, NG)

	# Define contingency size
	contingency_size = define_contingency_size(units, NG)

	NS_copy = (config_param.is_ConsiderMultiCUTs == 1) ? NS : Int64(1)

	scuc_subproblem, _units_minuptime_constr, _units_mindowntime_constr, _units_init_stateslogic_consist_constr, _units_states_consist_constr,
	_units_init_shutup_cost_constr, _units_init_shutdown_cost_costr, _units_shutup_cost_constr, _units_shutdown_cost_constr = add_unit_operation_constraints!(
		scuc_subproblem, NT, NG, units, onoffinit)# Add unit operation constraints
	scuc_subproblem, _winds_curt_constr, _loads_curt_const = add_curtailment_constraints!(scuc_subproblem, NT, ND, NW, NS_copy, loads, winds)# Add curtailment constraints for wind and loads
	scuc_subproblem, _units_minpower_constr, _units_maxpower_constr = add_generator_power_constraints!(scuc_subproblem, NT, NG, NS_copy, units)# Add generator power constraints
	scuc_subproblem, _sys_upreserve_constr, _sys_down_reserve_constr = add_reserve_constraints!(
		scuc_subproblem, NT, NG, NC, NS_copy, units, loads, winds, config_param)# Add reserve constraints
	scuc_subproblem, _sys_balance_constr = add_power_balance_constraints!(
		scuc_subproblem, NT, NG, ND, NC, NW, NS_copy, loads, winds, config_param, ND2)# Add power balance constraints
	scuc_subproblem, _units_upramp_constr, _units_downramp_constr = add_ramp_constraints!(scuc_subproblem, NT, NG, NS_copy, units, onoffinit)# Add ramp constraints
	scuc_subproblem, _units_pwlpower_sum_constr, _units_pwlblock_upbound_constr, _units_pwlblock_dwbound_constr = add_pwl_constraints!(
		scuc_subproblem, NT, NG, NS_copy, units)# Add piecewise linear constraints
	scuc_subproblem, _transmissionline_powerflow_upbound_constr, _transmissionline_powerflow_downbound_constr = add_transmission_constraints!(
		scuc_subproblem, NT, NG, ND, NC, NW, NL, NS_copy, units, loads, winds, lines, psses, gsdf, config_param, ND2, DataCentras)# Add transmission constraints
	# add_storage_constraints!(scuc_subproblem, NT, NC, NS, config_param, psses)
	# add_datacentra_constraints!(scuc_subproblem, NT, NS, config_param, ND2, DataCentras)
	# add_frequency_constraints!(scuc_subproblem, NT, NG, NC, NS, units, psses, config_param, contingency_size)
	# @show model_summary(scuc_subproblem)

	println("\n")
	@show scuc_subproblem
	println("\n")

	all_constraints_dict = Dict{Symbol, Any}()

	all_constraints_dict[:key_units_minuptime_constr] = vec(_units_minuptime_constr)
	all_constraints_dict[:key_units_mindowntime_constr] = vec(_units_mindowntime_constr)
	all_constraints_dict[:key_units_init_stateslogic_consist_constr] = vec(_units_init_stateslogic_consist_constr)
	all_constraints_dict[:key_units_states_consist_constr] = vec(_units_states_consist_constr)
	all_constraints_dict[:key_units_init_shutup_cost_constr] = vec(_units_init_shutup_cost_constr)
	all_constraints_dict[:key_units_init_shutdown_cost_costr] = vec(_units_init_shutdown_cost_costr)
	all_constraints_dict[:key_units_shutup_cost_constr] = vec(collect(Iterators.flatten(_units_shutup_cost_constr.data)))
	all_constraints_dict[:key_units_shutdown_cost_constr] = vec(collect(Iterators.flatten(_units_shutdown_cost_constr.data)))
	all_constraints_dict[:key_winds_curt_constr] = vec(collect(Iterators.flatten(_winds_curt_constr)))
	all_constraints_dict[:key_loads_curt_const] = vec(collect(Iterators.flatten(_loads_curt_const)))
	all_constraints_dict[:key_units_minpower_constr] = vec(collect(Iterators.flatten(_units_minpower_constr)))
	all_constraints_dict[:key_units_maxpower_constr] = vec(collect(Iterators.flatten(_units_maxpower_constr)))
	all_constraints_dict[:key_sys_upreserve_constr] = vec(_sys_upreserve_constr)
	all_constraints_dict[:key_sys_down_reserve_constr] = vec(_sys_down_reserve_constr)
	all_constraints_dict[:key_units_upramp_constr] = vec(collect(Iterators.flatten(_units_upramp_constr)))
	all_constraints_dict[:key_units_downramp_constr] = vec(collect(Iterators.flatten(_units_downramp_constr)))
	all_constraints_dict[:key_units_pwlpower_sum_constr] = vec(_units_pwlpower_sum_constr)
	all_constraints_dict[:key_units_pwlblock_upbound_constr] = vec(_units_pwlblock_upbound_constr)
	all_constraints_dict[:key_units_pwlblock_dwbound_constr] = vec(_units_pwlblock_dwbound_constr)
	all_constraints_dict[:key_balance_constr] = vec((_sys_balance_constr[1]))
	# all_constraints_dict[:balance_constr] = vec(convert_constraints_type_to_vector(sys_balance_constr))
	all_constraints_dict[:key_transmissionline_powerflow_upbound_constr] = vec(_transmissionline_powerflow_upbound_constr[1])
	all_constraints_dict[:key_transmissionline_powerflow_downbound_constr] = vec(_transmissionline_powerflow_downbound_constr[1])

	# NOTE - save the constraints in a dictionary for easy access
	sub_cons = SCUCModel_constraints(
		[vec(all_constraints_dict[key])
		 for key in [
		:key_units_minuptime_constr, :key_units_mindowntime_constr,
		:key_units_init_stateslogic_consist_constr, :key_units_states_consist_constr,
		:key_units_init_shutup_cost_constr, :key_units_init_shutdown_cost_costr,
		:key_units_shutup_cost_constr, :key_units_shutdown_cost_constr,
		:key_winds_curt_constr, :key_loads_curt_const,
		:key_units_minpower_constr, :key_units_maxpower_constr,
		:key_sys_upreserve_constr, :key_sys_down_reserve_constr,
		:key_units_upramp_constr, :key_units_downramp_constr,
		:key_units_pwlpower_sum_constr, :key_units_pwlblock_upbound_constr,
		:key_units_pwlblock_dwbound_constr, :key_balance_constr,
		:key_transmissionline_powerflow_upbound_constr, :key_transmissionline_powerflow_downbound_constr
	]]...
	)

	all_constr_lessthan_sets, all_constr_greaterthan_sets, all_constr_equalto_sets = reorginze_constraints_sets(all_constraints_dict)

	all_reorginzed_constraints_dict = Dict{Symbol, Any}()
	all_reorginzed_constraints_dict[:LessThan] = collect(Iterators.flatten(all_constr_lessthan_sets))
	all_reorginzed_constraints_dict[:GreaterThan] = collect(Iterators.flatten(all_constr_greaterthan_sets))
	all_reorginzed_constraints_dict[:EqualTo] = collect(Iterators.flatten(all_constr_equalto_sets))

	# NOTE - save the reformated constraints in a dictionary for easy access
	sub_reformat_cons = SCUCModel_reformat_constraints(
		[vec(all_reorginzed_constraints_dict[key])
		 for key in [
		:EqualTo, :GreaterThan, :LessThan
	]]...
	)

	# NOTE - save all scuc model components in struct! SCUC_model
	sub_scuc_struct = SCUC_Model(
		scuc_subproblem::Model,
		sub_vars::SCUCModel_decision_variables,
		sub_obj::SCUCModel_objective_function,
		sub_cons::SCUCModel_constraints,
		sub_reformat_cons::SCUCModel_reformat_constraints
	)

	return scuc_subproblem, sub_scuc_struct
end

# Helper function to flatten constraints
flatten_constraints(constr) = vec(collect(Iterators.flatten(constr)))

"""
	define_subproblem_decision_variables!(scuc_subproblem, NT, NG, ND, NC, ND2, NS, NW, config_param)

Define the decision variables for the subproblem.

# Arguments
- `scuc_subproblem::Model`: The JuMP model for the subproblem.
- `NT::Int64`: Number of time periods.
- `NG::Int64`: Number of generators.
- `ND::Int64`: Number of loads.
- `NC::Int64`: Number of storage units.
- `ND2::Int64`: Number of data centers.
- `NS::Int64`: Number of scenarios.
- `NW::Int64`: Number of wind power plants.
+ `NW::Int64`: Number of wind power plants (optional).
- `config_param::config`: Configuration parameters.

# Returns
- `scuc_subproblem::Model`: The JuMP model with decision variables defined.
"""
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
	NS_copy = (config_param.is_ConsiderMultiCUTs == 1) ? NS : Int64(1)

	# binary variables
	@variable(scuc_subproblem, x[1:NG, 1:NT])
	@variable(scuc_subproblem, u[1:NG, 1:NT])
	@variable(scuc_subproblem, v[1:NG, 1:NT])
	@variable(scuc_subproblem, su₀[1:NG, 1:NT]>=0)
	@variable(scuc_subproblem, sd₀[1:NG, 1:NT]>=0)

	# @variable(scuc_subproblem, θ[NG * NS, 1:NT]>=0)

	# continuous variables
	@variable(scuc_subproblem, pg₀[1:(NG * NS_copy), 1:NT]>=0)
	@variable(scuc_subproblem, pgₖ[1:(NG * NS_copy), 1:NT, 1:3]>=0)

	@variable(scuc_subproblem, sr⁺[1:(NG * NS_copy), 1:NT]>=0)
	@variable(scuc_subproblem, sr⁻[1:(NG * NS_copy), 1:NT]>=0)
	@variable(scuc_subproblem, Δpd[1:(ND * NS_copy), 1:NT]>=0)
	@variable(scuc_subproblem, Δpw[1:(NW * NS_copy), 1:NT]>=0)

	# pss variables
	if config_param.is_ConsiderBESS == 1
		@variable(scuc_subproblem, κ⁺[1:(NC * NS_copy), 1:NT], Bin) # charge status
		@variable(scuc_subproblem, κ⁻[1:(NC * NS_copy), 1:NT], Bin) # discharge status
		@variable(scuc_subproblem, pc⁺[1:(NC * NS_copy), 1:NT]>=0)# charge power
		@variable(scuc_subproblem, pc⁻[1:(NC * NS_copy), 1:NT]>=0)# discharge power
		@variable(scuc_subproblem, qc[1:(NC * NS_copy), 1:NT]>=0) # cumsum power
		@variable(scuc_subproblem, pss_sumchargeenergy[1:(NC * NS), 1]>=0) # TODO Currently commented out

		# defination charging and discharging of BESS
		@variable(scuc_subproblem, α[1:(NS_copy * NC), 1:NT], Bin)
		@variable(scuc_subproblem, β[1:(NS_copy * NC), 1:NT], Bin)
	else
		κ⁺, κ⁻, pc⁺, pc⁻, qc = Matrix{VariableRef}(undef, 0, 0),
		Matrix{VariableRef}(undef, 0, 0), Matrix{VariableRef}(undef, 0, 0), Matrix{VariableRef}(undef, 0, 0),
		Matrix{VariableRef}(undef, 0, 0)
		pss_sumchargeenergy = Matrix{VariableRef}(undef, 0, 0)
		α, β = Matrix{VariableRef}(undef, 0, 0), Matrix{VariableRef}(undef, 0, 0)
	end

	if config_param.is_ConsiderDataCentra == 1
		@variable(scuc_subproblem, dc_p[1:(ND2 * NS_copy), 1:NT]>=0)
		@variable(scuc_subproblem, dc_f[1:(ND2 * NS_copy), 1:NT]>=0)
		@variable(scuc_subproblem, dc_v[1:(ND2 * NS_copy), 1:NT]>=0) # Currently commented out
		@variable(scuc_subproblem, dc_v²[1:(ND2 * NS_copy), 1:NT]>=0)
		@variable(scuc_subproblem, dc_λ[1:(ND2 * NS_copy), 1:NT]>=0)
		@variable(scuc_subproblem, dc_Δu1[1:(ND2 * NS_copy), 1:NT]>=0)
		@variable(scuc_subproblem, dc_Δu2[1:(ND2 * NS_copy), 1:NT]>=0)
	end

	# # Frequency control related variables (assuming these might be needed based on later constraints)
	# # Check if these are actually used/defined in the constraints file later
	# if config_param.is_ConsiderFrequencyControl == 1 # Assuming flag exists
	# 	@variable(scuc_subproblem, Δf_nadir[1:NS]>=0)
	# 	@variable(scuc_subproblem, Δf_qss[1:NS]>=0)
	# 	@variable(scuc_subproblem, Δp_imbalance[1:NS]>=0) # Placeholder, adjust as needed based on full constraints
	# end

	# println("\t Variables defined.")
	return scuc_subproblem, x, u, v, su₀, sd₀, pg₀, pgₖ, sr⁺, sr⁻, Δpd, Δpw, κ⁺, κ⁻, pc⁺, pc⁻, qc, pss_sumchargeenergy, α, β
end

"""
	set_subproblem_objective_economic!(scuc_subproblem, NT, NG, ND, NW, NS, units, config_param, scenarios_prob)

Set the objective function for the subproblem, aiming to minimize the total cost of operation.

# Arguments
- `scuc_subproblem::Model`: The JuMP model for the subproblem.
- `NT::Int64`: Number of time periods.
- `NG::Int64`: Number of generators.
- `ND::Int64`: Number of loads.
- `NW::Int64`: Number of wind power plants.
- `NS::Int64`: Number of scenarios.
- `units::unit`: Unit data structure.
- `config_param::config`: Configuration parameters.
- `scenarios_prob::Float64`: Probability of each scenario.
"""
function set_subproblem_objective_economic!(
		scuc_subproblem::Model,
		NT::Int64,
		NG::Int64,
		ND::Int64,
		NW::Int64,
		NS::Int64,
		units::unit,
		config_param::config,
		scenarios_prob::Float64
)
	# Input validation
	@assert NT>0 "Number of time periods (NT) must be positive."
	@assert NG>0 "Number of generators (NG) must be positive."
	@assert ND>=0 "Number of loads (ND) must be non-negative."
	@assert NW>=0 "Number of wind power plants (NW) must be non-negative."
	@assert NS>0 "Number of scenarios (NS) must be positive."
	@assert scenarios_prob >= 0&&scenarios_prob <= 1 "Scenario probability must be between 0 and 1."

	# Cost parameters
	c₀ = config_param.is_CoalPrice  # Base cost of coal

	# Penalty coefficients for load and wind curtailment
	load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

	NS_copy = (config_param.is_ConsiderMultiCUTs == 1) ? NS : Int64(1)
	pₛ = (config_param.is_ConsiderMultiCUTs == 1) ? scenarios_prob : 1.0

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

	obj = @objective(scuc_subproblem,
		Min,
		sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT)+
		pₛ*c₀*
		(
			sum(
				sum(
					sum(sum(pgₖ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT))
				for s in 1:NS_copy
				) for i in 1:NG
			)+
			sum(sum(sum(x[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS_copy)+
			sum(
				sum(
					sum(
						ρ⁺ * sr⁺[i + (s - 1) * NG, t] + ρ⁻ * sr⁻[i + (s - 1) * NG, t]
					for i in 1:NG
					) for t in 1:NT
				) for s in 1:NS_copy
			)
		)+
		pₛ*load_curtailment_penalty*sum(sum(sum(Δpd[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS_copy)+
		pₛ*wind_curtailment_penalty*sum(sum(sum(Δpw[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS_copy))

	# @objective(scuc_subproblem,
	# 	Min,
	# 	sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT) +
	# 		pₛ * c₀ *
	# 		(
	# 			sum(
	# 				sum(
	# 					sum(sum(pgₖ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT))
	# 					for s in 1:NS
	# 				) for i in 1:NG
	# 			) +
	# 			sum(sum(sum(x[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS) +
	# 			sum(
	# 				sum(
	# 					sum(
	# 						ρ⁺ * sr⁺[i + (s - 1) * NG, t] + ρ⁻ * sr⁻[i + (s - 1) * NG, t]
	# 						for i in 1:NG
	# 					) for t in 1:NT
	# 				) for s in 1:NS
	# 			)
	# 		) +
	# 		pₛ * load_curtailment_penalty * sum(sum(sum(Δpd[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS) +
	# 		pₛ * wind_curtailment_penalty * sum(sum(sum(Δpw[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS))
	# println("objective_function")
	println("\t LP_type subproblem objective_function \t\t\t\t\t done")

	println("Objective function has been set.")
	return scuc_subproblem, obj
end
