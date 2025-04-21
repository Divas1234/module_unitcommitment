
include(joinpath(pwd(), "src", "environment_config.jl"));
include(joinpath(pwd(), "src", "renewableresource_modules", "stochasticsimulation.jl"));
include(joinpath(pwd(), "src", "read_inputdata_modules", "readdatas.jl"));
include(joinpath(pwd(), "src", "unitcommitment_model_modules", "SUCuccommitmentmodel.jl"));

include("define_SCUCmodel_structure.jl")
include("define_masterproblem.jl")
include("define_subproblem.jl")
include("benderdecomposition_module.jl")
include("define_batch_subproblems.jl")

function main()
	UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet()

	# Form input data for the model
	config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC,
	ND2, DataCentras = forminputdata(
		DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data)

	# Generate wind scenarios
	winds, NW = genscenario(WindsFreqParam, 1)

	# Apply boundary conditions
	# boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, psses, config_param)

	# Run the SUC-SCUC model
	# Define scenario probability (assuming equal probability)
	scenarios_prob = 1.0 / winds.scenarios_nums
	NS = Int64(winds.scenarios_nums)

	refcost, eachslope = linearizationfuelcurve(units, NG)
	scuc_masterproblem, master_model_struct = bd_masterfunction(
		NT, NB, NG, ND, NC, ND2, NS, units, config_param, scenarios_prob
	)
	scuc_subproblem, sub_model_struct = bd_subfunction(
		NT, NB, NL, NG, ND, NC, ND2, NS, NW, units, winds, loads, lines, DataCentras, psses, scenarios_prob, config_param
	)
	# Make sure refcost and eachslope are defined before using them in the subproblem
	if !@isdefined(scenarios_prob)
		println("Warning: scenarios_prob not defined, setting to default value")
		scenarios_prob = 1.0 / NS
	end

	# Define the subproblem structure for multi_cuts in benderdecomposition_module.jl
	# If the multi-cut option is enabled, generate batch subproblems
	if config_param.is_ConsiderMultiCUTs == 1
		batch_scuc_subproblem_struct_dic = OrderedDict{Int64, SCUC_Model}()
		batch_scuc_subproblem_struct_dic = (config_param.is_ConsiderMultiCUTs == 1) ?
										   get_batch_scuc_subproblems_for_scenario(scuc_subproblem, sub_model_struct, winds, config_param, NS) :
										   OrderedDict(1 => sub_model_struct)
		# @info batch_scuc_subproblem_dic
		@info "Generating batch subproblems for multi-cut scenarios"
		@info "Batch subproblem dictionary created with $(length(batch_scuc_subproblem_struct_dic)) entries, [batch_scuc_subproblem_struct_dic] have been created..."
	else
		@info "Single subproblem mode, no batch scuc_model generation in multicuts..."
	end

	return scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_scuc_subproblem_struct_dic, config_param, units,
	lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras
end
