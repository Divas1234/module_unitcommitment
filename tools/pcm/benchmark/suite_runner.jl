module PCMThreeMethodBenchmark

using CSV
using DataFrames
using Dates
using DelimitedFiles
using Printf
using Statistics

export parse_list, cost_delta_pct, method_equivalent_units, read_cost_vector,
	   normalize_solver, aggregate_metrics, add_relative_metrics, extract_cluster_intermediate,
	   extract_adaptive_intermediate, profile_dir_name, method_dir_name, run_dir_name,
	   benchmark_run_dir, benchmark_batch_name, benchmark_output_root, run_one, write_report, rebuild_outputs, main

const PROJECT_ROOT = dirname(dirname(dirname(@__DIR__)))
const DEFAULT_METHODS = ["standard", "clustered_pcm", "adaptive_overlap", "clustered_adaptive_overlap"]
const DEFAULT_PROFILES = ["baseline", "smooth", "extreme_ramp"]

# 输出目录只使用短而稳定的英文标识；CSV 内仍保留完整名称，便于分析和审计。
const PROFILE_DIR_NAMES = Dict("baseline" => "base", "smooth" => "smooth", "extreme_ramp" => "ramp")
const METHOD_DIR_NAMES = Dict(
	"integrated_uc" => "uc_ref",
	"standard" => "std",
	"clustered_pcm" => "clu",
	"adaptive_overlap" => "ovl",
	"clustered_adaptive_overlap" => "clu_ovl")

profile_dir_name(profile::AbstractString) = get(PROFILE_DIR_NAMES, lowercase(profile), lowercase(profile))
method_dir_name(method::AbstractString) = get(METHOD_DIR_NAMES, lowercase(method), lowercase(method))
run_dir_name(run_number::Integer) = "r$(lpad(run_number, 2, '0'))"

const LOAD_DIR_NAMES = Dict("baseline" => "normal", "smooth" => "smooth", "extreme_ramp" => "extreme")

function benchmark_batch_name(methods, profiles; horizon_hours::Integer = 72,
		timestamp = Dates.format(now(), "yyyymmdd_HHMMSS"))
	length(profiles) == 1 || throw(ArgumentError(
		"Default output naming requires one load profile per run; run normal, smooth, and extreme separately."))
	load_name = get(LOAD_DIR_NAMES, lowercase(String(first(profiles))), lowercase(String(first(profiles))))
	comparison_count = count(method -> lowercase(String(method)) != "integrated_uc", methods)
	horizon_hours > 0 || throw(ArgumentError("horizon_hours must be positive"))
	return "pcm_com$(comparison_count)_load$(load_name)_h$(horizon_hours)_$(timestamp)"
end

"""
Return the standard batch directory: com0 tests are isolated; real comparisons stay at output root.
"""
function benchmark_output_root(project_root::AbstractString, methods, profiles;
		horizon_hours::Integer = 72, timestamp = Dates.format(now(), "yyyymmdd_HHMMSS"))
	batch_name = benchmark_batch_name(methods, profiles; horizon_hours, timestamp)
	comparison_count = count(method -> lowercase(String(method)) != "integrated_uc", methods)
	parent = comparison_count == 0 ? joinpath(project_root, "output", "test_res") : joinpath(project_root, "output")
	return abspath(joinpath(parent, batch_name))
end

function benchmark_run_dir(output_root::AbstractString, profile::AbstractString, method::AbstractString,
		run_number::Integer; existing::Bool = false)
	compact = joinpath(output_root, profile_dir_name(profile), method_dir_name(method), run_dir_name(run_number))
	(!existing || isdir(compact)) && return compact
	# 兼容旧批次，确保历史结果仍可重新汇总。
	legacy = joinpath(output_root, String(profile), lowercase(method), "run$(run_number)")
	return existing && isdir(legacy) ? legacy : compact
end

parse_list(value::AbstractString) = [strip(item) for item ∈ split(value, ',') if !isempty(strip(item))]

