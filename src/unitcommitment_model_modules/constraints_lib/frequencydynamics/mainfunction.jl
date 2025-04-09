include("_automatic_workflow.jl")

# --- Main Script Execution ---

# converter_formming_configuations
controller_config = converter_formming_configuations()

# --- Enhanced Error Handling and Logging ---
if !haskey(controller_config, "VSM") || !haskey(controller_config, "Droop")
	error("Error: 'VSM' or 'Droop' keys are missing in the controller configuration.")
end

if !haskey(controller_config["VSM"], "control_parameters") ||
   !haskey(controller_config["Droop"], "control_parameters")
	error("Error: 'control_parameters' key is missing in 'VSM' or 'Droop' configuration.")
end

println("Controller configuration loaded successfully.")

flag_converter = Int64(0)

# 提取 vsm 参数
converter_vsm_parameters = get(controller_config, "VSM", Dict())["control_parameters"]
converter_droop_parameters = get(controller_config, "Droop", Dict())["control_parameters"]

# --- Enhanced Parameter Validation ---
function validate_parameters(params::Dict, param_names::Vector{String})
	for name in param_names
		if !haskey(params, name)
			error("Error: Missing parameter '$name' in configuration.")
		elseif !isa(params[name], Number)
			error("Error: Parameter '$name' must be a number.")
		elseif params[name] <= 0 && name != "droop"
			error("Error: Parameter '$name' must be positive.")
		end
	end
end

validate_parameters(converter_vsm_parameters, ["inertia", "damping", "time_constant"])
validate_parameters(converter_droop_parameters, ["droop", "time_constant"])

println("Converter parameters validated successfully.")

# Get parameters from boundary conditions
initial_inertia, factorial_coefficient, time_constant, droop, ROCOF_threshold, NADIR_threshold, power_deviation = get_parmeters(flag_converter)

# --- Enhanced Parameter Validation for get_parameters output ---
function validate_get_parameters_output(params::Tuple)
	param_names = ["initial_inertia", "factorial_coefficient", "time_constant",
				   "droop", "ROCOF_threshold", "NADIR_threshold", "power_deviation"]
	for (i, param) in enumerate(params)
		if !isa(param, Number)
			error("Error: Parameter '$(param_names[i])' from get_parameters must be a number.")
		end
		if param <= 0 && param_names[i] != "droop"
			error("Error: Parameter '$(param_names[i])' from get_parameters must be positive.")
		end
	end
end

validate_get_parameters_output((initial_inertia, factorial_coefficient, time_constant,
								droop, ROCOF_threshold, NADIR_threshold, power_deviation))

println("Parameters from get_parmeters validated successfully.")

# Calculate inertia parameters

# NOTE - reseting the droop value to 36.0 for testing purposes
# droop = 36.0

inertia_updown_bindings, extreme_inertia, nadir_vector, inertia_vector, selected_ids = calculate_inertia_parameters(initial_inertia, factorial_coefficient, time_constant, droop, power_deviation,
																													DAMPING_RANGE, converter_vsm_parameters, converter_droop_parameters, flag_converter)

println("Output from calculate_inertia_parameters validated successfully.")

# Estimate inertia limits
min_inertia, max_inertia = estimate_inertia_limits(ROCOF_threshold, power_deviation, DAMPING_RANGE, factorial_coefficient, time_constant, droop)

# --- Enhanced Output Validation for estimate_inertia_limits ---
if !isa(min_inertia, Number) || !isa(max_inertia, Array)
	error("Error: min_inertia and max_inertia must be numbers.")
end
if min_inertia >= maximum(max_inertia)
	error("Error: min_inertia must be less than max_inertia")
end

println("Output from estimate_inertia_limits validated successfully.")
println("Output from estimate_inertia_limits validated successfully.")

# p1 = data_visualization(DAMPING_RANGE, inertia_updown_bindings, extreme_inertia,
# 	nadir_vector, inertia_vector, selected_ids)

p1, sy1 = data_visualization(DAMPING_RANGE, inertia_updown_bindings, extreme_inertia,
							 nadir_vector, inertia_vector, selected_ids, max_inertia, min_inertia)

show(p1)
Plots.plot(sy1; size = (400, 400))
Plots.savefig(joinpath(pwd(), "fig/output_plot.png"))
Plots.savefig(joinpath(pwd(), "fig/output_plot.pdf"))

println("Calculations complete. Plot generated.")
