using Pkg
Pkg.activate(".Pkg/")

neededPackages = [:FileIO, :LinearAlgebra, :LinearAlgebra, :Random, :GLM, :Plots, :DelimitedFiles, :GeometryBasics, :QHull,
				  :Printf]

# Make sure all needed Pkg's are ready to go
for neededpackage in neededPackages
	(String(neededpackage) in keys(Pkg.project().dependencies)) || Pkg.add(String(neededpackage))
	# @eval using $neededpackage
end

using Plots, PlotThemes
using LinearAlgebra

gr()
# theme(:wong2)


include("_boundary.jl")
include("_inertia_response.jl")
include("_primary_frequencyresponse.jl")
include("_analytical_systemfrequencyresponse.jl")
include("_inertia_damping_regressionrelations.jl")
# include("_visulazations.jl")
include("_converter_config.jl")
include("_generate_geometries.jl")
# include("_tem_plot_polygonfigures.jl")

# Constants (could also be in environment_config.jl)
const DAMPING_RANGE = 2:0.25:15
const MIN_DAMPING = minimum(DAMPING_RANGE)
const MAX_DAMPING = maximum(DAMPING_RANGE)

# Constants for the formulas
const PERCENTAGE_BASE = 100
const FREQUENCY_BASE = 50
current_filepath = pwd()
# const OUTPUT_REL_PATH = joinpath(current_filepath, "\\res\\all_vertices.txt")
const OUTPUT_REL_PATH = "res/all_vertices.txt"