function normalize_solver(value::AbstractString)
	solver = lowercase(strip(value))
	solver in ("gurobi", "gurobi_direct") && return "gurobi"
	solver in ("glpk", "glpk_fallback") && return "glpk"
	solver == "auto" && return "auto"
	throw(ArgumentError("Unsupported PCM_SOLVER='$value'. Use gurobi, glpk, or auto."))
end

function cost_delta_pct(base, candidate)
	(ismissing(base) || ismissing(candidate) || base == 0) && return missing
	100.0 * (Float64(candidate) / Float64(base) - 1.0)
end

function method_equivalent_units(method::AbstractString, physical, virtual)
	lowercase(method) in ("clustered_pcm", "clustered_adaptive_overlap") ? virtual : physical
end

function read_cost_vector(path::AbstractString)
	isfile(path) || return nothing
	matrix = readdlm(path, ',', Float64)
	isempty(matrix) && return nothing
	Float64.(vec(matrix[end, :]))
end

function _safe_float(value)
	ismissing(value) && return missing
	value isa Number && return Float64(value)
	try
		Float64(value)
	catch
		missing
	end
end

function _safe_median(values)
	available = [_safe_float(value) for value ∈ values if !ismissing(_safe_float(value))]
	isempty(available) ? missing : median(available)
end

function _safe_mean(values)
	available = [_safe_float(value) for value ∈ values if !ismissing(_safe_float(value))]
	isempty(available) ? missing : mean(available)
end

function _safe_sum(values)
	available = [_safe_float(value) for value ∈ values if !ismissing(_safe_float(value))]
	isempty(available) ? 0.0 : sum(available)
end

_column_or_missing(data::AbstractDataFrame, name::Symbol) = name ∈ propertynames(data) ? data[!, name] : fill(missing, nrow(data))

function aggregate_metrics(raw::DataFrame)
	rows = NamedTuple[]
	for group ∈ groupby(raw, [:profile, :method])
		status = String.(group.status)
		physical = _safe_median(group.physical_units)
		equivalent = _safe_median(group.equivalent_units)
		reduction = ismissing(physical) || ismissing(equivalent) || physical == 0 ? missing :
					100.0 * (1.0 - equivalent / physical)
		solver_value = first(_column_or_missing(group, :solver))
		push!(rows,
			(
				profile = String(first(group.profile)),
				method = String(first(group.method)),
				solver = ismissing(solver_value) ? "unknown" : String(solver_value),
				runs = nrow(group),
				successful_runs = count(==("OK"), status),
				success_rate_pct = 100.0 * count(==("OK"), status) / max(nrow(group), 1),
				median_wall_time_sec = _safe_median(group.wall_time_sec),
				median_simulation_time_sec = _safe_median(:simulation_time_sec ∈ propertynames(group) ? group.simulation_time_sec : group.wall_time_sec),
				median_offline_training_time_sec = _safe_median(_column_or_missing(group, :offline_training_time_sec)),
				median_offline_preprocess_time_sec = _safe_median(_column_or_missing(group, :offline_preprocess_time_sec)),
				median_allocated_mb = _safe_median(group.allocated_mb),
				median_peak_rss_mb = _safe_median(group.peak_rss_mb),
				median_total_cost = _safe_median(group.total_cost),
				startup_shutdown_cost = _safe_median(_column_or_missing(group, :startup_shutdown_cost)),
				fuel_cost = _safe_median(_column_or_missing(group, :fuel_cost)),
				reserve_cost = _safe_median(_column_or_missing(group, :reserve_cost)),
				load_shed_cost = _safe_median(_column_or_missing(group, :load_shed_cost)),
				wind_curtail_cost = _safe_median(_column_or_missing(group, :wind_curtail_cost)),
				physical_units = physical,
				equivalent_units = equivalent,
				state_reduction_pct = reduction,
				median_integer_variables = _safe_median(group.commitment_integer_variables),
				cluster_attempts = _safe_sum(group.cluster_attempts),
				cluster_successes = _safe_sum(group.cluster_successes),
				cluster_fallbacks = _safe_sum(group.cluster_fallbacks),
				mean_overlap_hours = _safe_mean(_column_or_missing(group, :average_overlap_hours)),
				max_overlap_hours = maximum(skipmissing(_column_or_missing(group, :max_overlap_hours)); init = 0.0),
				ramp_event_intervals = _safe_sum(_column_or_missing(group, :ramp_event_intervals)),
				reference_repairs = _safe_sum(_column_or_missing(group, :reference_repairs)),
				mean_pre_repair_cost_gap_pct = _safe_mean(_column_or_missing(group, :pre_repair_cost_gap_pct))))
	end
	DataFrame(rows)
