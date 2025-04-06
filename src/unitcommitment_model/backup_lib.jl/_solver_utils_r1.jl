using JuMP, Gurobi # Add Gurobi here if not implicitly loaded via JuMP
using DelimitedFiles # Explicitly add for writedlm

export solve_and_extract_results

# Helper function to write benchmark results to a text file
function write_benchmark_results(output_dir, results, NG, NW, ND, NC, NT)
	output_file = joinpath(output_dir, "Bench_calculation_result.txt")
	println("Attempting to save benchmark results to: $output_file")
	try
		open(output_file, "w") do io
			# --- Write Summary Costs ---
			# Total objective value is the primary cost metric here.
			writedlm(io, [" "])
			writedlm(io, ["Metric" "Value"], '\t')
			writedlm(io, ["ObjectiveValue" results["objective_value"]], '\t')
			# Add other summary metrics if available and needed (e.g., solve_time)
			writedlm(io, ["SolveTime" results["solve_time"]], '\t')
			writedlm(io, ["Status" string(results["status"])], '\t') # Convert status to string

			# --- Write Detailed Results ---
			# Helper function to safely write data if it's not nothing
			safe_writedlm(io, data) = !isnothing(data) && writedlm(io, data, '\t')

			writedlm(io, [" "])
			writedlm(io, ["list 1: units stutup/down states (x₀)"])
			safe_writedlm(io, results["x₀"])

			writedlm(io, [" "])
			writedlm(io, ["list 2: units dispatching power in scenario NO.1 (pg₀)"])
			# Assuming pg₀ is the first NG rows of p₀
			!isnothing(results["p₀"]) && size(results["p₀"], 1) >= NG && writedlm(io, results["p₀"][1:NG, 1:NT], '\t')

			writedlm(io, [" "])
			writedlm(io, ["list 3: spolied wind power (pᵩ)"])
			!isnothing(results["pᵩ"]) && size(results["pᵩ"], 1) >= NW && writedlm(io, results["pᵩ"][1:NW, 1:NT], '\t')

			writedlm(io, [" "])
			writedlm(io, ["list 4: forced load curtailments (pᵨ)"])
			!isnothing(results["pᵨ"]) && size(results["pᵨ"], 1) >= ND && writedlm(io, results["pᵨ"][1:ND, 1:NT], '\t')

			if NC > 0
				writedlm(io, [" "])
				writedlm(io, ["list 5: pss charge state (κ⁺)"])
				safe_writedlm(io, results["pss_charge_state⁺"])

				writedlm(io, [" "])
				writedlm(io, ["list 6: pss discharge state (κ⁻)"])
				safe_writedlm(io, results["pss_charge_state⁻"])

				writedlm(io, [" "])
				writedlm(io, ["list 7: pss charge power (pc⁺)"])
				safe_writedlm(io, results["pss_charge_p⁺"])

				writedlm(io, [" "])
				writedlm(io, ["list 8: pss discharge power (pc⁻)"])
				safe_writedlm(io, results["pss_charge_p⁻"])

				writedlm(io, [" "])
				writedlm(io, ["list 9: pss stored energy (qc)"])
				safe_writedlm(io, results["pss_Qc"])
			end

			writedlm(io, [" "])
			writedlm(io, ["list 10: upward reserve (sr⁺)"])
			!isnothing(results["seq_sr⁺"]) && size(results["seq_sr⁺"], 1) >= NG && writedlm(io, results["seq_sr⁺"][1:NG, 1:NT], '\t')

			writedlm(io, [" "])
			writedlm(io, ["list 11: downward reserve (sr⁻)"])
			!isnothing(results["seq_sr⁻"]) && size(results["seq_sr⁻"], 1) >= NG && writedlm(io, results["seq_sr⁻"][1:NG, 1:NT], '\t')

			# Alpha/beta were commented out in original, keeping them commented
			# writedlm(io, [" "]); writedlm(io, ["list 12: α"]); safe_writedlm(io, results["pss_charge_cycle⁺"])
			# writedlm(io, [" "]); writedlm(io, ["list 13: β"]); safe_writedlm(io, results["pss_charge_cycle⁻"])
		end
		println("Benchmark results successfully saved to: $output_file")
	catch e
		println("Error writing benchmark results to file '$output_file': $e")
		showerror(stdout, e, catch_backtrace())
		println() # Add a newline for clarity
	end
	println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
end

