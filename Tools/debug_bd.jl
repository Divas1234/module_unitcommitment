include("mainfunc.jl")
scuc_masterproblem, scuc_subproblem, master_re_constr_sets, sub_re_constr_sets, config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main();

if config_param.is_ConsiderMultiCUTs == 1
	batch_scuc_subproblem_dic = get_batch_scuc_subproblems_for_scenario(scuc_subproblem::Model, winds::wind, config_param::config)
end

# DEBUG - benderdecomposition_module
bd_framework(scuc_masterproblem::Model, scuc_subproblem::Model, master_allconstr_sets, sub_allconstr_sets)