end

function add_relative_metrics(summary::DataFrame)
	result = copy(summary)
	n = nrow(result)
	speedup = Vector{Union{Missing, Float64}}(missing, n)
	wall_delta = Vector{Union{Missing, Float64}}(missing, n)
	cost_delta = Vector{Union{Missing, Float64}}(missing, n)
	allocated_delta = Vector{Union{Missing, Float64}}(missing, n)
	peak_delta = Vector{Union{Missing, Float64}}(missing, n)
	integer_reduction = Vector{Union{Missing, Float64}}(missing, n)

	for i ∈ 1:n
		reference_method = any((result.profile .== result.profile[i]) .& (result.method .== "integrated_uc")) ? "integrated_uc" : "standard"
		baseline_rows = result[(result.profile .== result.profile[i]) .& (result.method .== reference_method), :]
		nrow(baseline_rows) == 1 || continue
		baseline = baseline_rows[1, :]
		speedup[i] = ismissing(baseline.median_simulation_time_sec) || ismissing(result.median_simulation_time_sec[i]) ? missing :
					 baseline.median_simulation_time_sec / result.median_simulation_time_sec[i]
		wall_delta[i] = cost_delta_pct(baseline.median_simulation_time_sec, result.median_simulation_time_sec[i])
		cost_delta[i] = cost_delta_pct(baseline.median_total_cost, result.median_total_cost[i])
		allocated_delta[i] = cost_delta_pct(baseline.median_allocated_mb, result.median_allocated_mb[i])
		peak_delta[i] = cost_delta_pct(baseline.median_peak_rss_mb, result.median_peak_rss_mb[i])
		integer_reduction[i] = ismissing(baseline.median_integer_variables) || ismissing(result.median_integer_variables[i]) ||
							   baseline.median_integer_variables == 0 ? missing :
							   100.0 * (1.0 - result.median_integer_variables[i] / baseline.median_integer_variables)
	end
	result.speedup_vs_standard = speedup
	result.wall_time_delta_pct = wall_delta
	result.cost_delta_pct = cost_delta
	result.allocated_delta_pct = allocated_delta
	result.peak_rss_delta_pct = peak_delta
	result.integer_reduction_pct = integer_reduction
	result
end

function _metric_value(metrics, name, default = missing)
	name ∈ propertynames(metrics) || return default
	value = metrics[1, name]
	ismissing(value) ? default : value
end

function _overlap_metrics(run_dir, method)
	method ∉ ("adaptive_overlap", "clustered_adaptive_overlap") && return (
		windows = "", average = 0.0, maximum = 0.0, ramp_events = 0.0, reference_repairs = 0.0, pre_repair_gap = 0.0)
	folder = method == "clustered_adaptive_overlap" ? "clustered_adaptive_pcm_simulation_results" : "adaptive_pcm_simulation_results"
	path = joinpath(run_dir, "output", "details_schedule_results", folder, "overlap_window_statistics.csv")
	isfile(path) || return (windows = "", average = missing, maximum = missing, ramp_events = missing,
		reference_repairs = missing, pre_repair_gap = missing)
	stats = CSV.read(path, DataFrame)
	windows = isempty(stats) ? "" : join(stats.Final_Adaptive_Overlap_h, ";")
	average = isempty(stats) ? missing : mean(Float64.(stats.Final_Adaptive_Overlap_h))
	max_overlap = isempty(stats) ? missing : Float64(Base.maximum(stats.Final_Adaptive_Overlap_h))
	ramp_events = isempty(stats) ? 0.0 : Float64(count(identity, Bool.(stats.Ramp_Event_Detected)))
	repairs = :Reference_Repair_Applied ∈ propertynames(stats) ? count(identity, Bool.(stats.Reference_Repair_Applied)) : 0
	gaps = :Reference_Cost_Gap_pct ∈ propertynames(stats) ? Float64.(stats.Reference_Cost_Gap_pct) : Float64[]
	(windows = windows, average = average, maximum = max_overlap, ramp_events = ramp_events,
		reference_repairs = Float64(repairs), pre_repair_gap = isempty(gaps) ? 0.0 : mean(abs.(gaps)))
