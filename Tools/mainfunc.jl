
include(joinpath(pwd(), "src", "environment_config.jl"));
include(joinpath(pwd(), "src", "renewableresource_modules", "stochasticsimulation.jl"));
include(joinpath(pwd(), "src", "read_inputdata_modules", "readdatas.jl"));
include(joinpath(pwd(), "src", "unitcommitment_model_modules", "SUCuccommitmentmodel.jl"));

include("define_masterproblem.jl")
include("define_subproblem.jl")
include("benderdecomposition_module.jl")

function main()
	UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet()

	# Form input data for the model
	config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, DataCentras = forminputdata(
		DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data)

	# Generate wind scenarios
	winds, NW = genscenario(WindsFreqParam, 1)

	# Apply boundary conditions
	# boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, psses, config_param)

	# Run the SUC-SCUC model
	# Define scenario probability (assuming equal probability)
	scenarios_prob = 1.0 / winds.scenarios_nums
	@show NS = Int64(winds.scenarios_nums)

	refcost, eachslope = linearizationfuelcurve(units, NG)
	scuc_masterproblem, master_re_constr_sets = bd_masterfunction(NT, NB, NG, ND, NC, ND2, NS, units, config_param)
	scuc_subproblem, sub_re_constr_sets = bd_subfunction(
		NT::Int64, NB::Int64, NL::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, NS::Int64, NW::Int64, units::unit, winds::wind,
		loads::load, lines::transmissionline, DataCentras::data_centra, psses::pss, scenarios_prob::Float64, config_param::config)
	# Make sure refcost and eachslope are defined before using them in the subproblem
	if !@isdefined(scenarios_prob)
		println("Warning: scenarios_prob not defined, setting to default value")
		scenarios_prob = 1.0 / NS
	end

	return scuc_masterproblem, scuc_subproblem, master_re_constr_sets, sub_re_constr_sets, config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, DataCentras, winds
end
