include("mainfunc.jl")
scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_scuc_subproblem_dic, config_param, units,
lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main();

# DEBUG - benderdecomposition_module
# bd_framework(scuc_masterproblem::Model, batch_scuc_subproblem_dic::OrderedDict, master_model_struct, sub_model_struct, winds, config_param)

