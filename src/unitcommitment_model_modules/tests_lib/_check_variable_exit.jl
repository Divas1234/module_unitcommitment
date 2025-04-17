function check_var_exists(model::Model, name::String)
	return any(v -> v == name, all_variables(model))
end
