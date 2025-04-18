const T1 = Vector{ConstraintRef{
	Model,
	MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}},
	ScalarShape
}}
const T2 = Vector{ConstraintRef{
	Model,
	MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.GreaterThan{Float64}},
	ScalarShape
}}
const T0 = Vector{ConstraintRef{
	Model,
	MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.EqualTo{Float64}},
	ScalarShape
}}
const ConType = ConstraintRef{
	Model,
	MOI.ConstraintIndex{MOI.ScalarAffineFunction{Float64}, MOI.LessThan{Float64}},
	ScalarShape
}
