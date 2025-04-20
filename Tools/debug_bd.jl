using Revise
include("mainfunc.jl")
scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main();

batch_scuc_subproblem_dic =
	(config_param.is_ConsiderMultiCUTs == 1) ?
	get_batch_scuc_subproblems_for_scenario(scuc_subproblem::Model,sub_model_struct, winds::wind, config_param::config) :
	OrderedDict(1 => scuc_subproblem)

# DEBUG - benderdecomposition_module
bd_framework(scuc_masterproblem::Model, batch_scuc_subproblem_dic::OrderedDict, master_model_struct, sub_model_struct, winds, config_param)

optimize!(sub_model_struct.model)
dual.(sub_model_struct.constraints.units_minuptime_constr)
typeof(sub_model_struct.constraints.units_minuptime_constr)


sub_model_struct.reformated_constraints._equal_to



# for t in 1:NT, w in 1:NW
	# 	new_rhs = scenarios_curve[t] * winds.p_max[w, 1]
	# 	set_normalized_rhs(scuc_subproblem[:winds_curt_constr_for_eachscenario][1, t][w], new_rhs)
	# end
