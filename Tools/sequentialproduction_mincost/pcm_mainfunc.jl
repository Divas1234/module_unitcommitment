include(joinpath(pwd(), "src", "renewableresource_modules", "stochasticsimulation.jl"));
include(joinpath(pwd(), "src", "read_inputdata_modules", "readdatas.jl"));
include("period_scuc_modules.jl")
# include(joinpath(pwd(), "src", "unitcommitment_model_modules", "SUCuccommitmentmodel.jl"));

# Destructure directly from function call for clarity
# Read data from Excel sheet
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet();

# Form input data for the model
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC,
ND2, DataCentras = forminputdata(
	DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData,
	datacentra_Data);

# Generate wind scenarios
winds, NW = genscenario(WindsFreqParam, 0);

# Apply boundary conditions
# boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, stroges);

# Run the SUC-SCUC model
# Define scenario probability (assuming equal probability)
scenarios_prob = 1.0 / winds.scenarios_nums;

# Call the refactored function
mini_NT = 24
patch_scheduling_ids_numssets = 7

"""
	column_1: units shutup_cost
	column_2: units shutdown_cost
	column_3: units operation_cost
	column_4: total cost
"""
total_scheduled_cost = zeros(patch_scheduling_ids_numssets + 1, 7)

# Loop over each patch scheduling interval (from 1 to patch_scheduling_ids_numssets)
pre_scheduling_results = Dict{String, Array{Float64}}()
for interval_scheduling_id in 1:patch_scheduling_ids_numssets
	# Update boundary conditions for the current interval based on previous scheduling results
	mini_units, mini_loads, mini_winds = update_boundary_conditions(
		interval_scheduling_id, NG, mini_NT, units, loads, winds, pre_scheduling_results)

	# Run the SCUC model for the current interval with updated data
	poster_scheduling_results = each_period_scucmodel_modules(
		mini_NT, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds, lines, DataCentras,
		config_param, stroges, scenarios_prob, NL, interval_scheduling_id)

	total_scheduled_cost[interval_scheduling_id, :] = poster_scheduling_results["res_scheduled_costs"]

	# Save the detailed results of the current scheduling interval
	save_powerbalance_scheduled_results(
		mini_units, mini_winds, config_param, poster_scheduling_results, interval_scheduling_id)
	# Update the previous scheduling results for the next interval
	pre_scheduling_results = poster_scheduling_results
end

total_scheduled_cost[end, :] = sum(total_scheduled_cost[1:(end - 1), :], dims = 1)

outdir = creat_outputfilepath(-1, 1)
write_result(outdir, "total_scheduled_results.csv", round.(total_scheduled_cost, digits = 5))

println("Simulation completed successfully.")

