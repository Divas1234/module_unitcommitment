function get_batch_scuc_subproblems_for_scenario(scuc_subproblem::Model, winds::wind, config_param::config)
	batch_scuc_subproblem_dic = OrderedDict{Int64, Any}()

	if config_param.is_ConsiderMultiCUTs == 1
		for s in 1:NS
			scenarios_curve = winds.scenarios_curve[s, :]
			ref_scuc_subproblem = scuc_subproblem
			modify_winds_constr_rhs!(ref_scuc_subproblem, winds, scenarios_curve)
			batch_scuc_subproblem_dic[s] = ref_scuc_subproblem
		end
	end
	return batch_scuc_subproblem_dic
end

function modify_winds_constr_rhs!(scuc_subproblem, winds, scenarios_curve)
	for t in 1:NT
		for w in 1:NW
			new_rhs = scenarios_curve[t] * winds.p_max[w, 1]
			set_normalized_rhs(scuc_subproblem[:winds_curt_constr_for_eachscenario][1, t][w], new_rhs)
		end
	end
end
