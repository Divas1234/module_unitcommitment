using JuMP

export define_decision_variables!

# Helper function to define model variables
function define_decision_variables!(scuc::Model, NT, NG, ND, NC, ND2, NS, NW, config_param)
	# binary variables
	@variable(scuc, x[1:NG, 1:NT], Bin)
	@variable(scuc, u[1:NG, 1:NT], Bin)
	@variable(scuc, v[1:NG, 1:NT], Bin)

	# continuous variables
	@variable(scuc, pg₀[1:(NG * NS), 1:NT] >= 0)
	@variable(scuc, pgₖ[1:(NG * NS), 1:NT, 1:3] >= 0)
	@variable(scuc, su₀[1:NG, 1:NT] >= 0)
	@variable(scuc, sd₀[1:NG, 1:NT] >= 0)
	@variable(scuc, sr⁺[1:(NG * NS), 1:NT] >= 0)
	@variable(scuc, sr⁻[1:(NG * NS), 1:NT] >= 0)
	@variable(scuc, Δpd[1:(ND * NS), 1:NT] >= 0)
	@variable(scuc, Δpw[1:(NW * NS), 1:NT] >= 0)

	# pss variables
	@variable(scuc, κ⁺[1:(NC * NS), 1:NT], Bin) # charge status
	@variable(scuc, κ⁻[1:(NC * NS), 1:NT], Bin) # discharge status
	@variable(scuc, pc⁺[1:(NC * NS), 1:NT] >= 0)# charge power
	@variable(scuc, pc⁻[1:(NC * NS), 1:NT] >= 0)# discharge power
	@variable(scuc, qc[1:(NC * NS), 1:NT] >= 0) # cumsum power
	# @variable(scuc, pss_sumchargeenergy[1:NC * NS, 1] >= 0) # Currently commented out

	# defination charging and discharging of BESS
	@variable(scuc, α[1:(NS * NC), 1:NT], Bin)
	@variable(scuc, β[1:(NS * NC), 1:NT], Bin)

	if config_param.is_ConsiderDataCentra == 1
		@variable(scuc, dc_p[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_f[1:(ND2 * NS), 1:NT] >= 0)
		# @variable(scuc, dc_v[1:(ND2 * NS), 1:NT]>=0) # Currently commented out
		@variable(scuc, dc_v²[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_λ[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_Δu1[1:(ND2 * NS), 1:NT] >= 0)
		@variable(scuc, dc_Δu2[1:(ND2 * NS), 1:NT] >= 0)
	end

	# Frequency control related variables (assuming these might be needed based on later constraints)
	# Check if these are actually used/defined in the constraints file later
	if config_param.is_ConsiderFrequencyControl == 1 # Assuming flag exists
		@variable(scuc, Δf_nadir[1:NS] >= 0)
		@variable(scuc, Δf_qss[1:NS] >= 0)
		@variable(scuc, Δp_imbalance[1:NS] >= 0) # Placeholder, adjust as needed based on full constraints
	end

	println("\t Variables defined.")
	return scuc # Return model with variables
end
