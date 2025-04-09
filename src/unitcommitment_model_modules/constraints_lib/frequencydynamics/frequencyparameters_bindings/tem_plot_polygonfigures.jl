using Plots
using DelimitedFiles
using GeometryBasics
using QHull
using Printf # For formatted output filenames

const MIN_POINTS_FOR_HULL = 3 # Minimum points needed for a 2D convex hull

"""
	load_vertices(data_file::String)

Loads vertex data from a text file.
Returns a matrix of vertices or throws an error if loading fails.
"""
function load_vertices(data_file::String)::Matrix{Float64}
	if !isfile(data_file)
		error("Vertex data file not found: $data_file")
	end
	try
		vertices = readdlm(data_file)
		if isempty(vertices)
			error("Vertex data file is empty: $data_file")
		end
		if size(vertices, 2) != 3
			error("Vertex data must have 3 columns (x, y, z), found $(size(vertices, 2)) in $data_file")
		end
		return Matrix{Float64}(vertices) # Ensure type stability
	catch e
		error("Failed to read vertex data from $data_file: $e")
	end
end

"""
	group_points_by_x(vertices::Matrix{Float64})

Groups vertices by their unique x-coordinates.
Returns a dictionary mapping x-coordinate to a matrix of points at that x.
"""
function group_points_by_x(vertices::Matrix{Float64})::Dict{Float64, Matrix{Float64}}
	grouped_points = Dict{Float64, Matrix{Float64}}()
	for i in 1:size(vertices, 1)
		x = vertices[i, 1]
		point_row = vertices[i:i, :] # Keep as a 1xN matrix slice
		if haskey(grouped_points, x)
			grouped_points[x] = vcat(grouped_points[x], point_row)
		else
			grouped_points[x] = point_row
		end
	end
	return grouped_points
end

"""
	plot_convex_hull_slice!(plt::Plots.Plot, points_at_x::Matrix{Float64})

Calculates and plots the 2D convex hull (y-z plane) for a given set of points sharing the same x-coordinate.
Modifies the input plot object `plt`.
"""
function plot_convex_hull_slice!(plt::Plots.Plot, points_at_x::Matrix{Float64})
	num_points = size(points_at_x, 1)
	current_x = points_at_x[1, 1] # All points share the same x

	if num_points < MIN_POINTS_FOR_HULL
		# @warn "Skipping convex hull for x=$current_x due to insufficient points ($num_points < $MIN_POINTS_FOR_HULL)"
		return false # Indicate hull was not plotted
	end

	# Extract y-z coordinates for convex hull calculation
	yz_points = points_at_x[:, 2:3]

	try
		hull = chull(yz_points)
		hull_indices = hull.vertices # Indices relative to yz_points (and thus points_at_x)

		# Ensure hull has at least 3 vertices to form a polygon
		if length(hull_indices) < MIN_POINTS_FOR_HULL
			# @warn "Skipping convex hull for x=$current_x as hull calculation resulted in < $MIN_POINTS_FOR_HULL vertices (possibly collinear points)."
			return false # Indicate hull was not plotted
		end

		# Get the points corresponding to the hull vertices in their original 3D space
		hull_points_3d = points_at_x[hull_indices, :]

		# Plot the edges of the convex hull polygon
		n_hull = size(hull_points_3d, 1)
		for i in 1:n_hull
			current_point = hull_points_3d[i, :]
			# Connect to the next point, wrapping around to the first
			next_point = hull_points_3d[mod1(i + 1, n_hull), :]

			plot!(plt,
				[current_point[1], next_point[1]],
				[current_point[2], next_point[2]],
				[current_point[3], next_point[3]],
				color = :red,
				linewidth = 0.5,
				alpha = 0.8,
				label = "", # Avoid adding legend entries for each segment
			)
		end
		return true # Indicate hull was plotted
	catch e
		@warn "Convex hull calculation failed for x=$current_x: $e"
		return false # Indicate hull was not plotted
	end
end


