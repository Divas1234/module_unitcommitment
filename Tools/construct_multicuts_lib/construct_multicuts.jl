include("_get_benders_multi_opti_feas_cuts.jl")
include("_get_RhsCoeffi_in_DIFFconstraints.jl")
include("_get_dual_subprob_constrs_coefficients.jl")

export add_optimitycut_constraints!, add_feasibilitycut_constraints!, get_dual_constrs_coefficient
export get_greater_than_constr_rhs, get_smaller_than_constr_rhs, get_equal_to_constr_rhs
export get_x_coeff_vectors_from_constr, get_u_coeff_vectors_from_constr, get_v_coeff_vectors_from_constr
export get_coeff_from_constr

println("\t\u2192 multicuts_libs have been loaded.")