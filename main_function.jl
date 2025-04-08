include("src/environment_config.jl");
include("src/renewableresource_modules/stochasticsimulation.jl");
include("src/read_inputdata_modules/readdatas.jl");
include("src/unitcommitment_model_modules/SUCuccommitmentmodel.jl");

# Destructure directly from function call for clarity
# Read data from Excel sheet
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet();

# Form input data for the model
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, DataCentras = forminputdata(
	DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data);

# Generate wind scenarios
winds, NW = genscenario(WindsFreqParam, 1);

# Apply boundary conditions
boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, stroges);

# Run the SUC-SCUC model
# Define scenario probability (assuming equal probability)
scenarios_prob = 1.0 / winds.scenarios_nums;

# Call the refactored function
results = SUC_scucmodel(
	NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param,
	stroges, scenarios_prob, NL) # Added stroges, scenarios_prob, NL

function save_details_scheduled_results(results)
	# Check if optimization was successful and extract results
	if results !== nothing
		println("Extracting results from dictionary...")
		bench_x₀ = results["x₀"]
		bench_p₀ = results["p₀"]
		bench_pᵨ = results["pᵨ"]
		bench_pᵩ = results["pᵩ"]
		bench_seq_sr⁺ = results["seq_sr⁺"]
		bench_seq_sr⁻ = results["seq_sr⁻"]

		if config_param.is_ConsiderBESS == 1
			bench_pss_charge_p⁺ = results["pss_charge_p⁺"]
			bench_pss_charge_p⁻ = results["pss_charge_p⁻"]
			bench_su_cost = results["su_cost"]
			bench_sd_cost = results["sd_cost"]
			# bench_prod_cost = results["prod_cost"]
			# bench_cost_sr⁺ = results["cr⁺"]
			# bench_cost_sr⁻ = results["cr⁻"]

		end

		if config_param.is_ConsiderDataCentra == 1
			# Extract Data Centra results if they exist
			dc_p = get(results, "dc_p", nothing)
			dc_f = get(results, "dc_f", nothing)
			dc_v² = get(results, "dc_v²", nothing)
			dc_λ = get(results, "dc_λ", nothing)
			dc_Δu1 = get(results, "dc_Δu1", nothing)
			dc_Δu2 = get(results, "dc_Δu2", nothing)
		end
	else
		println("Optimization failed. Cannot proceed with saving results.")
		# Handle the error appropriately, maybe exit or skip saving
		# For now, just assign nothing to avoid errors in subsequent code if not handled
		bench_p₀, bench_pᵨ, bench_pᵩ, bench_pss_charge_p⁺, bench_pss_charge_p⁻ = ntuple(_ -> nothing, 5)
	end

	# Save the balance results
	# Save the balance results (only if optimization succeeded)
	if results !== nothing && bench_p₀ !== nothing # Check if variables are valid
		savebalance_result(bench_p₀, bench_pᵨ, bench_pᵩ, bench_pss_charge_p⁺,
			bench_pss_charge_p⁻, 1)
	else
		println("Skipping saving results due to optimization failure.")
	end
end
