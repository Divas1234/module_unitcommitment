using Pkg
Pkg.activate("./.pkg")
include("src/environment_config.jl")
include("src/formatteddata.jl")
include("src/renewableenergysimulation.jl")
include("src/showboundrycase.jl")
include("src/readdatafromexcel.jl")
include("src/SUCuccommitmentmodel.jl")
include("src/casesploting.jl")
include("src/saveresult.jl")
include("src/generatefittingparameters.jl")
include("src/draw_onlineactivepowerbalance.jl")
include("src/draw_addditionalpower.jl")

# Destructure directly from function call for clarity
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet()

config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, DataCentras = forminputdata(
	DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data
)

winds, NW = genscenario(WindsFreqParam, 1)

boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, stroges)

# bench_x₀, bench_p₀, bench_pᵨ, bench_pᵩ, bench_seq_sr⁺, bench_seq_sr⁻, bench_pss_charge_p⁺, bench_pss_charge_p⁻, bench_su_cost, bench_sd_cost, bench_prod_cost, bench_cost_sr⁺, bench_cost_sr⁻ = SUC_scucmodel(
# 	NT, NB, NG, ND, NC, units, loads, winds, lines, config_param)

# savebalance_result(bench_p₀, bench_pᵨ, bench_pᵩ, bench_pss_charge_p⁺, bench_pss_charge_p⁻, 1)

ND2

# DEBUG - uc

if config_param.is_NetWorkCon == 1
	Adjacmatrix_BtoG, Adjacmatrix_B2D, Gsdf = linearpowerflow(units, lines, loads, NG, NB, ND, NL)
	Adjacmatrix_BtoW = zeros(NB, length(winds.index))
	for i in 1:length(winds.index)
		Adjacmatrix_BtoW[winds.index[i, 1], i] = 1
	end
end

NS = winds.scenarios_nums
NW = length(winds.index)

# creat scucsimulation_model
# scuc = Model(CPLEX.Optimizer)
scuc = Model(Gurobi.Optimizer)

# NS = 1 # for test

# binary variables
@variable(scuc, x[1:NG, 1:NT], Bin)
@variable(scuc, u[1:NG, 1:NT], Bin)
@variable(scuc, v[1:NG, 1:NT], Bin)

# continuous variables
@variable(scuc, pg₀[1:(NG * NS), 1:NT]>=0)
@variable(scuc, pgₖ[1:(NG * NS), 1:NT, 1:3]>=0)
@variable(scuc, su₀[1:NG, 1:NT]>=0)
@variable(scuc, sd₀[1:NG, 1:NT]>=0)
@variable(scuc, sr⁺[1:(NG * NS), 1:NT]>=0)
@variable(scuc, sr⁻[1:(NG * NS), 1:NT]>=0)
@variable(scuc, Δpd[1:(ND * NS), 1:NT]>=0)
@variable(scuc, Δpw[1:(NW * NS), 1:NT]>=0)

# pss variables
@variable(scuc, κ⁺[1:(NC * NS), 1:NT], Bin) # charge status
@variable(scuc, κ⁻[1:(NC * NS), 1:NT], Bin) # discharge status
@variable(scuc, pc⁺[1:(NC * NS), 1:NT]>=0)# charge power
@variable(scuc, pc⁻[1:(NC * NS), 1:NT]>=0)# discharge power
@variable(scuc, qc[1:(NC * NS), 1:NT]>=0) # cumsum power
# @variable(scuc, pss_sumchargeenergy[1:NC * NS, 1] >= 0)

# defination charging and discharging of BESS
@variable(scuc, α[1:(NS * NC), 1:NT], Bin)
@variable(scuc, β[1:(NS * NC), 1:NT], Bin)

# Linearize the fuel cost curve for the generators
refcost, eachslope = linearizationfuelcurve(units, NG)

# Cost parameters
c₀ = config_param.is_CoalPrice  # Base cost of coal
pₛ = scenarios_prob  # Probability of scenarios

# Penalty coefficients for load and wind curtailment
load_curtailment_penalty = config_param.is_LoadsCuttingCoefficient * 1e10
wind_curtailment_penalty = config_param.is_WindsCuttingCoefficient * 1e0

if config_param.is_ConsiderDataCentra == 1
	@variable(scuc, dc_p[1:(ND2 * NS), 1:NT]>=0)
	@variable(scuc, dc_f[1:(ND2 * NS), 1:NT]>=0)
	# @variable(scuc, dc_v[1:(ND2 * NS), 1:NT]>=0)
	@variable(scuc, dc_v²[1:(ND2 * NS), 1:NT]>=0)
	@variable(scuc, dc_λ[1:(ND2 * NS), 1:NT]>=0)
	@variable(scuc, dc_Δu1[1:(ND2 * NS), 1:NT]>=0)
	@variable(scuc, dc_Δu2[1:(ND2 * NS), 1:NT]>=0)
