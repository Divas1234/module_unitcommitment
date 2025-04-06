# using Pkg
# Pkg.activate("./.pkg")
# Pkg.add([
# 	"Revise", "JuMP", "Gurobi", "Test", "DelimitedFiles", "PlotlyJS",
# 	"LaTeXStrings", "Plots", "JLD", "DataFrames", "Clustering",
# 	"StatsPlots"
# ])
using Revise, JuMP, Gurobi, Test, DelimitedFiles, LaTeXStrings, Plots, DataFrames,
	  Clustering, StatsPlots, CSV
gr()
using Random
Random.seed!(1234)


# files_to_include = [
# 	"formatteddata.jl",
# 	"renewableenergysimulation.jl",
# 	"showboundrycase.jl",
# 	"readdatafromexcel.jl",
# 	"SUCuccommitmentmodel.jl",
# 	"casesploting.jl",
# 	"saveresult.jl",
# 	"generatefittingparameters.jl",
# 	"draw_onlineactivepowerbalance.jl",
# 	"draw_addditionalpower.jl"
# ]
# for file in files_to_include
# 	include(file)
# end
