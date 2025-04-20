
function reorginze_constraints_sets(all_constraints_dict)
	# all_constr_lessthan_sets = Vector{T1}()
	# all_constr_greaterthan_sets = Vector{T2}()
	# all_constr_equalto_sets = Vector{T0}()
	# for item in Dict(all_constraints_dict)
	# 	if occursin("EqualTo", string(typeof(item[2])))
	# 		push!(all_constr_equalto_sets, item[2])
	# 	elseif occursin("LessThan", string(typeof(item[2])))
	# 		push!(all_constr_lessthan_sets, item[2])
	# 	elseif occursin("GreaterThan", string(typeof(item[2])))
	# 		push!(all_constr_greaterthan_sets, item[2])
	# 	else
	# 		println("check it, not the regular MOI type in the all_constraints_dict",item[1])
	#         @info tem[1]:: typeof(item[2])
	# 	end
	# end

	all_constr_lessthan_sets = Dict{Any, T1}()
	all_constr_greaterthan_sets = Dict{Any, T2}()
	all_constr_equalto_sets = Dict{Any, T0}()

	for (key, constr) in all_constraints_dict
		constr_type_str = string(typeof(constr))
		if occursin("EqualTo", constr_type_str)
			all_constr_equalto_sets[key] = constr
		elseif occursin("LessThan", constr_type_str)
			all_constr_lessthan_sets[key] = constr
		elseif occursin("GreaterThan", constr_type_str)
			all_constr_greaterthan_sets[key] = constr
		else
			println("Check this constraint – not a regular MOI type: ", key)
			@info key typeof(constr)
		end
	end

	return all_constr_lessthan_sets, all_constr_greaterthan_sets, all_constr_equalto_sets
end
