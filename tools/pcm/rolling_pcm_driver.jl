"""
固定窗口 PCM 的公共滚动驱动。

调用入口必须预先注入：
- `PCM_WINDOW_SOLVER`：单个滚动窗口的求解函数；
- `PCM_FORMULATION_NAME`：用于日志审计的方法名称。

本文件只管理数据读取、随机场景、窗口边界、结果累计和落盘，不决定采用
物理单机模型还是聚类模型。
"""

isdefined(@__MODULE__, :PCM_WINDOW_SOLVER) ||
	error("PCM_WINDOW_SOLVER is not configured; run a method-specific PCM entrypoint")
isdefined(@__MODULE__, :PCM_FORMULATION_NAME) ||
	error("PCM_FORMULATION_NAME is not configured; run a method-specific PCM entrypoint")

include("../../src/renewableresource_modules/stochasticsimulation.jl")
include("../../src/read_inputdata_modules/readdatas.jl")
include("standard_pcm/period_scuc.jl")
include("config/load_profiles.jl")

using Random

PCM_RANDOM_SEED = parse(Int, get(ENV, "PCM_RANDOM_SEED", "20260809"))
Random.seed!(PCM_RANDOM_SEED)
println("  PCM random seed: $PCM_RANDOM_SEED")

println("\n" * "="^80)
println("Step 1: Reading input data from Excel file...")
println("="^80)
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve,
DataLoad, Datacentra_Data, HydroData, HydroCurve = readxlssheet()

println("\n" * "="^80)
println("Step 2: Formatting input data for optimization model...")
println("="^80)
config_param, units, lines, loads, stroges, NB, NG, NL, ND, NT, NC, ND2, NH,
DataCentras, hydros = forminputdata(
	DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam,
	StrogeData, Datacentra_Data, HydroData, HydroCurve)
config_param.is_NetWorkCon = parse(Int, get(ENV, "PCM_NETWORK_CONSTRAINTS", "0"))
apply_pcm_load_profile!(loads, get(ENV, "PCM_LOAD_PROFILE", "baseline"))
println("  PCM load profile: $(get(ENV, "PCM_LOAD_PROFILE", "baseline"))")
println("  PCM network constraints: $(config_param.is_NetWorkCon == 1 ? "enabled" : "disabled")")

println("\n" * "="^80)
println("Step 3: Generating wind power scenarios...")
println("="^80)
winds, NW = genscenario(WindsFreqParam, 0)
scenarios_prob = 1.0 / winds.scenarios_nums

println("\n" * "="^80)
println("Step 4: Configuring sequential scheduling parameters...")
println("="^80)
mini_NT = parse(Int, get(ENV, "PCM_WINDOW_HOURS", "24"))
patch_scheduling_ids_numssets = parse(Int, get(ENV, "PCM_INTERVALS", "7"))
println("  Formulation: $PCM_FORMULATION_NAME")
println("  Scheduling intervals: $patch_scheduling_ids_numssets")
println("  Time periods per interval: $mini_NT")
println("  Total planning horizon: $(patch_scheduling_ids_numssets * mini_NT) periods")

total_scheduled_cost = zeros(patch_scheduling_ids_numssets + 1, 7)
pre_scheduling_results = Dict{String, Array{Float64}}()

println("\n" * "="^80)
println("Step 5: Running sequential unit commitment optimization...")
println("="^80)
pcm_simulation_start = time()

for interval_scheduling_id in 1:patch_scheduling_ids_numssets
	global pre_scheduling_results
	println("\n" * "-"^80)
	println("Processing scheduling interval $interval_scheduling_id of $patch_scheduling_ids_numssets...")
	println("-"^80)

	mini_units, mini_loads, mini_winds = update_boundary_conditions(
		interval_scheduling_id, NG, mini_NT, units, loads, winds, pre_scheduling_results)
	poster_scheduling_results = PCM_WINDOW_SOLVER(
		mini_NT, NB, NG, ND, NC, ND2, mini_units, mini_loads, mini_winds, lines,
		DataCentras, config_param, stroges, scenarios_prob, NL,
		interval_scheduling_id, hydros, NH)
	poster_scheduling_results === nothing &&
		error("Optimization failed for interval $interval_scheduling_id")

	if haskey(poster_scheduling_results, "res_scheduled_costs")
		total_scheduled_cost[interval_scheduling_id, :] = poster_scheduling_results["res_scheduled_costs"]
		println("  ✓ Interval $interval_scheduling_id optimization completed successfully")
	else
		println("  ⚠ Warning: No cost data found for interval $interval_scheduling_id")
	end

	save_powerbalance_scheduled_results(
		mini_units, mini_winds, config_param, poster_scheduling_results,
		interval_scheduling_id)
	pre_scheduling_results = poster_scheduling_results
end

PCM_OFFLINE_PREPROCESS_TIME_SEC = isdefined(@__MODULE__, :PCM_CLUSTER_PREPROCESS_TIME_SEC) ?
								  PCM_CLUSTER_PREPROCESS_TIME_SEC[] : 0.0
PCM_SIMULATION_TIME_SEC = max(0.0, time() - pcm_simulation_start - PCM_OFFLINE_PREPROCESS_TIME_SEC)
PCM_ML_TRAINING_TIME_SEC = 0.0

println("\n" * "="^80)
println("Step 6: Aggregating total scheduling costs...")
println("="^80)
total_scheduled_cost[end, :] = sum(total_scheduled_cost[1:(end - 1), :]; dims = 1)
outdir = creat_outputfilepath(-1, 1)
write_result(outdir, "total_scheduled_results.csv", round.(total_scheduled_cost; digits = 5))

println("  ✓ Sequential PCM ($PCM_FORMULATION_NAME) completed successfully")
println("  Total intervals processed: $patch_scheduling_ids_numssets")
println("  Results saved to: $outdir")