end

# if config_param.is_ConsiderDataCentra == 1
#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_p[((s - 1) * ND + 1):(s * ND), t].<=data_centra.p_max)
#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_p[((s - 1) * ND + 1):(s * ND), t].>=data_centra.p_min)
#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_p[((s - 1) * ND + 1):(s * ND), t].==data_centra.idle .+ data_centra.sv_constant .* dc_Δu2 / data_centra.μ)

#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu2[((s - 1) * ND + 1):(s * ND), t].<=dc_Δu1[((s - 1) * ND + 1):(s * ND), t])
#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu2[((s - 1) * ND + 1):(s * ND), t].<=dc_λ[((s - 1) * ND + 1):(s * ND), t])
#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu2[((s - 1) * ND + 1):(s * ND), t].>=dc_λ[((s - 1) * ND + 1):(s * ND), t] .+ dc_Δu1[((s - 1) * ND + 1):(s * ND), t] - 1)

#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu1[((s - 1) * ND + 1):(s * ND), t].<=dc_v²[((s - 1) * ND + 1):(s * ND), t])
#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu1[((s - 1) * ND + 1):(s * ND), t].<=dc_f[((s - 1) * ND + 1):(s * ND), t])
#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu1[((s - 1) * ND + 1):(s * ND), t].>=dc_v²[((s - 1) * ND + 1):(s * ND), t] .+ dc_f[((s - 1) * ND + 1):(s * ND), t] - 1)

#     iter_num = 6
#     iter_block = Int64(round(ND / ter_num))
#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_λ[((s - 1) * ND + 1):(s * ND), t].<=ones(ND, 1))
#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_f[((s - 1) * ND + 1):(s * ND), t].<=ones(ND, 1))
#     @constraint(scuc, [s = 1:NS, t = 1:NT], dc_v²[((s - 1) * ND + 1):(s * ND), t].<=ones(ND, 1))
#     @constraint(scuc, [s = 1:NS, t = 1:NT, iter = 1:iter_num],
#         sum(dc_λ[((s - 1) * ND + 1):(s * ND), ((iter - 1) * iter_block + 1):(ter * iter_block)]).==data_centra.λ[:, ((iter - 1) * iter_block + 1):(ter * iter_block)])
# end

@constraint(scuc, [s = 1:NS, t = 1:NT], dc_p[((s - 1) * ND2 + 1):(s * ND2), t].<=DataCentras.p_max)
DataCentras.p_max
# ND = 8
@constraint(scuc, [s = 1:NS, t = 1:NT], dc_p[((s - 1) * ND2 + 1):(s * ND2), t].>=DataCentras.p_min)
@constraint(scuc, [s = 1:NS, t = 1:NT], dc_p[((s - 1) * ND2 + 1):(s * ND2), t].==DataCentras.idale .+ DataCentras.sv_constant .* dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t] ./ DataCentras.μ)

@constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t].<=dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t])
@constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t].<=dc_λ[((s - 1) * ND2 + 1):(s * ND2), t])
@constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t].>=dc_λ[((s - 1) * ND2 + 1):(s * ND2), t] .+ dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t] - ones(ND2, 1))

@constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t].<=dc_v²[((s - 1) * ND2 + 1):(s * ND2), t])
@constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t].<=dc_f[((s - 1) * ND2 + 1):(s * ND2), t])
@constraint(scuc, [s = 1:NS, t = 1:NT], dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t].>=dc_v²[((s - 1) * ND2 + 1):(s * ND2), t] .+ dc_f[((s - 1) * ND2 + 1):(s * ND2), t] - ones(ND2, 1))

iter_num = 6
iter_block = Int64(round(NT / iter_num))
@constraint(scuc, [s = 1:NS, t = 1:NT], dc_λ[((s - 1) * ND2 + 1):(s * ND2), t].<=ones(ND2, 1))
@constraint(scuc, [s = 1:NS, t = 1:NT], dc_f[((s - 1) * ND2 + 1):(s * ND2), t].<=ones(ND2, 1))
@constraint(scuc, [s = 1:NS, t = 1:NT], dc_v²[((s - 1) * ND2 + 1):(s * ND2), t].<=ones(ND2, 1))
@constraint(scuc, [s = 1:NS, t = 1:NT, iter = 1:iter_num],
	sum(dc_λ[((s - 1) * ND2 + 1):(s * ND2),
		((iter - 1) * iter_block + 1):(iter * iter_block)]).==sum(DataCentras.λ) .* DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])