end

function extract_cluster_intermediate(run_dir::AbstractString, profile::AbstractString, run_number::Integer)
	log_path = joinpath(run_dir, "run.log")
	isfile(log_path) || return DataFrame()
	rows = NamedTuple[]
	interval = 0
	current = 0
	for line ∈ split(read(log_path, String), '\n')
		interval_match = match(r"Processing scheduling interval (\d+) of", line)
		interval_match !== nothing && (interval = parse(Int, interval_match.captures[1]))
		cluster_match = match(r"Clustered PCM: (\d+) physical units -> (\d+) equivalent units \(([0-9.]+)% state reduction; (\d+) units", line)
		if cluster_match !== nothing
			current = length(rows) + 1
			push!(rows,
				(
					profile = String(profile), method = "clustered_pcm", run = Int(run_number), interval = interval,
					attempt = count(row -> row.interval == interval, rows) + 1,
					physical_units = parse(Int, cluster_match.captures[1]),
					equivalent_units = parse(Int, cluster_match.captures[2]),
					state_reduction_pct = parse(Float64, cluster_match.captures[3]),
					non_singleton_units = parse(Int, cluster_match.captures[4]),
					status = "attempted", failure_stage = "", diagnostic = ""))
		elseif current > 0 && occursin("True clustered UC completed", line)
			rows[current] = merge(rows[current], (status = "completed", diagnostic = strip(line)))
		elseif current > 0 && occursin("True clustered UC failed", line)
			failure_match = match(r"failed at ([^:]+): (.*?)(?:; falling back|$)", line)
			stage = failure_match === nothing ? "unknown" : strip(failure_match.captures[1])
			diagnostic = failure_match === nothing ? strip(line) : strip(failure_match.captures[2])
			rows[current] = merge(rows[current], (status = "failed", failure_stage = stage, diagnostic = diagnostic))
		end
	end
	DataFrame(rows)
end

function extract_adaptive_intermediate(run_dir::AbstractString, profile::AbstractString, run_number::Integer, method::AbstractString = "adaptive_overlap")
	folder = method == "clustered_adaptive_overlap" ? "clustered_adaptive_pcm_simulation_results" : "adaptive_pcm_simulation_results"
	path = joinpath(run_dir, "output", "details_schedule_results", folder, "overlap_window_statistics.csv")
	isfile(path) || return DataFrame()
	stats = CSV.read(path, DataFrame)
	isempty(stats) && return DataFrame()
	insertcols!(stats, 1, :profile => fill(String(profile), nrow(stats)),
		:method => fill(String(method), nrow(stats)), :run => fill(Int(run_number), nrow(stats)))
	stats
end

function _cost_path(run_dir, method)
	folder = method == "clustered_adaptive_overlap" ? "clustered_adaptive_pcm_simulation_results" :
			 method == "adaptive_overlap" ? "adaptive_pcm_simulation_results" : "pcm_simulation_results"
	filename = method in ("adaptive_overlap", "clustered_adaptive_overlap") ? "total_scheduled_results.csv" :
			   joinpath("summary_scheduling_report", "total_scheduled_results.csv")
	joinpath(run_dir, "output", "details_schedule_results", folder, filename)
end

