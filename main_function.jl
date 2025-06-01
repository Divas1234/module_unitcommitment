include("src/environment_config.jl");
include("src/renewableresource_modules/stochasticsimulation.jl");
include("src/read_inputdata_modules/readdatas.jl");
include("src/unitcommitment_model_modules/SUCuccommitmentmodel.jl");

# Destructure directly from function call for clarity
# Read data from Excel sheet
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet();

# Form input data for the model
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC,
ND2, NH, DataCentras, hydros = forminputdata(DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData,
	Datacentra_Data, HydroData, HydroCurve);
NT = 24
# Generate wind scenarios
winds, NW = genscenario(WindsFreqParam, 1);

# Apply boundary conditions
# boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, stroges);

# Run the SUC-SCUC model
# Define scenario probability (assuming equal probability)
scenarios_prob = 1.0 / winds.scenarios_nums;

# Call the refactored function
results = SUC_scucmodel(NT, NB, NG, ND, NC, ND2, units, loads, winds, lines, DataCentras, config_param, stroges, scenarios_prob, NL, hydros, NH) # Added stroges, scenarios_prob, NL, NH

save_powerbalance_scheduled_results(units, winds, config_param, results)
println("Simulation completed successfully.")
