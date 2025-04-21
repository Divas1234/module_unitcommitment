function get_batch_scuc_subproblems_for_scenario(
		scuc_subproblem::Model,
		sub_model_struct::SCUC_Model,
		winds::wind,
		config_param::config,
		NS::Int64)

	# batch_scuc_subproblem_dic = OrderedDict{Int64, Any}()
	batch_scuc_model_strcuture_dic = OrderedDict{Int64, SCUC_Model}()

	@assert config_param.is_ConsiderMultiCUTs == 1

	for s in 1:NS
		ref_subproblem = JuMP.copy_model(scuc_subproblem)

		ref_subproblem_struct = deepcopy(sub_model_struct)

		scenarios_curve = winds.scenarios_curve[s, :]
		# ref_subproblem, modified_constr = modify_winds_constr_rhs!(ref_subproblem, winds, scenarios_curve)
		# reload scuc_model
		modified_model, modified_constr = modify_winds_constr_rhs!(ref_subproblem_struct.model, winds, scenarios_curve)
		# batch_primary_constraints, modify the rhs of the wind curtailment constraints
		ref_subproblem_struct.constraints.winds_curt_constr = modified_constr
		# alignment of the modified constraints
		ref_subproblem_struct.reformated_constraints._smaller_than[:key_winds_curt_constr] = modified_constr

		batch_scuc_model_strcuture_dic[s] = ref_subproblem_struct
	end

	return batch_scuc_model_strcuture_dic
end

function modify_winds_constr_rhs!(
		scuc_subproblem,
		winds,
		scenarios_curve)
	# for t in 1:NT, w in 1:NW
	# 	new_rhs = scenarios_curve[t] * winds.p_max[w, 1]
	# 	set_normalized_rhs(scuc_subproblem[:winds_curt_constr_for_eachscenario][1, t][w], new_rhs)
	# end
	modified_constr = scuc_subproblem[:winds_curt_constr_for_eachscenario]
	set_normalized_rhs.(
		[modified_constr[1, t][w] for t in 1:NT, w in 1:NW],
		scenarios_curve .* winds.p_max[:, 1]'
	)
	modified_constr = vec(collect(Iterators.flatten(modified_constr)))
	return scuc_subproblem, modified_constr
end
