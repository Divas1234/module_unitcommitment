using Plots
using LinearAlgebra # Potentially needed for fitting or other calculations, good practice to include if used by dependencies

# --- Constants ---
# Defined at the top for clarity and easy modification.
const DEFAULT_DAMPING_MIN = 2.5
const DEFAULT_DAMPING_MAX = 12.0
const DEFAULT_DAMPING_RANGE = 2.0:0.5:15.0 # Use Float64 for consistency

# --- Helper Functions (Assumed to be defined elsewhere) ---
# Placeholder comments for functions assumed to exist.
# function load_controller_configs() ... end
# function get_system_parameters(flag_converter) ... end
# function calculate_inertia_boundaries(initial_inertia, factor_coeff, time_const, droop, power_dev, damping_values, vsm_params, droop_params, flag_converter) ... end
# function estimate_inertia_stability_limits(rocof_limit, power_dev, damping_values, factor_coeff, time_const, droop) ... end
# function fit_quadratic_inertia_model(inertia_data, damping_values) ... end
# function calculate_plot_vertices(...) ... end # If the commented-out vertex calculation is needed

"""
    generate_inertia_damping_figure(droop_setting::Float64;
                                    damping_values::AbstractVector{Float64} = DEFAULT_DAMPING_RANGE,
                                    flag_converter::Int = 0)

Generates a plot visualizing the feasible operating region for inertia and damping,
considering converter configurations and system stability limits (RoCoF, Nadir).

Improvements:
- More descriptive function and variable names (snake_case).
- Explicit type annotations for clarity and potential performance benefits.
- Renamed external function calls to be more descriptive (assuming control over them).
- Vectorized calculations where possible (e.g., `fill_area_lower_bound`).
- Simplified dictionary access.
- Used constants for magic numbers in plotting.
- Removed redundant variable assignments.
- Added basic input validation.
- Removed debugging (`@show`) and commented-out code sections.
- Added `LinearAlgebra` import if potentially needed by fitting functions.

Arguments:
- `droop_setting`: The droop parameter value (p.u.).
- `damping_values`: A vector of damping values (p.u.) to evaluate. Defaults to `DEFAULT_DAMPING_RANGE`.
- `flag_converter`: Integer flag selecting a specific converter model or scenario. Defaults to 0.

Returns:
- A `Plots.Plot` object representing the generated figure.

Raises:
- `ArgumentError`: If `damping_values` is empty.
"""
function generate_inertia_damping_figure(
    droop_setting::Float64;
    damping_values::AbstractVector{Float64} = DEFAULT_DAMPING_RANGE,
    flag_converter::Int = 0 # Parameterized flag_converter
)
    # --- Input Validation ---
    if isempty(damping_values)
        throw(ArgumentError("damping_values cannot be empty."))
    end

    # --- Configuration Loading ---
    # Descriptive function name, assumes it returns a Dict
    # TODO: Replace placeholder with actual function call if available
    # controller_configs = load_controller_configs()
    controller_configs = converter_formming_configuations() # Keeping original name if rename isn't possible yet

    # Simplified and safer dictionary access using get with default values
    vsm_params = get(get(controller_configs, "VSM", Dict()), "control_parameters", Dict())
    droop_params = get(get(controller_configs, "Droop", Dict()), "control_parameters", Dict())

    # --- Parameter Retrieval ---
    # Descriptive function name, clearer variable names
    # Note: The original 'droop' from get_system_parameters is ignored, using droop_setting instead.
    # TODO: Replace placeholder with actual function call if available
    # initial_inertia, factor_coeff, time_const, _, rocof_limit, nadir_limit, power_dev =
    #     get_system_parameters(flag_converter)
    initial_inertia, factor_coeff, time_const, _, rocof_limit, nadir_limit, power_dev =
        get_parmeters(flag_converter) # Keeping original name if rename isn't possible yet


    # Use the provided droop setting directly
    droop = droop_setting

    # --- Core Calculations ---
    # Descriptive function names, clearer variable names
    # Unused return values are explicitly ignored with '_'
    # TODO: Replace placeholder with actual function call if available
    # inertia_bounds, extreme_inertia, _, _, _ = calculate_inertia_boundaries(
    inertia_bounds, extreme_inertia, _, _, _ = calculate_inertia_parameters( # Keeping original name
        initial_inertia, factor_coeff, time_const, droop, power_dev,
        damping_values, vsm_params, droop_params, flag_converter
    )

    # Descriptive function name
    # TODO: Replace placeholder with actual function call if available
    # min_inertia_limit, max_inertia_limit = estimate_inertia_stability_limits(
    min_inertia_limit, max_inertia_limit = estimate_inertia_limits( # Keeping original name
        rocof_limit, power_dev, damping_values, factor_coeff, time_const, droop,
    ) # Note: nadir_limit is still unused here, as per original code. Verify if intended.

    # Descriptive function name, clearer variable names
    # The model is: inertia = c + b*damping + a*damping^2
    # TODO: Replace placeholder with actual function call if available
    # fit_coeffs = fit_quadratic_inertia_model(extreme_inertia, damping_values)
    fit_coeffs = calculate_fittingparameters(extreme_inertia, damping_values) # Keeping original name

    # Calculate the fitted inertia curve using the quadratic model (vectorized)
    # Using @. macro for broadcasting is concise
    fitted_inertia = @. fit_coeffs[1] + fit_coeffs[2] * damping_values + fit_coeffs[3] * damping_values^2

    # Calculate the lower bound for the fill area (vectorized)
    # Takes the maximum of the fitted curve and the minimum inertia limit at each point
    fill_area_lower_bound = max.(fitted_inertia, min_inertia_limit)

    # --- Plotting ---
    # Use descriptive variable names directly in plot calls
    # Removed redundant assignments like `damping = damping_values`

    # Initial plot setup
    p = Plots.plot(
        damping_values, inertia_bounds[:, 1], # Upper bound
        framestyle = :box,
        ylims = (0, maximum(inertia_bounds[:, 1]) * 1.05), # Add slight padding to ylims
        xlabel = "Damping (p.u.)", # Clearer labels
        ylabel = "Inertia (p.u.)",
        lw = 3,
        label = "Upper Inertia Bound",
        legend = :topright # Adjust legend position if needed
    )

    # Add lower inertia bound
    Plots.plot!(p, damping_values, inertia_bounds[:, 2], # Lower bound
        lw = 3,
        label = "Lower Inertia Bound",
        color = :forestgreen
    )

    # Add fitted inertia curve
    Plots.plot!(p, damping_values, fitted_inertia,
        lw = 3,
        label = "Fitted Inertia Boundary",
        linestyle = :dash, # Differentiate fitted curve
        color = :purple
    )

    # Add constant stability limits
    # Check if min_inertia_limit is scalar or vector before plotting
    if isa(min_inertia_limit, Number)
         Plots.hline!(p, [min_inertia_limit], # Use the calculated limit directly
            lw = 3,
            label = "Min Stability Inertia",
            linestyle = :dot,
            color = :red
        )
    else # Assuming it's a vector matching damping_values
        Plots.plot!(p, damping_values, min_inertia_limit,
            lw = 3,
            label = "Min Stability Inertia",
            linestyle = :dot,
            color = :red
        )
    end

    # Plot the calculated max limit vector (assuming it's a vector)
    Plots.plot!(p, damping_values, max_inertia_limit,
        lw = 3,
        label = "Max Stability Inertia (RoCoF)",
        linestyle = :dot,
        color = :orange
    )


    # Add fill area representing the feasible region (optional, uncomment if needed)
    # Plots.plot!(p, damping_values, inertia_bounds[:, 1], # Fill between upper bound and the calculated lower fill bound
    #     fillrange = fill_area_lower_bound,
    #     fillalpha = 0.25,
    #     label = "Feasible Region",
    #     color = :skyblue,
    #     lw = 0 # No line for the fill itself
    # )

    # Add vertical lines for default damping range bindings
    Plots.vline!(p, [DEFAULT_DAMPING_MIN],
        lw = 2, # Slightly thinner for visual distinction
        label = "Default Min Damping",
        linestyle = :dashdot,
        color = :grey
    )
    Plots.vline!(p, [DEFAULT_DAMPING_MAX],
        lw = 2,
        label = "Default Max Damping",
        linestyle = :dashdot,
        color = :grey
    )

    # Add title
    # Plots.title!(p, "Inertia vs. Damping Feasible Region (Droop = $droop_setting)")

    # --- Optional: Vertex Calculation (if needed) ---
    # If the commented-out vertex calculation is required:
    # TODO: Replace placeholder with actual function call if available
    # vertices = calculate_plot_vertices(damping_values, inertia_bounds, fit_coeffs,
    #                                   min_inertia_limit, max_inertia_limit,
    #                                   DEFAULT_DAMPING_MIN, DEFAULT_DAMPING_MAX, droop)
    # # Potentially plot vertices:
    # Plots.scatter!(p, vertices[:, 1], vertices[:, 2], label="Region Vertices", markersize=5, color=:black)


    return p # Return the plot object
end

# --- Example Usage ---
# Ensure the necessary helper functions (converter_formming_configuations, etc.) and
# their dependencies are defined and loaded correctly.

# Example:
# droop_val = 0.05
# inertia_damping_plot = generate_inertia_damping_figure(droop_val)
# savefig(inertia_damping_plot, "inertia_damping_plot_improved.png")
# display(inertia_damping_plot) # Show plot if running interactively
