
function reorginze_constraints_sets(all_constraints_dict)
	all_constr_lessthan_sets = Vector{T1}()
	all_constr_greaterthan_sets = Vector{T2}()
	all_constr_equalto_sets = Vector{T0}()
	for item in Dict(all_constraints_dict)
		if occursin("EqualTo", string(typeof(item[2])))
			push!(all_constr_equalto_sets, item[2])
		elseif occursin("LessThan", string(typeof(item[2])))
			push!(all_constr_lessthan_sets, item[2])
		elseif occursin("GreaterThan", string(typeof(item[2])))
			push!(all_constr_greaterthan_sets, item[2])
		else
			println("check it, not the regular MOP type in the all_constraints_dict")
		end
	end
	return all_constr_lessthan_sets, all_constr_greaterthan_sets, all_constr_equalto_sets
end