function _run_row(metrics, profile, method, run_number, run_dir)
	physical = _safe_float(_metric_value(metrics, :physical_units))
	virtual = _safe_float(_metric_value(metrics, :virtual_units))
	equivalent = method_equivalent_units(method, physical, virtual)
	cost_vector = read_cost_vector(_cost_path(run_dir, method))
	metric_cost = _safe_float(_metric_value(metrics, :total_cost))
	total_cost = cost_vector === nothing ? metric_cost : sum(cost_vector)
	components = cost_vector === nothing ? fill(missing, 7) : cost_vector
	overlap = _overlap_metrics(run_dir, method)
	(
		profile = profile,
		method = method,
		run = run_number,
		solver = String(_metric_value(metrics, :solver, "unknown")),
		status = String(_metric_value(metrics, :status, "FAILED")),
		wall_time_sec = _safe_float(_metric_value(metrics, :wall_time_sec)),
		simulation_time_sec = _safe_float(_metric_value(metrics, :simulation_time_sec)),
		offline_training_time_sec = _safe_float(_metric_value(metrics, :offline_training_time_sec, 0.0)),
		offline_preprocess_time_sec = _safe_float(_metric_value(metrics, :offline_preprocess_time_sec, 0.0)),
		allocated_mb = _safe_float(_metric_value(metrics, :allocated_mb)),
		peak_rss_mb = _safe_float(_metric_value(metrics, :peak_rss_mb)),
		total_cost = total_cost,
		startup_shutdown_cost = components[1] + components[2],
		fuel_cost = components[3],
		reserve_cost = components[4] + components[5],
		load_shed_cost = components[6],
		wind_curtail_cost = components[7],
		physical_units = physical,
		equivalent_units = equivalent,
		state_reduction_pct = ismissing(physical) || ismissing(equivalent) || physical == 0 ? missing :
							  100.0 * (1.0 - equivalent / physical),
		commitment_integer_variables = _safe_float(_metric_value(metrics, :commitment_integer_variables)),
		cluster_attempts = _safe_float(_metric_value(metrics, :cluster_attempts, 0.0)),
		cluster_successes = _safe_float(_metric_value(metrics, :cluster_successes, 0.0)),
		cluster_fallbacks = _safe_float(_metric_value(metrics, :cluster_fallbacks, 0.0)),
		overlap_windows_h = overlap.windows,
		average_overlap_hours = overlap.average,
		max_overlap_hours = overlap.maximum,
		ramp_event_intervals = overlap.ramp_events,
		reference_repairs = overlap.reference_repairs,
		pre_repair_cost_gap_pct = overlap.pre_repair_gap)
end

function run_one(; project_root = PROJECT_ROOT, julia_project = joinpath(project_root, "pkg"), output_root, input_file,
		profile, method, run_number, intervals, window_hours, network_constraints, random_seed, overlap_mode, solver)
	run_dir = benchmark_run_dir(output_root, profile, method, run_number)
	mkpath(run_dir)
	metrics_path = joinpath(run_dir, "metrics.csv")
	log_path = joinpath(run_dir, "run.log")
	resume_existing = lowercase(strip(get(ENV, "PCM_BENCHMARK_RESUME", "false"))) in ("1", "true", "yes", "on")
	if resume_existing && isfile(metrics_path)
		metrics = CSV.read(metrics_path, DataFrame)
		status = nrow(metrics) > 0 && :status in propertynames(metrics) ? uppercase(strip(string(metrics.status[1]))) : ""
		if status == "OK"
			println("[$(now())] profile=$(profile) method=$(method) run=$(run_number) RESUME successful metrics")
			return _run_row(metrics, profile, method, run_number, run_dir)
		end
		# A failed/partial result is a checkpoint, not a completed experiment.
		# Re-run it after a code or solver-policy fix while preserving successful
		# methods in the same batch directory.
		println("[$(now())] profile=$(profile) method=$(method) run=$(run_number) RESUME retry status=$(isempty(status) ? "UNKNOWN" : status)")
	end
	command = `$(Base.julia_cmd()) --project=$(julia_project) $(joinpath(project_root, "tools", "pcm", "benchmark", "method_worker.jl"))`
	integrated_reference = lowercase(method) == "integrated_uc"
	effective_intervals = integrated_reference ? 1 : intervals
	effective_window_hours = integrated_reference ? intervals * window_hours : window_hours
	environment = Dict(
		"PCM_METHOD" => method,
		"PCM_INPUT_XLSX" => input_file,
		"MODULE_UC_DATA_FILE" => input_file,
		"PCM_LOAD_PROFILE" => profile,
		"PCM_INTERVALS" => string(effective_intervals),
		"PCM_WINDOW_HOURS" => string(effective_window_hours),
		"PCM_NETWORK_CONSTRAINTS" => network_constraints,
		"PCM_RANDOM_SEED" => random_seed,
		"PCM_OVERLAP_MODE" => overlap_mode,
		"PCM_SOLVER" => solver,
		"PCM_SOLVER_THREADS" => get(ENV, "PCM_SOLVER_THREADS", "16"),
		"PCM_TRAINING_MODE" => get(ENV, "PCM_TRAINING_MODE", "sweep"),
		"MODULE_UC_OUTPUT_DIR" => joinpath(run_dir, "output"),
		"PCM_BENCHMARK_METRICS" => metrics_path)

	println("[$(now())] profile=$(profile) method=$(method) run=$(run_number)")
	cd(run_dir) do
		open(log_path, "w") do io
			process = run(pipeline(addenv(command, environment); stdout = io, stderr = io); wait = false)
			wait(process)
		end
	end
	metrics = isfile(metrics_path) ? CSV.read(metrics_path, DataFrame) : DataFrame(; status = ["FAILED"])
	_run_row(metrics, profile, method, run_number, run_dir)
