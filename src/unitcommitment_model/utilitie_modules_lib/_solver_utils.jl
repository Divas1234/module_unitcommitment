using JuMP, Gurobi # Add Gurobi here if not implicitly loaded via JuMP

export solve_and_extract_results

# Helper function to solve the model and extract results
function solve_and_extract_results(scuc::Model, NT, NG, ND, NC, NW, NS, ND2, scenarios_prob, eachslope, refcost, config_param)
	println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
	println("Step-4: starting Gurobi solver")
	optimize!(scuc)
	println("Step-5: Gurobi solver finished")
	println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")

	# Check termination status
	status = termination_status(scuc)
	println("Termination Status: ", status)

	if status == MOI.OPTIMAL || status == MOI.LOCALLY_SOLVED || status == MOI.TIME_LIMIT ||
	   status == MOI.OBJECTIVE_LIMIT # Added OBJECTIVE_LIMIT as acceptable status
		println("Acceptable solution found (Status: $status).")

		# Extract values
		x₀      = JuMP.value.(scuc[:x])
		u₀      = JuMP.value.(scuc[:u])
		v₀      = JuMP.value.(scuc[:v])
		pg₀     = JuMP.value.(scuc[:pg₀])
		pgₖ     = JuMP.value.(scuc[:pgₖ])
		su_cost = JuMP.value.(scuc[:su₀])
		sd_cost = JuMP.value.(scuc[:sd₀])
		seq_sr⁺ = JuMP.value.(scuc[:sr⁺])
		seq_sr⁻ = JuMP.value.(scuc[:sr⁻])
		pᵨ      = JuMP.value.(scuc[:Δpd])
		pᵩ      = JuMP.value.(scuc[:Δpw])
		# α       = JuMP.value.(α)
		# β       = JuMP.value.(β)

		# Storage results (check if NC > 0)
		pss_charge_p⁺, pss_charge_p⁻, pss_charge_state⁺, pss_charge_state⁻, pss_charge_cycle⁺, pss_charge_cycle⁻, pss_Qc = ntuple(
			_ -> nothing, 7)
		if NC > 0
			pss_charge_p⁺     = JuMP.value.(scuc[:pc⁺])
			pss_charge_p⁻     = JuMP.value.(scuc[:pc⁻])
			pss_charge_state⁺ = JuMP.value.(scuc[:κ⁺])
			pss_charge_state⁻ = JuMP.value.(scuc[:κ⁻])
			pss_charge_cycle⁺ = JuMP.value.(scuc[:α])
			pss_charge_cycle⁻ = JuMP.value.(scuc[:β])
			pss_Qc            = JuMP.value.(scuc[:qc])
		end

		# Note: Calculating individual cost components (prod_cost, cr+, cr-) here from solved variables
		# requires passing parameters like eachslope, refcost, ρ⁺, ρ⁻ to this function.
		# The total cost is available via objective_value(scuc).
		# Removed the direct calculation here to fix syntax errors and avoid complexity.
		# These can be recalculated outside if needed, using the returned solved variables.

		# Data centra results
		dc_p_res, dc_f_res, dc_v²_res, dc_λ_res, dc_Δu1_res, dc_Δu2_res = ntuple(_ -> nothing, 6) # Initialize as nothing
		if config_param.is_ConsiderDataCentra == 1 && ND2 > 0
			dc_p_res   = JuMP.value.(scuc[:dc_p])
			dc_f_res   = JuMP.value.(scuc[:dc_f])
			dc_v²_res  = JuMP.value.(scuc[:dc_v²])
			dc_λ_res   = JuMP.value.(scuc[:dc_λ])
			dc_Δu1_res = JuMP.value.(scuc[:dc_Δu1])
			dc_Δu2_res = JuMP.value.(scuc[:dc_Δu2])
		end

		#   =================================
		# res = JuMP.value
		println("Step-6: record datas")
		# Note: Original function returned specific variables directly.
		# Adjust the return statement based on what the caller function `mainfun.jl` expects.
		# Returning a dictionary or a custom struct might be cleaner.
		results = Dict(
			"x₀"                => x₀,
			"u₀"                => u₀,
			"v₀"                => v₀,
			"p₀"                => pg₀,
			"pₖ"                => pgₖ,
			"su_cost"           => su_cost,
			"sd_cost"           => sd_cost,
			"seq_sr⁺"           => seq_sr⁺,
			"seq_sr⁻"           => seq_sr⁻,
			"pᵨ"                => pᵨ,
			"pᵩ"                => pᵩ,
			"pss_charge_p⁺"     => pss_charge_p⁺,
			"pss_charge_p⁻"     => pss_charge_p⁻,
			"pss_charge_state⁺" => pss_charge_state⁺,
			"pss_charge_state⁻" => pss_charge_state⁻,
			"pss_charge_cycle⁺" => pss_charge_cycle⁺,
			"pss_charge_cycle⁻" => pss_charge_cycle⁻,
			"pss_Qc"            => pss_Qc,

			# "prod_cost" => prod_cost,
			# "cr⁺"       => cr⁺,
			# "cr⁻"       => cr⁻,       # Removed as they are not calculated here anymore

			"objective_value" => objective_value(scuc),
			"solve_time"      => solve_time(scuc),
			"status"          => status,

			# Add data centra results to dictionary
			"dc_p"   => dc_p_res,
			"dc_f"   => dc_f_res,
			"dc_v²"  => dc_v²_res,
			"dc_λ"   => dc_λ_res,
			"dc_Δu1" => dc_Δu1_res,
			"dc_Δu2" => dc_Δu2_res
		)

		exported_scheduling_cost(NS, NT, NB, NG, ND, NC, ND2, units, loads,
			winds, lines, DataCentras, config_param, su_cost, sd_cost, pgₖ, pg₀, x₀,
			seq_sr⁺, seq_sr⁻, pᵨ, pᵩ, pss_charge_state⁺, pss_charge_state⁻, pss_charge_p⁺, pss_charge_p⁻, pss_Qc,
			dc_p_res, dc_f_res, dc_v²_res, dc_λ_res, dc_Δu1_res, dc_Δu2_res, eachslope, refcost)

		return results

	else # This else corresponds to the 'if status == MOI.OPTIMAL...'
		println("Solver did not find an acceptable solution. Status: ", status)
		# Return empty or indicate failure
		return nothing # Or throw an error
	end
end # End of solve_and_extract_results function
