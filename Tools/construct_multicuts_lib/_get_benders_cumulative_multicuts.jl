function get_benders_cumulative_multicuts_expression(
		scuc_masterproblem::JuMP.Model, final_dual_subproblem_coefficient_results::Dict{Symbol, dual_subprob_expr_coefficient},
		NG::Int64, NT::Int64, NW::Int64, ND::Int64, NL::Int64)
	benders_cut = AffExpr(0)

	for (keys_name, coeff) in final_dual_subproblem_coefficient_results
		# println(keys_name)
		scuc_masterproblem, dual_expression_cut = get_benders_multicuts_expression(scuc_masterproblem, coeff, keys_name, NG, NT, NW, ND, NL)
		benders_cut += dual_expression_cut
	end
	return scuc_masterproblem, benders_cut
end