end

function _markdown_table(io, data::DataFrame, columns)
	println(io, "| ", join(string.(columns), " | "), " |")
	println(io, "| ", join(fill("---", length(columns)), " | "), " |")
	for row ∈ eachrow(data)
		values = [ismissing(row[column]) ? "NA" : string(row[column]) for column ∈ columns]
		println(io, "| ", join(values, " | "), " |")
	end
end

function write_report(path, raw, summary, comparison; input_file, profiles, methods, intervals, window_hours,
		cluster_intermediate = DataFrame(), adaptive_intermediate = DataFrame())
	open(path, "w") do io
		println(io, "# PCM 三方案统一计算结果与性能对比\n")
		println(io, "- 输入：`$(input_file)`")
		println(io, "- 场景：$(join(profiles, ", "))")
		println(io, "- 方法：$(join(methods, ", "))")
		println(io, "- 滚动范围：$(intervals) × $(window_hours) h")
		println(io, "- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。\n")
		println(io, "## 汇总指标\n")
		_markdown_table(io, comparison,
			[:profile, :method, :solver, :successful_runs, :success_rate_pct, :median_simulation_time_sec,
				:median_offline_training_time_sec, :median_offline_preprocess_time_sec, :median_wall_time_sec,
				:median_peak_rss_mb, :median_total_cost, :speedup_vs_standard, :cost_delta_pct, :cluster_fallbacks,
				:mean_overlap_hours, :ramp_event_intervals, :reference_repairs, :mean_pre_repair_cost_gap_pct])
		println(io, "\n## 规模与降维\n")
		_markdown_table(io,
			comparison,
			[:profile, :method, :physical_units, :equivalent_units, :state_reduction_pct,
				:median_integer_variables, :integer_reduction_pct, :median_allocated_mb, :allocated_delta_pct])
		if nrow(cluster_intermediate) > 0
			println(io, "\n## clustered_pcm 关键中间过程\n")
			println(io, "该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。\n")
			_markdown_table(io,
				cluster_intermediate,
				[:profile, :run, :interval, :attempt, :physical_units,
					:equivalent_units, :state_reduction_pct, :status, :failure_stage, :diagnostic])
		end
		if nrow(adaptive_intermediate) > 0
			println(io, "\n## adaptive_overlap 关键中间过程\n")
			println(io, "该表保留每个滚动区间的交叠窗决策来源、最终交叠长度和实际求解时域。\n")
			_markdown_table(io, adaptive_intermediate,
				[:profile, :run, :Interval_ID, :Steady_State_Overlap_h,
					:Unit_Dwell_Overlap_h, :Ramp_Event_Detected, :Ramp_Overlap_h, :Limiting_Factor,
					:Final_Adaptive_Overlap_h, :Total_Solved_Horizon_h, :Subproblem_SolveTime_sec, :Optimization_Status])
		end
		println(io, "\n## 解释口径\n")
		println(io, "- 存在 `integrated_uc` 时，成本误差以完整时域单机 UC 为基准；否则仅兼容性回退到 standard。")
		println(io, "- `median_simulation_time_sec` 是在线 PCM 仿真时间；ML 训练和聚类预处理分别单列，不计入该指标。")
		println(io, "- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。")
		println(io, "- `reference_repairs` 表示组合方法因提交期物理成本偏差超限而采用单机参考解的窗口数；修复前偏差单独保留。")
		println(io, "\n原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。\n")
	end
