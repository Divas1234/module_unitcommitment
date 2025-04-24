include("_check_validata_input.jl")
include("_check_variable_exit.jl")
include("_check_MIP_prob.jl")
include("_MOI_constraintREF_temple.jl")

export validate_inputs, check_var_exists, is_mixed_integer_problem

println("\t\u2192 all boundary conditions validated.")
