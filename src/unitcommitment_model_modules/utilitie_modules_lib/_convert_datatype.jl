function convert_constraints_type_to_vector(x)
	if typeof(x) <: AbstractVector
		if isa(x, Vector{Any})
			x = vec(x)
		end
	end
	return x
end

function check_constrainsref_type(x)
	if !(typeof(x) <: AbstractVector && isa(x, Vector{Any}))
		println("this is the vector{Any} of the constraints, needs to be converted to vector{ConstraintRef}`")
	end
end
