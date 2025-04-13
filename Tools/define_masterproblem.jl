include("/Users/yuanyiping/Documents/GitHub/module_unitcommitment/src/environment_config.jl")
include("/Users/yuanyiping/Documents/GitHub/module_unitcommitment/src/unitcommitment_model_modules/SUCuccommitmentmodel.jl")

function bd_masterfunction(NT::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, units::unit, config_param::config)
	println("this is the master function of the bender decomposition process")
	Δp_contingency = define_contingency_size(units, NG)
	scuc = Model(Gurobi.Optimizer)
	# set_silent(scuc)
	# --- Define Variables ---
	# Define decision variables for the optimization model
	define_masterproblem_decision_variables!(scuc::Model, NT, NG, ND, NC, ND2, NS, NW, config_param)

	# --- Set Objective ---
	# Set the objective function to be minimized
	set_masterproblem_objective_economic!(
		scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)

	# println("subject to.") # Indicate the start of constraint definitions

	# --- Add Constraints ---
	# Add the constraints to the optimization model
	add_unit_operation_constraints!(scuc, NT, NG, units, onoffinit)
	# add_curtailment_constraints!(scuc, NT, ND, NW, NS, loads, winds)
	# add_generator_power_constraints!(scuc, NT, NG, NS, units)
	# add_reserve_constraints!(scuc, NT, NG, NC, NS, units, loads, winds, config_param)
	# add_power_balance_constraints!(scuc, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)
	# add_ramp_constraints!(scuc, NT, NG, NS, units, onoffinit)
	# add_pwl_constraints!(scuc, NT, NG, NS, units)
	# add_transmission_constraints!(scuc, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, stroges, Gsdf, config_param, ND2, DataCentras)
	# add_storage_constraints!(scuc, NT, NC, NS, config_param, stroges)
	# add_datacentra_constraints!(scuc, NT, NS, config_param, ND2, DataCentras)
	# add_frequency_constraints!(scuc, NT, NG, NC, NS, units, stroges, config_param, Δp_contingency)
end

# Helper function to define model variables
function define_masterproblem_decision_variables!(scuc::Model, NT, NG, ND, NC, ND2, NS, NW, config_param)
	# binary variables
	@variable(scuc, x[1:NG, 1:NT], Bin)
	@variable(scuc, u[1:NG, 1:NT], Bin)
	@variable(scuc, v[1:NG, 1:NT], Bin)

	# continuous variables
	# @variable(scuc, pg₀[1:(NG * NS), 1:NT]>=0)
	# @variable(scuc, pgₖ[1:(NG * NS), 1:NT, 1:3]>=0)
	@variable(scuc, su₀[1:NG, 1:NT]>=0)
	@variable(scuc, sd₀[1:NG, 1:NT]>=0)

	@variable(scuc, θ[NG * NS, 1:NT]>=0)

	# @variable(scuc, sr⁺[1:(NG * NS), 1:NT]>=0)
	# @variable(scuc, sr⁻[1:(NG * NS), 1:NT]>=0)
	# @variable(scuc, Δpd[1:(ND * NS), 1:NT]>=0)
	# @variable(scuc, Δpw[1:(NW * NS), 1:NT]>=0)

	# pss variables
	# @variable(scuc, κ⁺[1:(NC * NS), 1:NT], Bin) # charge status
	# @variable(scuc, κ⁻[1:(NC * NS), 1:NT], Bin) # discharge status
	# @variable(scuc, pc⁺[1:(NC * NS), 1:NT]>=0)# charge power
	# @variable(scuc, pc⁻[1:(NC * NS), 1:NT]>=0)# discharge power
	# @variable(scuc, qc[1:(NC * NS), 1:NT]>=0) # cumsum power
	# # @variable(scuc, pss_sumchargeenergy[1:NC * NS, 1] >= 0) # Currently commented out

	# # defination charging and discharging of BESS
	# @variable(scuc, α[1:(NS * NC), 1:NT], Bin)
	# @variable(scuc, β[1:(NS * NC), 1:NT], Bin)

	# if config_param.is_ConsiderDataCentra == 1
	# 	@variable(scuc, dc_p[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc, dc_f[1:(ND2 * NS), 1:NT]>=0)
	# 	# @variable(scuc, dc_v[1:(ND2 * NS), 1:NT]>=0) # Currently commented out
	# 	@variable(scuc, dc_v²[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc, dc_λ[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc, dc_Δu1[1:(ND2 * NS), 1:NT]>=0)
	# 	@variable(scuc, dc_Δu2[1:(ND2 * NS), 1:NT]>=0)
	# end

	# # Frequency control related variables (assuming these might be needed based on later constraints)
	# # Check if these are actually used/defined in the constraints file later
	# if config_param.is_ConsiderFrequencyControl == 1 # Assuming flag exists
	# 	@variable(scuc, Δf_nadir[1:NS]>=0)
	# 	@variable(scuc, Δf_qss[1:NS]>=0)
	# 	@variable(scuc, Δp_imbalance[1:NS]>=0) # Placeholder, adjust as needed based on full constraints
	# end

	# println("\t Variables defined.")
	return scuc # Return model with variables
end

function set_masterproblem_objective_economic!(
		scuc::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob, refcost, eachslope)
	# Cost parameters
	c₀ = config_param.is_CoalPrice  # Base cost of coal
	pₛ = scenarios_prob  # Probability of scenarios

	# Penalty coefficients for load and wind curtailment
	load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
	wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

	ρ⁺ = c₀ * 2
	ρ⁻ = c₀ * 2

	x = scuc[:x]
	su₀ = scuc[:su₀]
	sd₀ = scuc[:sd₀]
	# pgₖ = scuc[:pgₖ]
	# sr⁺ = scuc[:sr⁺]
	# sr⁻ = scuc[:sr⁻]
	# Δpd = scuc[:Δpd]
	# Δpw = scuc[:Δpw]

	@objective(scuc,
		Min,
		sum(sum(su₀[i, t] + sd₀[i, t] for i in 1:NG) for t in 1:NT)
		# +
		# pₛ*
		# c₀*
		# (
		# 	sum(
		# 		sum(
		# 			sum(sum(pgₖ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT))
		# 		for s in 1:NS
		# 		) for i in 1:NG
		# 	)+
		# 	sum(sum(sum(x[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS)+ # Assumes x is accessible
		# 	sum(
		# 		sum(
		# 			sum(
		# 				ρ⁺ * sr⁺[i + (s - 1) * NG, t] + ρ⁻ * sr⁻[i + (s - 1) * NG, t]
		# 			for i in 1:NG
		# 			) for t in 1:NT
		# 		) for s in 1:NS
		# 	)
		# )+
		# pₛ*
		# load_curtailment_penalty*
		# sum(sum(sum(Δpd[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS)+
		# pₛ*
		# wind_curtailment_penalty*
		# sum(sum(sum(Δpw[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS))
	)
	# println("objective_function")
	println("\t MILP_type objective_function \t\t\t\t\t\t done")
end
