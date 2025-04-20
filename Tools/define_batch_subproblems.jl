function get_batch_scuc_subproblems_for_scenario(scuc_subproblem::Model,sub_model_struct::SCUC_Model, winds::wind, config_param::config)
	batch_scuc_subproblem_dic = OrderedDict{Int64, Any}()
	batch_scuc_model_strcuture_dic = OrderedDict{Int64, Any}()

	@assert config_param.is_ConsiderMultiCUTs == 1
	# for s in 1:NS
	# 	scenarios_curve = winds.scenarios_curve[s, :]
	# 	ref_scuc_subproblem = scuc_subproblem
	# 	modify_winds_constr_rhs!(ref_scuc_subproblem, winds, scenarios_curve)
	# 	batch_scuc_subproblem_dic[s] = ref_scuc_subproblem
	# end

	# for s in 1:NS
	# 	ref_subproblem = scuc_subproblem
	# 	ref_subproblem_struct = sub_model_struct

	# 	scenarios_curve = winds.scenarios_curve[s, :]

	# 	ref_subproblem, modified_constr = modify_winds_constr_rhs!(ref_subproblem, winds, scenarios_curve)
    #     ref_subproblem_struct.constraints.winds_curt_constr = vec(collect(Iterators.flatten(modified_constr)))

	# 	ref_subproblem_struct.model = ref_subproblem
	# 	ref_subproblem.objective_function = sub_model_struct.objective_function
	# 	ref_subproblem.constraints = sub_model_struct.constraints
	# 	sub_reformat_cons = get_reorganize_constraints_struct(ref_subproblem.constraints)


	# 	batch_scuc_model_strcuture_dic[s] = (
    #         :model => ref_scuc_subproblem,
	# 		:decision_variables => sub_model_struct.decision_variables,
	# 		:objective_function => sub_model_struct.objective_function,
	# 		:constraints => sub_model_struct.lines,
	# 	)






# struct SCUC_Model
# 	model::Union{Missing, JuMP.Model}
# 	decision_variables::SCUCModel_decision_variables
# 	objective_function::SCUCModel_objective_function
# 	constraints::SCUCModel_constraints
# 	reformated_constraints::SCUCModel_reformat_constraints
# end



















	# end

	batch_scuc_subproblem_dic = Dict(
		s => (
			ref_scuc_subproblem = scuc_subproblem;
			modify_winds_constr_rhs!(ref_scuc_subproblem, winds, winds.scenarios_curve[s, :]);
			ref_scuc_subproblem)
		for s in 1:NS
	)

	return batch_scuc_subproblem_dic
end

function modify_winds_constr_rhs!(scuc_subproblem, winds, scenarios_curve)
	# for t in 1:NT, w in 1:NW
	# 	new_rhs = scenarios_curve[t] * winds.p_max[w, 1]
	# 	set_normalized_rhs(scuc_subproblem[:winds_curt_constr_for_eachscenario][1, t][w], new_rhs)
	# end
	modified_constr = set_normalized_rhs.(
		[scuc_subproblem[:winds_curt_constr_for_eachscenario][1, t][w] for t in 1:NT, w in 1:NW],
		scenarios_curve .* winds.p_max[:, 1]'
	)
	return scuc_subproblem, modified_constr
end
