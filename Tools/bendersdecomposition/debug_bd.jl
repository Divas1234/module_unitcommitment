ENV["JULIA_SHOW_ASCII"] = true

include("benders_mainfunc.jl");

scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_sub_model_struct_dic, config_param, units,
lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = benders_mainfunc_modules();

bd_framework(scuc_masterproblem, scuc_subproblem, master_model_struct,
	batch_sub_model_struct_dic, winds, config_param)

# DEBUG - benderdecomposition_module
