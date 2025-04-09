# using Pkg # No need to activate Pkg here.
# Pkg.activate(".Pkg/") # No need to activate Pkg here.

# using GeometryBasics # No need to import it again.
using FileIO
using DelimitedFiles
# using GLMakie # No need to import it again.

function load_geometry_from_txt(filepath)
	"""
	Loads vertex data from a text file and creates a Mesh object.

	Args:
		filepath (str): Path to the text file containing vertex data.

	Returns:
		Mesh: A GeometryBasics.Mesh object representing the geometry, or nothing if there is no valid data.
	"""
	try
		# Read the data from the text file
		vertices_data = readdlm(filepath, ' ', Float64)
		if isempty(vertices_data)
			println("Warning: File $filepath is empty.")
			return nothing
		end
		if size(vertices_data, 2) != 3
			println("Warning: File $filepath is not a n*3 matrix, it is $(size(vertices_data))")
			return nothing
		end

		# Convert the data to Point3f0 vertices
		vertices = [Point3f0(row[1], row[2], row[3]) for row in eachrow(vertices_data)]

		# Check if there are enough vertices to form a triangle
		if length(vertices) < 3
			println("Warning: File $filepath does not contain enough vertices (at least 3) to form a triangle.")
			return nothing
		end

		# Create faces (triangles). Assuming vertices form a triangulated surface.
		# We'll triangulate assuming a fan pattern from the first vertex.
		faces = []
		for i in 2:(length(vertices) - 1)
			push!(faces, TriangleFace{Int}(1, i, i + 1))
		end

		# Construct the mesh
		mesh = GeometryBasics.Mesh(vertices, faces)

		return mesh

	catch e
		println("Error processing file $filepath: $e")
		return nothing
	end
end

function draw_geometry(res_path)
	"""
	Reads and draws geometry from text files in the specified directory.

	Args:
		res_path (str): Path to the directory containing text files.
	"""
	res_folder = res_path[1:(findlast(x -> x == '\\', res_path) - 1)]

	# Get all text files in the directory
	txt_files = filter(f -> endswith(f, ".txt"), readdir(res_folder, join = true))

	if isempty(txt_files)
		println("No .txt files found in directory: $res_path")
		return
	end

	meshes = []
	for file in txt_files
		mesh = load_geometry_from_txt(file)
		if !isnothing(mesh)
			push!(meshes, mesh)
		end
	end
	if isempty(meshes)
		println("No valid meshes were loaded.")
		return
	end

	# Create a Makie figure and axis
	fig = Figure()
	ax = Axis3(fig[1, 1], aspect = :data)

	# Draw the mesh using GLMakie
	for mesh in meshes
		mesh!(ax, mesh, color = :blue, transparency = true)
		wireframe!(ax, mesh, color = :black)
	end

	# Update the scene to fit the geometry
	if !isempty(meshes)
		limits = GeometryBasics.boundingbox(meshes[1]) # fix boundingbox
		for i in eachindex(meshes)[2:end]
			limits = union(limits, GeometryBasics.boundingbox(meshes[i]))
		end
		limits!(ax, limits)
	end

	# Display the figure
	display(fig)

	return
end