"""
	plot_polygon_figures(data_dir::String, output_dir::String; filename_base::String="polygon_figure")

Loads 3D vertex data, plots the points, and overlays 2D convex hulls (in y-z) for each unique x-slice.
Saves the resulting plot to PDF and PNG formats.

# Arguments
- `data_dir::String`: Directory containing the 'all_vertices.txt' file.
- `output_dir::String`: Directory where the output plots will be saved.
- `filename_base::String`: Base name for the output plot files (without extension). Defaults to "polygon_figure".

# Returns
- `Plots.Plot`: The generated plot object.
"""
function plot_polygon_figures(data_dir::String, output_dir::String; filename_base::String = "polygon_figure")

	vertex_file = joinpath(data_dir, "all_vertices.txt")
	println("Loading vertices from: $vertex_file")
	vertices = load_vertices(vertex_file)
	println("Loaded $(size(vertices, 1)) vertices.")

	# --- Plot Initialization ---
	println("Initializing plot...")
	plt = plot(
		size = (600, 400), # Slightly larger for better detail
		dpi = 300,
		background = :white,
		legend = false, # No legend needed for hull segments
		grid = true,    # Enable grid for better spatial understanding
		framestyle = :box, # Box frame for 3D
	)

	# --- Plot All Vertices ---
	println("Plotting all vertices...")
	scatter!(plt,
		vertices[:, 1], vertices[:, 2], vertices[:, 3],
		markersize = 1.5, # Slightly smaller markers
		markercolor = :darkgray,
		markerstrokewidth = 0.5,
		alpha = 0.7,      # Slightly more transparent
		label = "", # No label needed for scatter points if legend is off
	)

	# --- Group Points and Plot Hulls ---
	# Performance: Group points by x-coordinate first to avoid repeated filtering
	println("Grouping points by x-coordinate...")
	grouped_points = group_points_by_x(vertices)

	println("Plotting convex hulls for $(length(grouped_points)) unique x-slices...")
	num_hulls_plotted = 0
	plotted_hull_indices = [] # Keep track of which hulls were actually plotted

	# Sort keys to process slices in order (optional, but often desirable)
	sorted_x_coords = sort(collect(keys(grouped_points)))

	for x in sorted_x_coords
		points_at_x = grouped_points[x]
		if plot_convex_hull_slice!(plt, points_at_x)
			num_hulls_plotted += 1
			# push!(plotted_hull_indices, x) # If you need to know which ones
		end
	end
	println("Completed plotting $num_hulls_plotted hulls.")


	# --- Final Plot Styling ---
	println("Applying final plot styling...")
	plot!(plt,
		camera = (45, 30), # Adjust camera angle if needed
		xlabel = "Droop (p.u.)",
		ylabel = "Damping (p.u.)",
		zlabel = "Inertia (p.u.)",
		fontfamily = "Computer Modern", # Ensure this font is available on the system
		tickfontsize = 8,  # Slightly larger fonts
		guidefontsize = 10,
		# title = "Convex Hulls of Vertex Slices",
		titlefontsize = 12,
	)

	# --- Save and Display ---
	# Ensure output directory exists
	try
		if !isdir(output_dir)
			println("Creating output directory: $output_dir")
			mkpath(output_dir)
		end
	catch e
		error("Failed to create output directory '$output_dir': $e")
	end

	output_path_pdf = joinpath(output_dir, "$(filename_base).pdf")
	output_path_png = joinpath(output_dir, "$(filename_base).png")

	try
		println("Saving plot to $output_path_pdf")
		savefig(plt, output_path_pdf)
		println("Saving plot to $output_path_png")
		savefig(plt, output_path_png)
	catch e
		error("Failed to save plot: $e")
	end

	# Display the plot (optional, uncomment if needed in interactive sessions)
	# display(plt)

	println("Plot generation complete.")
	return plt # Return the plot object
end

# Example Usage:
# Needs to be called from another script or REPL.
# Assuming 'res' directory is in the current working directory or accessible path.
#=
if abspath(PROGRAM_FILE) == @__FILE__
	println("Running example usage...")
	data_directory = "res"
	output_directory = "res" # Or specify a different output location, e.g., "output_plots"
	try
		plot_polygon_figures(data_directory, output_directory, filename_base="polygon_scientific_improved")
		println("Example finished successfully.")
	catch e
		println("Error during example execution: ", e)
	end
end
=#