end

"""
Rebuild summaries and intermediate-process artifacts from a completed run directory.
"""
function rebuild_outputs(output_root::AbstractString; input_file = "unknown", profiles = nothing, methods = nothing,
		intervals = 3, window_hours = 24)
	metrics_path = joinpath(output_root, "metrics.csv")
	isfile(metrics_path) || error("Benchmark metrics not found: $metrics_path")
	raw = CSV.read(metrics_path, DataFrame)
	selected_profiles = profiles === nothing ? String.(unique(raw.profile)) : String.(profiles)
	selected_methods = methods === nothing ? String.(unique(raw.method)) : String.(methods)
	cluster_frames = DataFrame[]
	adaptive_frames = DataFrame[]
	for row ∈ eachrow(raw)
		run_dir = benchmark_run_dir(output_root, String(row.profile), String(row.method), Int(row.run); existing = true)
		row.method in ("clustered_pcm", "clustered_adaptive_overlap") &&
			push!(cluster_frames, extract_cluster_intermediate(run_dir, row.profile, row.run))
		row.method in ("adaptive_overlap", "clustered_adaptive_overlap") &&
			push!(adaptive_frames, extract_adaptive_intermediate(run_dir, row.profile, row.run, String(row.method)))
	end
	summary = aggregate_metrics(raw)
	comparison = add_relative_metrics(summary)
	cluster_intermediate = isempty(cluster_frames) ? DataFrame() : vcat(cluster_frames...; cols = :union)
	adaptive_intermediate = isempty(adaptive_frames) ? DataFrame() : vcat(adaptive_frames...; cols = :union)
	CSV.write(joinpath(output_root, "summary.csv"), summary)
	CSV.write(joinpath(output_root, "comparison.csv"), comparison)
	nrow(cluster_intermediate) > 0 && CSV.write(joinpath(output_root, "cluster_intermediate.csv"), cluster_intermediate)
	nrow(adaptive_intermediate) > 0 && CSV.write(joinpath(output_root, "adaptive_intermediate.csv"), adaptive_intermediate)
	write_report(joinpath(output_root, "comparison.md"), raw, summary, comparison;
		input_file, profiles = selected_profiles, methods = selected_methods, intervals, window_hours,
		cluster_intermediate, adaptive_intermediate)
	output_root
end

