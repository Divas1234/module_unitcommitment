using Pkg
Pkg.activate("./.pkg")

neededPackages = [
	:Revise, :JuMP, :Gurobi, :Test, :DelimitedFiles,
	:LaTeXStrings, :Plots, "JLD", :DataFrames, :Clustering,
	:StatsPlots, :Distributions, :CSV, :Random, :DataFrames, :MultivariateStats
]

# Make sure all needed Pkg's are ready to go
for neededpackage in neededPackages
	(String(neededpackage) in keys(Pkg.project().dependencies)) || Pkg.add(String(neededpackage))
	# @eval using $neededpackage
end

using Revise, JuMP, Gurobi, Test, DelimitedFiles, LaTeXStrings, Plots, JLD, DataFrames, Clustering, StatsPlots, Distributions, CSV, Random, DataFrames, MultivariateStats


gr()

Random.seed!(1234)

println("The [JULIA] environment_config has been loaded")
# println("\n\n\n")