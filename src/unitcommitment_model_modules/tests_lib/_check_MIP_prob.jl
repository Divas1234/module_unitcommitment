using JuMP

"""
    is_mixed_integer_problem(model::Model)::Bool

Check if a JuMP model is a mixed-integer programming (MIP) problem.

A model is considered a MIP if it contains at least one integer or binary variable.

# Arguments
- `model::Model`: The JuMP model to check.

# Returns
- `Bool`: `true` if the model is a MIP, `false` otherwise.
"""
function is_mixed_integer_problem(model::Model)::Bool
    has_integer_variable = any(is_integer(v) || is_binary(v) for v in all_variables(model))
    if has_integer_variable
        println("The model is a mixed-integer programming (MIP) problem.")
        return true
    else
        println("The model is a linear programming (LP) problem.")
        return false
    end
end
