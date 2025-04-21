function add_optimitycut_constraints!(scuc_masterproblem::JuMP.Model, sub_model_struct::SCUC_Model, ret, iter_value)
	# @assert termination_status(sub_model_struct[1].model)
	x⁽⁰⁾ = iter_value[1]
	u⁽⁰⁾ = iter_value[2]
	v⁽⁰⁾ = iter_value[3]
	add_optimity_cut = @constraint(scuc_masterproblem,
		scuc_masterproblem[:θ] >=
			ret.θ + sum(
			ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) +
			ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)
		))
	return scuc_masterproblem, add_optimity_cut
end

function add_feasibilitycut_constraints!(scuc_masterproblem::JuMP.Model, sub_model_struct::SCUC_Model, ret, iter_value)
	@assert !(ret.is_feasible)
	# @assert !termination_status(sub_model_struct[1].model)
	x⁽⁰⁾ = iter_value[1]
	u⁽⁰⁾ = iter_value[2]
	v⁽⁰⁾ = iter_value[3]

	add_feasibility_cut = @constraint(scuc_masterproblem,
		ret.dual_θ + sum(
			ret.ray_x .* (scuc_masterproblem[:x] - x⁽⁰⁾) + ret.ray_u .* (scuc_masterproblem[:u] - u⁽⁰⁾) + ret.ray_v .* (scuc_masterproblem[:v] - v⁽⁰⁾)) <= 0)

	return scuc_masterproblem, add_feasibility_cut
end
