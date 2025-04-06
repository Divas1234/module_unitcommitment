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
		dc_p_res, dc_f_res ,                          dc_v²_res, dc_λ_res, dc_Δu1_res, dc_Δu2_res = ntuple(_ -> nothing, 6) # Initialize as nothing
		if       config_param.is_ConsiderDataCentra == 1 && ND2 > 0
		         dc_p_res                            = JuMP.value.(scuc[:dc_p])
		         dc_f_res                            = JuMP.value.(scuc[:dc_f])
		         dc_v²_res                           = JuMP.value.(scuc[:dc_v²])
		         dc_λ_res                            = JuMP.value.(scuc[:dc_λ])
		         dc_Δu1_res                          = JuMP.value.(scuc[:dc_Δu1])
		         dc_Δu2_res                          = JuMP.value.(scuc[:dc_Δu2])
		end

		# TODO -

		c₀ = config_param.is_CoalPrice  # Base cost of coal
		pₛ = scenarios_prob  # Probability of scenarios

		# Penalty coefficients for load and wind curtailment
		load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
		wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

		ρ⁺ = c₀ * 2
		ρ⁻ = c₀ * 2

		prod_cost = pₛ *
					c₀ *
					(
						sum(
						sum(
							sum(sum(pgₖ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT))
						for s in 1    : NS
						)   for i in 1: NG
					) + sum(sum(sum(x₀[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS)
					)
		cr⁺ = pₛ *
			  c₀ *
			  sum(
				  sum(sum(ρ⁺ * seq_sr⁺[i + (s - 1) * NG, t] for i in 1:NG) for t in 1:NT)
					for s in 1: NS
			  )
		cr⁻ = pₛ *
			  c₀ *
			  sum(
				  sum(sum(ρ⁺ * seq_sr⁻[i + (s - 1) * NG, t] for i in 1:NG) for t in 1:NT)
					for s in 1: NS
			  )
		seq_sr⁺   = pₛ * c₀ * sum(ρ⁺ * seq_sr⁺[i, :] for i in 1:NG)
		seq_sr⁻   = pₛ * c₀ * sum(ρ⁺ * seq_sr⁻[i, :] for i in 1:NG)
		𝜟pd      = pₛ * sum(sum(sum(pᵨ[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS)
		𝜟pw      = pₛ * sum(sum(sum(pᵩ[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS)
		str       = zeros(1, 7)
		str[1, 1] = sum(su_cost) * 10
		str[1, 2] = sum(sd_cost) * 10
		str[1, 3] = prod_cost
		str[1, 4] = cr⁺
		str[1, 5] = cr⁻
		str[1, 6] = 𝜟pd
		str[1, 7] = 𝜟pw

		# Set output directory for results
  # output_dir = joinpath(pwd(), "output")
    output_dir = "/Users/yuanyiping/Documents/GitHub/module_unitcommitment/output/"

		# Create directory if it doesn't exist
		try
			if !isdir(output_dir)
				mkdir(output_dir)
			end

			# Open output file for writing results
			output_file = joinpath(output_dir, "Bench_calculation_result.txt")
			open(output_file, "w") do io
				writedlm(io, [" "])
				writedlm(io, ["su_cost" "sd_cost" "prod_cost" "cr⁺" "cr⁻" "𝜟pd" "𝜟pw"], '\t')
				writedlm(io, str, '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 1: units stutup/down states"])
				writedlm(io, x₀, '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 2: units dispatching power in scenario NO.1"])
				writedlm(io, pg₀[1:NG, 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 3: spolied wind power"])
				writedlm(io, pᵩ[1:NW, 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 4: forced load curtailments"])
				writedlm(io, pᵨ[1:ND, 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 5: pss charge state"])
				writedlm(io, pss_charge_state⁺[1:NC, 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 6: pss discharge state"])
				writedlm(io, pss_charge_state⁻[1:NC, 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 7: pss charge power"])
				writedlm(io, pss_charge_p⁺[1:NC, 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 8: pss discharge power"])
				writedlm(io, pss_charge_p⁻[1:NC, 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 9: pss strored energy"])
				writedlm(io, pss_Qc[1:NC, 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 10: sr⁺"])
				writedlm(io, seq_sr⁺[1:NG, 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 11: sr⁻"])
				writedlm(io, seq_sr⁻[1:NG, 1:NT], '\t')
				# writedlm(io, [" "])
				# writedlm(io, ["list 12: α"])
				# writedlm(io, α[1:NC, 1:NT], '\t')
				# writedlm(io, [" "])
				# writedlm(io, ["list 13: β"])
				# writedlm(io, β[1:NC, 1:NT], '\t')
			end
			println("The calculation result has been saved to: $output_file")
			println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")

			# Open output file for writing results
			output_file = joinpath(output_dir, "Bench_datacentra_result.txt")
			open(output_file, "w") do io
				writedlm(io, [" "])
				writedlm(io, ["list 1: dc_p"], '\t')
				writedlm(io, dc_p_res[1:(ND2 * NS), 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 2: dc_f"])
				writedlm(io, dc_f_res[1:(ND2 * NS), 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 3: dc_v²"])
				writedlm(io, dc_v²_res[1:(ND2 * NS), 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 4: dc_λ"])
				writedlm(io, dc_λ_res[1:(ND2 * NS), 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 5: dc_Δu1"])
				writedlm(io, dc_Δu1_res[1:(ND2 * NS), 1:NT], '\t')
				writedlm(io, [" "])
				writedlm(io, ["list 6: dc_Δu2"])
				writedlm(io, dc_Δu2_res[1:(ND2 * NS), 1:NT], '\t')
			end
			println("The calculation result has been saved to: $output_file")
			println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")

			# Open output file for csv writing results
			# output_dir = "D:/GithubClonefiles/datacentra_unitcommitment/output/data_centra/"

			# s                   = 1
			# @show data_to_write = [
			# 	("dc_Δu2.csv", JuMP.value.(dc_Δu2[1:(ND2), 1:NT])),
			# 	("dc_Δu1.csv", JuMP.value.(dc_Δu1[1:(ND2), 1:NT])),
			# 	("dc_v².csv", JuMP.value.(dc_v²[1:(ND2), 1:NT])),
			# 	("dc_λ.csv", JuMP.value.(dc_λ[1:(ND2), 1:NT])),
			# 	("dc_f.csv", JuMP.value.(dc_f[1:(ND2), 1:NT])),
			# 	("dc_p.csv", JuMP.value.(dc_p[1:(ND2), 1:NT])),
			# 	("dc_debug_tasks_1.csv",
			# 		(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((1 - 1) * iter_block + 1):(1 * iter_block)]))),
			# 	("dc_debug_tasks_2.csv",
			# 		(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((2 - 1) * iter_block + 1):(2 * iter_block)]))),
			# 	("dc_debug_tasks_3.csv",
			# 		(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((3 - 1) * iter_block + 1):(3 * iter_block)]))),
			# 	("dc_debug_tasks_4.csv",
			# 		(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((4 - 1) * iter_block + 1):(4 * iter_block)]))),
			# 	("dc_debug_tasks_5.csv",
			# 		(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((5 - 1) * iter_block + 1):(5 * iter_block)]))),
			# 	("dc_debug_tasks_6.csv",
			# 		(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((6 - 1) * iter_block + 1):(6 * iter_block)])))
			# ]

			# @constraint(scuc, [s = 1:NS, t = 1:NT, iter = 1:iter_num],
			# 	sum(dc_λ[((s - 1) * ND2 + 1):(s * ND2),
			# 		((iter - 1) * iter_block + 1):(iter * iter_block)]).<=(1 + coeff) * sum(DataCentras.λ) .* DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])

			# iter = 1
			# println("===============================================================================")
			# @show (1 + coeff) * sum(DataCentras.λ) * iter_block .*
			# 	  sum(DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])
			# @show (1 - coeff) * sum(DataCentras.λ) * iter_block .*
			# 	  sum(DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])
			# @show sum(JuMP.value.(dc_λ[
			# 	((s - 1) * ND2 + 1):(s * ND2), ((iter - 1) * iter_block + 1):(iter * iter_block)])) .*
			# 	  sum(DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])

			# println("===============================================================================")

			# for (filename, data) in data_to_write
			# filepath = joinpath(output_dir, filename)
			# 	try
			# 		CSV.write(filepath, DataFrame(data, :auto))
			# 		println("Successfully wrote to $filepath")
			# 	catch e
			# @error "Failed to write to $filepath" exception = (e, catch_backtrace())
			# 	end
			# end

		catch e
			println("Error writing results to file: $e")
		end

		  #   =================================
		# res                                 = JuMP.value
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
		return results

	else # This else corresponds to the 'if status == MOI.OPTIMAL...'
		println("Solver did not find an acceptable solution. Status: ", status)
		# Return empty or indicate failure
		return nothing # Or throw an error
	end
end # End of solve_and_extract_results function
