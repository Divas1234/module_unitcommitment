using Pkg

neededPackages = [:Revise, :JuMP, :Gurobi, :Test, :DelimitedFiles,
	:LaTeXStrings, :Plots, "JLD", :DataFrames, :Clustering, :XLSX,
	:StatsPlots, :Distributions, :CSV, :Random, :DataFrames, :MultivariateStats, :UnicodePlots, :DataStructures]

# Make sure all needed Pkg's are ready to go
for neededpackage in neededPackages
	(String(neededpackage) in keys(Pkg.project().dependencies)) || Pkg.add(String(neededpackage))
	# @eval using $neededpackage
end

using Revise, JuMP, Gurobi, Test, DelimitedFiles, LaTeXStrings, Plots, JLD, DataFrames, Clustering, StatsPlots, Distributions, CSV, Random,
	DataFrames, MultivariateStats, DataStructures

gr()
Random.seed!(1234)

println("\t\u2192 The [JULIA] environment_config has been loaded.")
# println("\n\n\n")
