include("_check_validata_input.jl")
include("_check_variable_exit.jl")
include("_check_MIP_prob.jl")

export validate_inputs, check_var_exists, is_mixed_integer_problem

println("all boundary conditions validated.")