function main(; project_root = PROJECT_ROOT,
		julia_project = get(ENV, "PCM_JULIA_PROJECT", joinpath(project_root, "pkg")),
		input_file = abspath(get(ENV, "PCM_INPUT_XLSX", joinpath(project_root, "data", "data_118_clustered_pcm.xlsx"))),
		output_root = abspath(get(ENV, "PCM_THREE_METHOD_OUTPUT",
			joinpath(project_root, "output", "pcm_runs", "pcm4_$(Dates.format(now(), "yyyymmdd_HHMMSS"))"))),
		profiles = parse_list(get(ENV, "PCM_BENCHMARK_PROFILES", join(DEFAULT_PROFILES, ","))),
		methods = parse_list(get(ENV, "PCM_BENCHMARK_METHODS", join(DEFAULT_METHODS, ","))),
		runs = parse(Int, get(ENV, "PCM_BENCHMARK_RUNS", "1")),
		intervals = parse(Int, get(ENV, "PCM_INTERVALS", "3")),
		window_hours = parse(Int, get(ENV, "PCM_WINDOW_HOURS", "24")),
		network_constraints = get(ENV, "PCM_NETWORK_CONSTRAINTS", "0"),
		random_seed = get(ENV, "PCM_RANDOM_SEED", "20260809"),
		overlap_mode = get(ENV, "PCM_OVERLAP_MODE", "ml_prediction"),
		solver = normalize_solver(get(ENV, "PCM_SOLVER", "gurobi")))
	isfile(input_file) || error("PCM input file not found: $input_file")
	isempty(profiles) && error("PCM_BENCHMARK_PROFILES is empty")
	isempty(methods) && error("PCM_BENCHMARK_METHODS is empty")
	runs >= 1 || error("PCM_BENCHMARK_RUNS must be positive")
	if isempty(get(ENV, "PCM_THREE_METHOD_OUTPUT", ""))
		output_root = benchmark_output_root(project_root, methods, profiles; horizon_hours = intervals * window_hours)
	end
	mkpath(output_root)

	jobs = [(profile = profile, method = lowercase(method), run_number = run_number)
		for profile in profiles for method in methods for run_number in 1:runs]
	max_parallel = max(1, parse(Int, get(ENV, "PCM_BENCHMARK_MAX_PARALLEL", "1")))
	println("PCM benchmark process parallelism: $(min(max_parallel, length(jobs)))")
	job_rows = Vector{NamedTuple}(undef, length(jobs))
	semaphore = Base.Semaphore(max_parallel)
	@sync for (job_index, job) in enumerate(jobs)
		@async begin
			Base.acquire(semaphore)
			try
				job.method ∈ (DEFAULT_METHODS..., "integrated_uc") || error("Unsupported PCM method: $(job.method)")
				job_rows[job_index] = run_one(; project_root, julia_project, output_root,
					input_file = abspath(input_file), profile = job.profile, method = job.method,
					run_number = job.run_number, intervals, window_hours, network_constraints,
					random_seed, overlap_mode, solver)
			finally
				Base.release(semaphore)
			end
		end
	end
	rows = NamedTuple[]
	cluster_process_frames = DataFrame[]
	adaptive_process_frames = DataFrame[]
	for (job, run_row) in zip(jobs, job_rows)
		push!(rows, run_row)
		run_dir = benchmark_run_dir(output_root, String(job.profile), job.method, job.run_number; existing = true)
		job.method in ("clustered_pcm", "clustered_adaptive_overlap") &&
			push!(cluster_process_frames, extract_cluster_intermediate(run_dir, job.profile, job.run_number))
		job.method in ("adaptive_overlap", "clustered_adaptive_overlap") &&
			push!(adaptive_process_frames, extract_adaptive_intermediate(run_dir, job.profile, job.run_number, job.method))
	end
	raw = DataFrame(rows)
	summary = aggregate_metrics(raw)
	comparison = add_relative_metrics(summary)
	cluster_intermediate = isempty(cluster_process_frames) ? DataFrame() : vcat(cluster_process_frames...; cols = :union)
	adaptive_intermediate = isempty(adaptive_process_frames) ? DataFrame() : vcat(adaptive_process_frames...; cols = :union)
	CSV.write(joinpath(output_root, "metrics.csv"), raw)
	CSV.write(joinpath(output_root, "summary.csv"), summary)
	CSV.write(joinpath(output_root, "comparison.csv"), comparison)
	nrow(cluster_intermediate) > 0 && CSV.write(joinpath(output_root, "cluster_intermediate.csv"), cluster_intermediate)
	nrow(adaptive_intermediate) > 0 && CSV.write(joinpath(output_root, "adaptive_intermediate.csv"), adaptive_intermediate)
	write_report(joinpath(output_root, "comparison.md"), raw, summary, comparison;
		input_file, profiles, methods, intervals, window_hours, cluster_intermediate, adaptive_intermediate)
	println("PCM three-method benchmark complete: $output_root")
	println(comparison)
	output_root
end

end

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
	PCMThreeMethodBenchmark.main()
end
