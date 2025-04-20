using Revise
include("mainfunc.jl")
scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main();

batch_scuc_subproblem_dic =
	(config_param.is_ConsiderMultiCUTs == 1) ?
	get_batch_scuc_subproblems_for_scenario(scuc_subproblem::Model, winds::wind, config_param::config) :
	OrderedDict(1 => scuc_subproblem)

# DEBUG - benderdecomposition_module
# bd_framework(scuc_masterproblem::Model, batch_scuc_subproblem_dic::OrderedDict, master_model_struct, sub_model_struct, winds, config_param)