# Helper function to write data centra results to a text file
function write_datacentra_results(output_dir, results, ND2, NS, NT)
	# Check if data centra results exist (using one key as an indicator)
	if isnothing(results["dc_p"]) || ND2 <= 0
		println("No data centra results to write (ND2=$ND2, dc_p is nothing: $(isnothing(results["dc_p"]))).")
		return
	end

	output_file = joinpath(output_dir, "Bench_datacentra_result.txt")
	println("Attempting to save data centra results to: $output_file")
	try
		open(output_file, "w") do io
			# Helper function to safely write data if it's not nothing
			safe_writedlm(io, data) = !isnothing(data) && writedlm(io, data, '\t')

			writedlm(io, [" "])
			writedlm(io, ["list 1: dc_p"])
			safe_writedlm(io, results["dc_p"]) # Assuming full matrix [1:(ND2 * NS), 1:NT] is needed

			writedlm(io, [" "])
			writedlm(io, ["list 2: dc_f"])
			safe_writedlm(io, results["dc_f"])

			writedlm(io, [" "])
			writedlm(io, ["list 3: dc_v²"])
			safe_writedlm(io, results["dc_v²"])

			writedlm(io, [" "])
			writedlm(io, ["list 4: dc_λ"])
			safe_writedlm(io, results["dc_λ"])

			writedlm(io, [" "])
			writedlm(io, ["list 5: dc_Δu1"])
			safe_writedlm(io, results["dc_Δu1"])

			writedlm(io, [" "])
			writedlm(io, ["list 6: dc_Δu2"])
			safe_writedlm(io, results["dc_Δu2"])
		end
		println("Data centra results successfully saved to: $output_file")
	catch e
		println("Error writing data centra results to file '$output_file': $e")
		showerror(stdout, e, catch_backtrace())
		println() # Add a newline for clarity
	end
	println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")
end

# Main function to solve the model, extract results, and write them to files.
# Parameters:
# scuc: The JuMP model object
# NT: Number of time periods
# NG: Number of generators
# ND: Number of conventional demands
# NC: Number of storage units (e.g., PSS)
# NW: Number of wind units
# NS: Number of scenarios
# ND2: Number of data centra
# scenarios_prob: Probability of each scenario (Note: Not used within this function after refactoring)
# eachslope: Cost curve slopes for generators (Note: Not used within this function after refactoring)
# refcost: Reference costs for generators (Note: Not used within this function after refactoring)
# config_param: Dictionary or Struct containing configuration parameters (e.g., is_ConsiderDataCentra)
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

		# Removed manual cost calculations (prod_cost, cr+, cr-, Δpd, Δpw, str)
		# These should be derived from the objective function or calculated by the caller if needed.

		# Set output directory using relative path (assuming script runs from project root)
		output_dir = joinpath(pwd(), "output")
		println("Output directory set to: $output_dir")

		# Create directory if it doesn't exist
		try
			if !isdir(output_dir)
				println("Creating output directory: $output_dir")
				mkpath(output_dir) # Use mkpath to create parent directories if needed
			end
		catch e
			println("Error creating output directory '$output_dir': $e")
			# Decide if we should proceed without writing files or return early
			# For now, we'll print the error and continue to attempt writing
		end

		# Store extracted results in a dictionary before writing
		# This makes it easier to pass data to helper functions
		extracted_results = Dict(
			"x₀"                => x₀,
			"u₀"                => u₀,
			"v₀"                => v₀,
			"p₀"                => pg₀, # Note: Renamed from pg₀ for consistency? Check usage.
			"pₖ"                => pgₖ,
			"su_cost"           => su_cost, # Raw startup decision cost variable
			"sd_cost"           => sd_cost, # Raw shutdown decision cost variable
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
			"objective_value"   => objective_value(scuc),
			"solve_time"        => solve_time(scuc),
			"status"            => status,
			"dc_p"              => dc_p_res,
			"dc_f"              => dc_f_res,
			"dc_v²"             => dc_v²_res,
			"dc_λ"              => dc_λ_res,
			"dc_Δu1"            => dc_Δu1_res,
			"dc_Δu2"            => dc_Δu2_res
		)

		# Write results using helper functions
		write_benchmark_results(output_dir, extracted_results, NG, NW, ND, NC, NT)
		write_datacentra_results(output_dir, extracted_results, ND2, NS, NT)

		# Removed the large commented-out CSV writing block and associated debug prints

		println("Step-6: recording data finished")
		# Return the dictionary containing all extracted results
		return extracted_results

	else # This else corresponds to the 'if status == MOI.OPTIMAL...'
		println("Solver did not find an acceptable solution. Status: ", status)
		# Return empty or indicate failure
		return nothing # Or throw an error
	end
end # End of solve_and_extract_results function
