if !isdefined(@__MODULE__, :_TRUE_CLUSTERED_PCM_SOLVER_INCLUDED)
	const _TRUE_CLUSTERED_PCM_SOLVER_INCLUDED=true
	include("adapter.jl")
	using JuMP
	using Statistics
	import MathOptInterface as MOI

	_clustered_pcm_up_ramp_limit(previous_online, startups, ramp_up, startup_ramp) = ramp_up * previous_online + startup_ramp * startups
	_clustered_pcm_down_ramp_limit(current_online, shutdowns, ramp_down, shutdown_ramp) = ramp_down * current_online + shutdown_ramp * shutdowns

	"""
	在聚类主问题中建立驻留年龄与出力联合的扩展网络流。

	每个物理机组在 ON(1)...ON(L+) / OFF(1)...OFF(D+) 状态间流动；
	在线弧同时携带弧起点出力和弧终点出力，因此普通爬坡、启动爬坡和
	停机爬坡都在单条状态弧上约束。对同质机组，整数状态流可分解成物理
	路径，连续出力流也可沿相同路径分解，避免簇总爬坡约束的假可行。
	"""
	function add_cluster_residence_power_flow_hull!(m, clusters, units, NT, U, Y, Z, P;
			tolerance=1e-7)
		state_refs=Dict{Int, NamedTuple}()
		for c ∈ clusters
			g=c.id
			L=max(1, c.min_up)
			D=max(1, c.min_down)
			on=@variable(m, [1:L, 1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_on_age")
			off=@variable(m, [1:D, 1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_off_age")
			onflow=@variable(m, [1:L, 1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_on_flow")
			offflow=@variable(m, [1:D, 1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_off_flow")
			startup=@variable(m, [1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_startup_flow")
			shutdown=@variable(m, [1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_shutdown_flow")
			pon=@variable(m, [1:L, 1:NT], lower_bound=0, base_name="cluster_$(g)_on_power")
			pfrom=@variable(m, [1:L, 1:NT], lower_bound=0, base_name="cluster_$(g)_arc_power_from")
			pto=@variable(m, [1:L, 1:NT], lower_bound=0, base_name="cluster_$(g)_arc_power_to")
			pstartup=@variable(m, [1:NT], lower_bound=0, base_name="cluster_$(g)_startup_power")
			pshutdown=@variable(m, [1:NT], lower_bound=0, base_name="cluster_$(g)_shutdown_power")

			ids=c.unit_indices
			pmin=minimum(units.p_min[ids]); pmax=minimum(units.p_max[ids])
			ru=minimum(units.ramp_up[ids]); rd=minimum(units.ramp_down[ids])
			sr=minimum(units.shut_up[ids]); dr=minimum(units.shut_down[ids])
			initial_on=zeros(Int, L); initial_off=zeros(Int, D); initial_power=zeros(Float64, L)
			for i ∈ ids
				if units.x_0[i]>0.5
					raw=units.t_0[i]>0 ? round(Int, units.t_0[i]) : L
					a=clamp(raw, 1, L)
					initial_on[a]+=1
					initial_power[a]+=units.p_0[i]
				else
					raw=units.t_1[i]>0 ? round(Int, units.t_1[i]) : D
					initial_off[clamp(raw, 1, D)]+=1
				end
			end

			for t ∈ 1:NT
				# Source-state conservation.  The last age is the mature pool and
				# may either remain mature or cross to the opposite state.
				for a ∈ (L>1 ? (1:L-1) : (1:0))
					source=t==1 ? initial_on[a] : on[a, t-1]
					@constraint(m, onflow[a, t]==source)
				end
				source_on_mature=t==1 ? initial_on[L] : on[L, t-1]
				@constraint(m, onflow[L, t]+shutdown[t]==source_on_mature)
				for a ∈ (D>1 ? (1:D-1) : (1:0))
					source=t==1 ? initial_off[a] : off[a, t-1]
					@constraint(m, offflow[a, t]==source)
				end
				source_off_mature=t==1 ? initial_off[D] : off[D, t-1]
				@constraint(m, offflow[D, t]+startup[t]==source_off_mature)

				# Destination-state accumulation; L=1/D=1 naturally means that the
				# only state is already mature.
				@constraint(m, on[1, t]==startup[t]+(L==1 ? onflow[1, t] : 0))
				for a ∈ (L>2 ? (2:L-1) : (1:0))
					@constraint(m, on[a, t]==onflow[a-1, t])
				end
				L>1 && @constraint(m, on[L, t]==onflow[L-1, t]+onflow[L, t])
				@constraint(m, off[1, t]==shutdown[t]+(D==1 ? offflow[1, t] : 0))
				for a ∈ (D>2 ? (2:D-1) : (1:0))
					@constraint(m, off[a, t]==offflow[a-1, t])
				end
				D>1 && @constraint(m, off[D, t]==offflow[D-1, t]+offflow[D, t])

				@constraint(m, U[g, t]==sum(on[:, t]))
				@constraint(m, Y[g, t]==startup[t])
				@constraint(m, Z[g, t]==shutdown[t])
				@constraint(m, P[g, t]==sum(pon[:, t]))

				# Split source-node power over outgoing arcs.  Only the mature ON
				# node has a shutdown arc; all other ON nodes have one forced arc.
				for a ∈ (L>1 ? (1:L-1) : (1:0))
					source_power=t==1 ? initial_power[a] : pon[a, t-1]
					@constraint(m, pfrom[a, t]==source_power)
				end
				source_mature_power=t==1 ? initial_power[L] : pon[L, t-1]
				@constraint(m, pfrom[L, t]+pshutdown[t]==source_mature_power)
				for a ∈ 1:L
					@constraint(m, pmin*onflow[a, t]<=pfrom[a, t])
					@constraint(m, pfrom[a, t]<=pmax*onflow[a, t])
					@constraint(m, pmin*onflow[a, t]<=pto[a, t])
					@constraint(m, pto[a, t]<=pmax*onflow[a, t])
					@constraint(m, pto[a, t]-pfrom[a, t]<=ru*onflow[a, t])
					@constraint(m, pfrom[a, t]-pto[a, t]<=rd*onflow[a, t])
				end
				@constraint(m, pmin*shutdown[t]<=pshutdown[t])
				@constraint(m, pshutdown[t]<=dr*shutdown[t])
				@constraint(m, pmin*startup[t]<=pstartup[t])
				@constraint(m, pstartup[t]<=sr*startup[t])
				@constraint(m, pon[1, t]==pstartup[t]+(L==1 ? pto[1, t] : 0))
				for a ∈ (L>2 ? (2:L-1) : (1:0))
					@constraint(m, pon[a, t]==pto[a-1, t])
				end
				L>1 && @constraint(m, pon[L, t]==pto[L-1, t]+pto[L, t])
			end
			state_refs[g]=(on=on, off=off, onflow=onflow, offflow=offflow,
				startup=startup, shutdown=shutdown, pon=pon, pfrom=pfrom, pto=pto)
		end
		state_refs
	end

	"""Add an integer output-state transition network sharing U/Y/Z/P."""
	function add_cluster_output_state_flow_hull!(m, clusters, units, NT, U, Y, Z, P;
			bins::Int=parse(Int, get(ENV, "PCM_CLUSTER_OUTPUT_BINS", "9")), tolerance=1e-7)
		bins=max(2, bins)
		refs=Dict{Int, NamedTuple}()
		for c ∈ clusters
			g=c.id; ids=c.unit_indices
			pmin=minimum(units.p_min[ids]); pmax=minimum(units.p_max[ids])
			ru=minimum(units.ramp_up[ids]); rd=minimum(units.ramp_down[ids])
			sr=minimum(units.shut_up[ids]); dr=minimum(units.shut_down[ids])
			# 固定网格必须包含滚动窗口传入的真实初始出力。若先把 p₀ 舍入到
			# 最近网格点，第一时段的爬坡弧会基于错误边界被删除，产生假不可行。
			initial_levels=[units.p_0[i] for i ∈ ids if units.x_0[i]>0.5]
			levels=sort!(unique(vcat(collect(range(pmin, pmax; length=bins)), initial_levels)))
			K=length(levels)
			B=@variable(m, [1:K, 1:NT], lower_bound=0, integer=true, base_name="cluster_$(g)_output_state")
			# B 是整数边际计数；A/SU/SD 构成具有整数供需的运输网络。
			# 该网络矩阵全幺模，连续弧存在可行解即存在整数弧分解，无需为
			# K² 条转移弧逐一引入整数变量。
			A=@variable(m, [1:K, 1:K, 1:NT], lower_bound=0, base_name="cluster_$(g)_output_arc")
			SU=@variable(m, [1:K, 1:NT], lower_bound=0, base_name="cluster_$(g)_startup_output_arc")
			SD=@variable(m, [1:K, 1:NT], lower_bound=0, base_name="cluster_$(g)_shutdown_output_arc")
			initial=zeros(Int, K)
			for i ∈ ids
				if units.x_0[i]>0.5
					k=argmin(abs.(levels.-units.p_0[i]))
					initial[k]+=1
				end
			end
			for t ∈ 1:NT
				for k ∈ 1:K
					previous=t==1 ? initial[k] : B[k, t-1]
					@constraint(m, sum(A[k, l, t] for l ∈ 1:K)+SD[k, t]==previous)
					@constraint(m, sum(A[l, k, t] for l ∈ 1:K)+SU[k, t]==B[k, t])
					levels[k]>dr+tolerance && @constraint(m, SD[k, t]==0)
					levels[k]>sr+tolerance && @constraint(m, SU[k, t]==0)
				end
				for k ∈ 1:K, l ∈ 1:K
					(levels[l]-levels[k]>ru+tolerance || levels[k]-levels[l]>rd+tolerance) &&
						@constraint(m, A[k, l, t]==0)
				end
				@constraint(m, sum(B[:, t])==U[g, t])
				@constraint(m, sum(SU[:, t])==Y[g, t])
				@constraint(m, sum(SD[:, t])==Z[g, t])
				@constraint(m, P[g, t]==sum(levels[k]*B[k, t] for k ∈ 1:K))
			end
			refs[g]=(states=B, transitions=A, startup=SU, shutdown=SD, levels=levels)
		end
		refs
	end

	"""
	建立“驻留年龄 × 出力档位”乘积状态流。

	与两个独立边际网络不同，`ON[a,k,t]` 中的同一份机组计数同时携带
	开机年龄 `a` 和出力状态 `k`。普通转移弧只有在年龄演化正确且出力满足
	爬坡约束时才存在；启动仅从成熟 OFF 池进入 ON(1)，停机仅从成熟 ON
	状态进入 OFF(1)。因此任意整数流都能直接分解为满足驻留和爬坡的单机路径。
	"""
	function add_cluster_residence_output_product_hull!(m, clusters, units, NT, U, Y, Z, P;
			bins::Int=parse(Int, get(ENV, "PCM_CLUSTER_OUTPUT_BINS", "9")), tolerance=1e-7)
		refs=Dict{Int, NamedTuple}()
		for c ∈ clusters
			g=c.id; ids=c.unit_indices; L=max(1,c.min_up); D=max(1,c.min_down)
			pmin=minimum(units.p_min[ids]); pmax=minimum(units.p_max[ids])
			ru=minimum(units.ramp_up[ids]); rd=minimum(units.ramp_down[ids])
			sr=minimum(units.shut_up[ids]); dr=minimum(units.shut_down[ids])
			initial_levels=[units.p_0[i] for i ∈ ids if units.x_0[i]>0.5]
			levels=sort!(unique(vcat(collect(range(pmin,pmax; length=max(2,bins))), initial_levels)))
			K=length(levels)
			ON=@variable(m,[1:L,1:K,1:NT],lower_bound=0,integer=true,base_name="cluster_$(g)_age_output")
			OFF=@variable(m,[1:D,1:NT],lower_bound=0,integer=true,base_name="cluster_$(g)_off_age_product")
			F=@variable(m,[1:L,1:K,1:K,1:NT],lower_bound=0,base_name="cluster_$(g)_age_output_arc")
			OF=@variable(m,[1:D,1:NT],lower_bound=0,base_name="cluster_$(g)_off_arc_product")
			SU=@variable(m,[1:K,1:NT],lower_bound=0,base_name="cluster_$(g)_startup_product")
			SD=@variable(m,[1:K,1:NT],lower_bound=0,base_name="cluster_$(g)_shutdown_product")
			initial_on=zeros(Int,L,K); initial_off=zeros(Int,D)
			for i ∈ ids
				if units.x_0[i]>0.5
					a=clamp(units.t_0[i]>0 ? round(Int,units.t_0[i]) : L,1,L)
					k=argmin(abs.(levels.-units.p_0[i])); initial_on[a,k]+=1
				else
					d=clamp(units.t_1[i]>0 ? round(Int,units.t_1[i]) : D,1,D); initial_off[d]+=1
				end
			end
			for t ∈ 1:NT
				# 每个在线乘积节点的流出；只有成熟年龄允许停机。
				for a ∈ 1:L, k ∈ 1:K
					source=t==1 ? initial_on[a,k] : ON[a,k,t-1]
					@constraint(m,sum(F[a,k,l,t] for l ∈ 1:K)+(a==L ? SD[k,t] : 0)==source)
					(a<L || levels[k]<=dr+tolerance) || @constraint(m,SD[k,t]==0)
					for l ∈ 1:K
						(levels[l]-levels[k]>ru+tolerance || levels[k]-levels[l]>rd+tolerance) &&
							@constraint(m,F[a,k,l,t]==0)
					end
				end
				# 目的年龄唯一：非成熟状态加一，成熟状态留在成熟池。
				for a ∈ 1:L, l ∈ 1:K
					incoming=a==1 ? SU[l,t] : sum(F[a-1,k,l,t] for k ∈ 1:K)
					a==L && (incoming += sum(F[L,k,l,t] for k ∈ 1:K))
					@constraint(m,ON[a,l,t]==incoming)
				end
				for k ∈ 1:K
					levels[k]>sr+tolerance && @constraint(m,SU[k,t]==0)
				end
				# 离线年龄流；成熟池可继续停留或启动。
				for d ∈ 1:D
					source=t==1 ? initial_off[d] : OFF[d,t-1]
					@constraint(m,OF[d,t]+(d==D ? sum(SU[:,t]) : 0)==source)
				end
				@constraint(m,OFF[1,t]==sum(SD[:,t])+(D==1 ? OF[1,t] : 0))
				for d ∈ 2:D-1; @constraint(m,OFF[d,t]==OF[d-1,t]); end
				D>1 && @constraint(m,OFF[D,t]==OF[D-1,t]+OF[D,t])
				@constraint(m,U[g,t]==sum(ON[:,:,t]))
				@constraint(m,Y[g,t]==sum(SU[:,t]))
				@constraint(m,Z[g,t]==sum(SD[:,t]))
				@constraint(m,P[g,t]==sum(levels[k]*ON[a,k,t] for a ∈ 1:L,k ∈ 1:K))
			end
			refs[g]=(on=ON,off=OFF,transitions=F,startup=SU,shutdown=SD,levels=levels)
		end
		refs
	end

	"""
	建立运行特性可互换的火电机组等价类。

	默认容差有意设置得很严格。仅归一化比例相似并不能保持 UC 可行域；
	绝对容量、启停爬坡或成本不同都不应直接聚合。滚动窗口的 x_0/p_0/t_0/t_1
	是簇内状态而不是簇身份；主问题显式加入初始剩余驻留约束，解群继续提供物理证书。
	无网络约束时允许跨母线聚类；网络约束启用时必须保持同母线注入。
	"""
	function build_similar_pcm_clusters(units; ratio_tol = 1e-6, ramp_tol = 1e-6, cost_tol = 1e-6, require_same_bus::Bool = false)
		groups=Vector{Vector{Int}}()
		startup_cost(i) = hasproperty(units, :coffi_cold_shutup_1) ? units.coffi_cold_shutup_1[i] : 0.0
		shutdown_cost(i) = hasproperty(units, :coffi_cold_shutdown_1) ? units.coffi_cold_shutdown_1[i] : 0.0
		feature(i) = (units.p_min[i]/max(units.p_max[i], eps()), units.ramp_up[i]/max(units.p_max[i], eps()),
			units.ramp_down[i]/max(units.p_max[i], eps()), units.coffi_a[i], units.coffi_b[i], units.coffi_c[i],
			startup_cost(i), shutdown_cost(i))
		function boundary_class(i)
			on=units.x_0[i]>0.5
			minimum=round(Int, on ? units.min_shutup_time[i] : units.min_shutdown_time[i])
			raw=on ? (hasproperty(units, :t_0) ? units.t_0[i] : 0.0) :
				(hasproperty(units, :t_1) ? units.t_1[i] : 0.0)
			# Unknown workbook history (0) is mature, as in the single-unit UC.
			elapsed=raw > 0 ? round(Int, raw) : minimum
			(on, min(elapsed, minimum))
		end
		for i ∈ eachindex(units.index)
			placed=false
			fi=feature(i)
			for g ∈ groups
				j=first(g)
				fj=feature(j)
				scale(x, y) = max(1.0, abs(x), abs(y))
				close(x, y, tol) = abs(x-y)<=tol*scale(x, y)
				compatible=boundary_class(i)==boundary_class(j) &&
						   (!require_same_bus || units.locatebus[i]==units.locatebus[j]) &&
						   round(Int, units.min_shutup_time[i])==round(Int, units.min_shutup_time[j]) &&
						   round(Int, units.min_shutdown_time[i])==round(Int, units.min_shutdown_time[j]) &&
						   abs(fi[1]-fj[1])<=ratio_tol &&
						   max(abs(fi[2]-fj[2]), abs(fi[3]-fj[3]))<=ramp_tol &&
						   all(abs(fi[k]-fj[k])<=cost_tol*max(1.0, abs(fj[k])) for k ∈ 4:length(fi)) &&
						   close(units.p_min[i], units.p_min[j], ratio_tol) &&
						   close(units.p_max[i], units.p_max[j], ratio_tol) &&
						   close(units.ramp_up[i], units.ramp_up[j], ramp_tol) &&
						   close(units.ramp_down[i], units.ramp_down[j], ramp_tol) &&
						   close(units.shut_up[i], units.shut_up[j], ramp_tol) &&
						   close(units.shut_down[i], units.shut_down[j], ramp_tol) &&
						   close(units.coffi_a[i], units.coffi_a[j], cost_tol) &&
						   close(units.coffi_c[i], units.coffi_c[j], cost_tol)
				compatible&&(push!(g, i); placed = true; break)
			end
			placed||push!(groups, [i])
		end
		[ClusterSpec(; id = k, unit_indices = g, min_up = max(1, maximum(round.(Int, units.min_shutup_time[g]))),
			 min_down = max(1, maximum(round.(Int, units.min_shutdown_time[g])))) for (k, g) ∈ enumerate(groups)]
	end

	function solve_true_clustered_pcm_window(NT, NB, NG, ND, units, loads, winds, lines, config_param, NL, hydros, NH; optimizer = Gurobi.Optimizer,
			tolerance = 1e-5, feedback_lines = Int[], iteration = 1, max_iterations = 6,
			max_cluster_size::Int = typemax(Int), refinement_used::Bool = false,
			physical_cuts::Vector{NamedTuple} = NamedTuple[], physical_iteration::Int = 1,
			max_physical_iterations::Int = parse(Int, get(ENV, "PCM_CLUSTER_MAX_PHYSICAL_ITERATIONS", "3")),
			expanded_units::Set{Int} = Set{Int}(), targeted_refinements::Int = 0,
			max_targeted_refinements::Int = parse(Int, get(ENV, "PCM_CLUSTER_MAX_TARGETED_REFINEMENTS", "12")),
			use_output_state::Bool = true,
			output_bins::Int = parse(Int, get(ENV, "PCM_CLUSTER_OUTPUT_BINS", "9")))
		# The clustered master is copper-plate by default. Bus identity is only
		# part of homogeneity when network constraints are actually represented.
		cluster_preprocess_start = time()
		clusters=build_similar_pcm_clusters(units; require_same_bus = config_param.is_NetWorkCon == 1)
		if !isempty(expanded_units)
			groups=Vector{Vector{Int}}()
			for c ∈ clusters
				kept=[i for i ∈ c.unit_indices if !(i in expanded_units)]
				isempty(kept) || push!(groups, kept)
				append!(groups, [[i] for i ∈ c.unit_indices if i in expanded_units])
			end
			clusters=[ClusterSpec(id=k, unit_indices=g,
				min_up=max(1, maximum(round.(Int, units.min_shutup_time[g]))),
				min_down=max(1, maximum(round.(Int, units.min_shutdown_time[g])))) for (k, g) ∈ enumerate(groups)]
		end
		if max_cluster_size < typemax(Int)
			groups=[collect(chunk) for c ∈ clusters for chunk ∈ Iterators.partition(c.unit_indices, max_cluster_size)]
			clusters=[ClusterSpec(id=k, unit_indices=g,
				min_up=max(1, maximum(round.(Int, units.min_shutup_time[g]))),
				min_down=max(1, maximum(round.(Int, units.min_shutdown_time[g])))) for (k, g) ∈ enumerate(groups)]
		end
		if isdefined(@__MODULE__, :PCM_CLUSTER_PREPROCESS_TIME_SEC)
			PCM_CLUSTER_PREPROCESS_TIME_SEC[] += time() - cluster_preprocess_start
		end
		C=length(clusters)
		clustered_units=sum(length(c.unit_indices) for c ∈ clusters if length(c.unit_indices)>1)
		println("  Clustered PCM: $NG physical units -> $C equivalent units " *
				"($(round(100 * (NG - C) / max(NG, 1); digits = 1))% state reduction; $clustered_units units in non-singleton clusters)")
		NW=length(winds.index)
		NS=winds.scenarios_nums
		NS==1||return (feasible = false, stage = :unsupported_scenarios, message = "true clustered master currently requires one PCM scenario")
		n=[length(c.unit_indices) for c ∈ clusters]
		coeffs=clustered_pcm_cost_coefficients(units, clusters)
		pmin=coeffs.pmin
		pmax=coeffs.pmax
		ru=[minimum(units.ramp_up[c.unit_indices]) for c ∈ clusters]
		rd=[minimum(units.ramp_down[c.unit_indices]) for c ∈ clusters]
		sr=[minimum(units.shut_up[c.unit_indices]) for c ∈ clusters]
		dr=[minimum(units.shut_down[c.unit_indices]) for c ∈ clusters]
		block=(pmax .- pmin) ./ 3
		refcost=coeffs.refcost
		slopes=coeffs.eachslope
		suc=coeffs.startup
		sdc=coeffs.shutdown
		U0=[count(i->units.x_0[i]>0.5, c.unit_indices) for c ∈ clusters]
		m=Model(optimizer)
		set_silent(m)
		pcm_solver_name() == "gurobi" && set_optimizer_attribute(
			m, "MIPGap", parse(Float64, get(ENV, "PCM_MIP_GAP", "0.015")))
		pcm_solver_name() == "gurobi" && set_optimizer_attribute(
			m, "Threads", max(1, parse(Int, get(ENV, "PCM_SOLVER_THREADS", "16"))))
		solver_limit=tryparse(Float64, get(ENV, "PCM_SOLVER_TIME_LIMIT_SECONDS", ""))
		if solver_limit !== nothing && solver_limit > 0
			# 与单机 PCM 使用相同的单窗时限，保证大规模性能对比公平。
			pcm_solver_name() == "gurobi" && set_optimizer_attribute(m, "TimeLimit", solver_limit)
		end
		# Integer counts replace per-unit binaries. For a cluster of n identical
		# units, U/Y/Z record how many are online/starting/stopping at each hour.
		@variable(m, 0<=U[g = 1:C, t = 1:NT]<=n[g], Int)
		@variable(m, 0<=Y[g = 1:C, t = 1:NT]<=n[g], Int)
		@variable(m, 0<=Z[g = 1:C, t = 1:NT]<=n[g], Int)
		# 簇内至少一台机组在线的指示量，用于保持最大单机事故备用与
		# 物理模型一致；不能用 U/n 缩放单机事故容量。
		@variable(m, cluster_online[1:C,1:NT], Bin)
		@variable(m, P[1:C, 1:NT]>=0)
		@variable(m, R[1:C, 1:NT]>=0)
		@variable(m, Rdown[1:C, 1:NT]>=0)
		@variable(m, Q[1:C, 1:NT, 1:3]>=0)
		@variable(m, ls[1:ND, 1:NT]>=0)
		@variable(m, wc[1:NW, 1:NT]>=0)
		@variable(m, H[1:NH, 1:NT]>=0)
		use_extended_hull=lowercase(get(ENV, "PCM_CLUSTER_EXTENDED_HULL", "true")) in ("1", "true", "yes", "on")
		# 默认使用真正联合的乘积状态流；诊断重求时才退回连续驻留—功率流。
		extended_state_flow=use_extended_hull && use_output_state ?
			add_cluster_residence_output_product_hull!(m, clusters, units, NT, U, Y, Z, P;
				bins=output_bins, tolerance=tolerance) : use_extended_hull ?
			add_cluster_residence_power_flow_hull!(m, clusters, units, NT, U, Y, Z, P; tolerance=tolerance) :
			Dict{Int, NamedTuple}()
		output_state_flow=Dict{Int, NamedTuple}()
		for g ∈ 1:C, t ∈ 1:NT

			prev=t==1 ? U0[g] : U[g, t - 1]
			@constraint(m,U[g,t]>=cluster_online[g,t])
			@constraint(m,U[g,t]<=n[g]*cluster_online[g,t])
			@constraint(m, U[g, t]-prev==Y[g, t]-Z[g, t])
			@constraint(m, Y[g, t]+Z[g, t]<=n[g])
			if t==1
				# The aggregate count balance alone does not know which initially
				# online units can physically reach zero in the first hour.  Limit
				# first-hour transitions to the boundary-ramp-eligible cohorts so
				# every accepted count trajectory has a physical path assignment.
				shutdown_eligible=count(i -> units.x_0[i]>0.5 &&
					units.p_0[i]<=units.shut_down[i]+tolerance, clusters[g].unit_indices)
				startup_eligible=count(i -> units.x_0[i]<=0.5 &&
					units.p_min[i]<=units.shut_up[i]+tolerance, clusters[g].unit_indices)
				@constraint(m, Z[g, t]<=shutdown_eligible)
				@constraint(m, Y[g, t]<=startup_eligible)
			end
			@constraint(m, P[g, t]==pmin[g]*U[g, t]+sum(Q[g, t, k] for k ∈ 1:3))
			for k ∈ 1:3
				@constraint(m, Q[g, t, k]<=block[g]*U[g, t])
			end
			@constraint(m, P[g, t]+R[g, t]<=pmax[g]*U[g, t])
			@constraint(m, P[g, t]-Rdown[g, t]>=pmin[g]*U[g, t])
			# 启停爬坡凸包强化：新启动机组在本时段最多达到 startup
			# ramp；下一时段停机的机组在当前时段必须已降至 shutdown
			# ramp。仅有簇总爬坡约束时，这两类不可解群轨迹仍会进入主解。
			# Reserve in the legacy single-unit PCM is capacity-limited but is not
			# coupled to the energy ramp constraint, so this hull must constrain P
			# (not P+R) to preserve exact formulation parity.
			@constraint(m, P[g, t]<=sr[g]*Y[g, t]+pmax[g]*(U[g, t]-Y[g, t]))
			previous_power=t==1 ? sum(units.p_0[clusters[g].unit_indices]) : P[g, t-1]
			# Workbook/rolling boundaries may carry nonzero p₀ on an offline
			# record.  The legacy physical model accepts that boundary, so apply
			# the shutdown hull only after the first optimized period.
			t>1 && @constraint(m, previous_power<=dr[g]*Z[g, t]+pmax[g]*(prev-Z[g, t]))
			@constraint(m,
				P[g, t]-previous_power <=
				_clustered_pcm_up_ramp_limit(prev, Y[g, t], ru[g], sr[g]))
			@constraint(m,
				previous_power-P[g, t] <=
				_clustered_pcm_down_ramp_limit(U[g, t], Z[g, t], rd[g], dr[g]))
			L=clusters[g].min_up
			D=clusters[g].min_down
			@constraint(m, sum(Y[g, k] for k ∈ max(1, t - L + 1):t)<=U[g, t])
			@constraint(m, sum(Z[g, k] for k ∈ max(1, t - D + 1):t)<=n[g]-U[g, t])
			# Keep the default feasible region aligned with the physical
			# single-unit benchmark. Strict initial-dwell cohort bounds can be
			# enabled for studies that also enable the corresponding constraint
			# in standard PCM; the residence-flow certificate remains mandatory.
			if lowercase(get(ENV, "PCM_CLUSTER_ENFORCE_INITIAL_DWELL", "true")) in ("1", "true", "yes", "on")
				forced_online = count(i -> units.x_0[i] > 0.5 && units.t_0[i] > 0 &&
										   max(0, ceil(Int, units.min_shutup_time[i] - units.t_0[i])) >= t,
					clusters[g].unit_indices)
				forced_offline = count(i -> units.x_0[i] <= 0.5 && units.t_1[i] > 0 &&
											max(0, ceil(Int, units.min_shutdown_time[i] - units.t_1[i])) >= t,
					clusters[g].unit_indices)
				forced_online > 0 && @constraint(m, U[g, t] >= forced_online)
				forced_offline > 0 && @constraint(m, U[g, t] <= n[g] - forced_offline)
			end
		end
		# Each disaggregation cut is a valid local no-good: it excludes exactly
		# one U/Y/Z tuple proven physically infeasible, while leaving all other
		# commitment-count combinations available to the clustered master.
		for (k, cut) ∈ enumerate(physical_cuts)
			g, t=cut.cluster, cut.period
			(g in 1:C && t in 1:NT) || continue
			cut_direction=@variable(m, [1:6], Bin, base_name="physical_cut_$(k)")
			M=n[g]+1
			@constraint(m, U[g, t] <= cut.commitment-1 + M*(1-cut_direction[1]))
			@constraint(m, U[g, t] >= cut.commitment+1 - M*(1-cut_direction[2]))
			@constraint(m, Y[g, t] <= cut.startup-1 + M*(1-cut_direction[3]))
			@constraint(m, Y[g, t] >= cut.startup+1 - M*(1-cut_direction[4]))
			@constraint(m, Z[g, t] <= cut.shutdown-1 + M*(1-cut_direction[5]))
			@constraint(m, Z[g, t] >= cut.shutdown+1 - M*(1-cut_direction[6]))
			@constraint(m, sum(cut_direction)>=1)
		end
		for d ∈ 1:ND, t ∈ 1:NT

			@constraint(m, ls[d, t]==0)
		end
		for w ∈ 1:NW, t ∈ 1:NT

			@constraint(m, wc[w, t]<=winds.scenarios_curve[1, t]*winds.p_max[w])
		end
		for h ∈ 1:NH, t ∈ 1:NT

			@constraint(m, hydros.p_min[h]<=H[h, t])
			@constraint(m, H[h, t]<=hydros.p_max[h])
			@constraint(m, H[h, t]<=hydros.reservoircurve[t, 1])
		end
		for h ∈ 1:NH
			@constraint(m, hydros.q_0[h]+sum(hydros.reservoircurve[t, 1]-H[h, t] for t ∈ 1:NT)<=hydros.q_max[h])
		end
		for t ∈ 1:NT
			demand=sum(loads.load_curve[:, t])
			wind=sum(winds.scenarios_curve[1, t]*winds.p_max[w] for w ∈ 1:NW)
			@constraint(m, sum(P[:, t])+sum(H[:, t])+wind-sum(wc[:, t])+sum(ls[:, t])==demand)
			hydro_up=sum(min(hydros.p_max[h], hydros.reservoircurve[t, 1])-H[h, t] for h ∈ 1:NH)
			for g ∈ 1:C
				@constraint(m,sum(R[:,t])+hydro_up>=0.5*pmax[g]*cluster_online[g,t])
			end
			forecast_reserve=winds.scenarios_curve[1, t]*sum(winds.p_max)*0.05
			@constraint(m,
				sum(Rdown[:, t])+sum(H[h, t]-hydros.p_min[h] for h ∈ 1:NH)>=config_param.is_Alpha*forecast_reserve+config_param.is_Belta*demand)
		end
		gsdf_master=config_param.is_NetWorkCon==1 ? calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND) : nothing
		if gsdf_master!==nothing
			network_margin=max(10*tolerance, 1e-4)
			for l ∈ unique(feedback_lines), t ∈ 1:NT

				flow=@expression(m,
					sum(gsdf_master[l, units.locatebus[first(clusters[g].unit_indices)]]*P[g, t] for g ∈ 1:C) +
					sum(gsdf_master[l, hydros.locatebus[h]]*H[h, t] for h ∈ 1:NH) +
					sum(gsdf_master[l, winds.index[w]]*(winds.scenarios_curve[1, t]*winds.p_max[w]-wc[w, t]) for w ∈ 1:NW) -
					sum(gsdf_master[l, loads.locatebus[d]]*(loads.load_curve[d, t]-ls[d, t]) for d ∈ 1:ND))
				@constraint(m, lines.p_min[l]+network_margin<=flow)
				@constraint(m, flow<=lines.p_max[l]-network_margin)
			end
		end
		@objective(m, Min, clustered_pcm_economic_expression(config_param, coeffs, U, Y, Z, Q, R, Rdown, ls, wc;
			scenarios_prob = 1.0))
		if isdefined(@__MODULE__, :PCM_CLUSTER_EXTENDED_INTEGER_VARIABLES)
			PCM_CLUSTER_EXTENDED_INTEGER_VARIABLES[] = JuMP.num_constraints(m, JuMP.VariableRef, MOI.Integer)
		end
		optimize!(m)
		if !(termination_status(m) in (MOI.OPTIMAL, MOI.TIME_LIMIT))
			if use_extended_hull && use_output_state && termination_status(m) in (MOI.INFEASIBLE, MOI.INFEASIBLE_OR_UNBOUNDED)
				max_bins=parse(Int, get(ENV, "PCM_CLUSTER_MAX_OUTPUT_BINS", "17"))
				refine_grid=output_bins<max_bins
				refined_bins=min(max_bins, max(17, 2output_bins-1))
				println(refine_grid ?
					"    $(output_bins)-point output grid is infeasible; retrying this window with $(refined_bins) points" :
					"    Refined output grid is infeasible; entering continuous residence-power diagnosis")
				return solve_true_clustered_pcm_window(NT, NB, NG, ND, units, loads, winds, lines,
					config_param, NL, hydros, NH; optimizer=optimizer, tolerance=tolerance,
					feedback_lines=feedback_lines, iteration=iteration, max_iterations=max_iterations,
					max_cluster_size=max_cluster_size, refinement_used=refinement_used,
					physical_cuts=physical_cuts, physical_iteration=physical_iteration,
					max_physical_iterations=max_physical_iterations, expanded_units=expanded_units,
					targeted_refinements=targeted_refinements,
					max_targeted_refinements=max_targeted_refinements, use_output_state=refine_grid,
					output_bins=refined_bins)
			end
			return (feasible=false, stage=:cluster_master, message=string(termination_status(m)))
		end
		Ui=round.(Int, JuMP.value.(U))
		Yi=round.(Int, JuMP.value.(Y))
		Zi=round.(Int, JuMP.value.(Z))
		Pv=JuMP.value.(P)
		Rv=JuMP.value.(R)
		# Aggregate minimum-time inequalities are not a physical certificate by
		# themselves. The residence-flow checker must construct one legal integral
		# path for every physical unit before dispatch disaggregation is attempted.
		checks=Dict{Int, TrajectoryCheckResult}()
		paths=AnonymousUnitPath[]
		mapping=Dict{Int, Int}()
		fast_assignment_feasible=true
		physical=_pcm_physical_units(clusters, units)
		for c ∈ clusters
			q=check_cluster_trajectory_feasibility(c, vec(Ui[c.id, :]), vec(Yi[c.id, :]), vec(Zi[c.id, :]), _pcm_initial_states(c, units))
			checks[c.id]=q
			q.feasible||return (feasible = false, stage = :residence_flow, message = q.diagnostic_message, checks = checks)
			mp=assign_paths_to_physical_units(c, q.paths, physical)
			if mp===nothing
				# 匿名流路径的贪心映射不是可行性证书。保留聚类解并转入下方
				# 精确簇内 MILP，而不是把启发式映射失败误报为聚类失败。
				fast_assignment_feasible=false
				continue
			end
			append!(paths, q.paths)
			merge!(mapping, Dict((c.id*10000+p.id)=>u for (p, u) ∈ [(p, mp[p.id]) for p ∈ q.paths]))
		end
		assigned=Pair{AnonymousUnitPath, Int}[]
		if fast_assignment_feasible
		for c ∈ clusters, p ∈ checks[c.id].paths

			global_path=AnonymousUnitPath(; id = c.id*10000+p.id, initial_on = p.initial_on, initial_duration = p.initial_duration,
				u = p.u, y = p.y, z = p.z, age = p.age, states = p.states)
			push!(assigned, global_path=>only(u for (key, u) ∈ mapping if key==c.id*10000+p.id))
		end
		end
		schedules=[ClusterSchedule(; cluster = g, commitment = vec(Ui[g, :]), startup = vec(Yi[g, :]),
					   shutdown = vec(Zi[g, :]), power = vec(Pv[g, :]), reserve = vec(Rv[g, :])) for g ∈ 1:C]
		fixedinj=zeros(NB, NT)
		for d ∈ 1:ND, t ∈ 1:NT

			fixedinj[loads.locatebus[d], t]-=loads.load_curve[d, t]-value(ls[d, t])
		end
		for w ∈ 1:NW, t ∈ 1:NT

			fixedinj[winds.index[w], t]+=winds.scenarios_curve[1, t]*winds.p_max[w]-value(wc[w, t])
		end
		for h ∈ 1:NH, t ∈ 1:NT

			fixedinj[hydros.locatebus[h], t]+=value(H[h, t])
		end
		gsdf=gsdf_master===nothing ? zeros(0, NB) : gsdf_master
		net=NetworkData(; buses = collect(1:NB), ptdf = gsdf===nothing ? zeros(0, NB) : Matrix(gsdf),
			line_limits = min.(abs.(lines.p_min), abs.(lines.p_max)), fixed_injection = fixedinj)
		# The master deliberately starts without the complete network. Here the
		# certified paths are dispatched on the physical PTDF network. Conflicting
		# lines are returned to the master as a small feedback set.
		function exact_physical_certificate()
			strict=solve_exact_unit_disaggregation(schedules, physical; network_data=net,
				optimizer=optimizer, tolerance=tolerance, diagnose_counts=false)
			strict.feasible && return strict
			# 只有严格计数模型没有得到可行解时才启动偏差归因模型。
			solve_exact_unit_disaggregation(schedules, physical; network_data=net,
				optimizer=optimizer, tolerance=tolerance, diagnose_counts=true)
		end
		dis=fast_assignment_feasible ?
			solve_unit_disaggregation(schedules, assigned, physical; network_data = net, optimizer = optimizer, tolerance = tolerance) :
			exact_physical_certificate()
		if !dis.feasible && dis.feedback.failure_stage != :network
			# Fast anonymous-path assignment is intentionally cheap but may choose
			# a poor shutdown order.  Certify the same aggregate U/Y/Z/P trajectory
			# with an exact cluster-internal assignment before declaring fallback.
			println("    Fast disaggregation failed at $(dis.feedback.failure_stage); trying exact cluster-internal certificate")
			dis=exact_physical_certificate()
		end
		if !dis.feasible
			if dis.feedback.failure_stage==:count_trajectory &&
				targeted_refinements<max_targeted_refinements && !isempty(dis.feedback.affected_clusters) &&
				C/NG<=1-parse(Float64,get(ENV,"PCM_CLUSTER_MIN_STATE_REDUCTION_PCT","40"))/100
				bad=findfirst(g->g in eachindex(clusters) && length(clusters[g].unit_indices)>1,
					dis.feedback.affected_clusters)
				bad=bad===nothing ? nothing : dis.feedback.affected_clusters[bad]
				if bad !== nothing
					new_expanded=union(expanded_units, Set(clusters[bad].unit_indices))
					println("    Targeted refinement $(targeted_refinements+1): expanding cluster $bad ($(length(clusters[bad].unit_indices)) units) after physical certificate failure")
					return solve_true_clustered_pcm_window(
						NT, NB, NG, ND, units, loads, winds, lines, config_param, NL, hydros, NH;
						optimizer=optimizer, tolerance=tolerance, feedback_lines=feedback_lines,
						iteration=iteration, max_iterations=max_iterations, max_cluster_size=max_cluster_size,
						refinement_used=refinement_used, physical_cuts=NamedTuple[], physical_iteration=1,
						max_physical_iterations=max_physical_iterations, expanded_units=new_expanded,
						targeted_refinements=targeted_refinements+1, max_targeted_refinements=max_targeted_refinements,
						use_output_state=use_output_state, output_bins=output_bins)
				end
			end
			if dis.feedback.failure_stage==:count_trajectory &&
				physical_iteration<max_physical_iterations && !isempty(dis.feedback.suggested_cuts)
				newcuts=copy(physical_cuts)
				for cut ∈ dis.feedback.suggested_cuts
					key=(cut.cluster, cut.period, cut.commitment, cut.startup, cut.shutdown)
					any((x.cluster, x.period, x.commitment, x.startup, x.shutdown)==key for x ∈ newcuts) || push!(newcuts, cut)
				end
				if length(newcuts)>length(physical_cuts)
					println("    Physical feedback iteration $physical_iteration: excluding infeasible local U/Y/Z tuple at cluster $(first(dis.feedback.suggested_cuts).cluster), period $(first(dis.feedback.suggested_cuts).period)")
					return solve_true_clustered_pcm_window(
						NT, NB, NG, ND, units, loads, winds, lines, config_param, NL, hydros, NH;
						optimizer=optimizer, tolerance=tolerance, feedback_lines=feedback_lines,
						iteration=iteration, max_iterations=max_iterations, max_cluster_size=max_cluster_size,
						refinement_used=refinement_used, physical_cuts=newcuts,
						physical_iteration=physical_iteration+1, max_physical_iterations=max_physical_iterations,
						expanded_units=expanded_units, targeted_refinements=targeted_refinements,
						max_targeted_refinements=max_targeted_refinements, use_output_state=use_output_state,
						output_bins=output_bins)
				end
			end
			allow_refinement=lowercase(get(ENV, "PCM_CLUSTER_ALLOW_GLOBAL_REFINEMENT", "false")) in ("1", "true", "yes", "on")
			if allow_refinement && dis.feedback.failure_stage != :network && !refinement_used && any(length(c.unit_indices)>2 for c ∈ clusters)
				println("    Physical certificate failed; refining homogeneous clusters to at most 2 units and resolving once")
				return solve_true_clustered_pcm_window(
					NT, NB, NG, ND, units, loads, winds, lines, config_param, NL, hydros, NH;
					optimizer=optimizer, tolerance=tolerance, feedback_lines=feedback_lines,
					iteration=iteration, max_iterations=max_iterations,
					max_cluster_size=2, refinement_used=true, physical_cuts=NamedTuple[],
					physical_iteration=1, max_physical_iterations=max_physical_iterations,
					expanded_units=expanded_units, targeted_refinements=targeted_refinements,
					max_targeted_refinements=max_targeted_refinements, use_output_state=use_output_state,
					output_bins=output_bins)
			end
			new_lines=unique(vcat(feedback_lines, dis.feedback.affected_lines))
			if dis.feedback.failure_stage==:network && iteration<max_iterations && length(new_lines)>length(feedback_lines)
				println("    Cluster feedback iteration $iteration: adding line cuts $(setdiff(new_lines,feedback_lines))")
				return solve_true_clustered_pcm_window(
					NT, NB, NG, ND, units, loads, winds, lines, config_param, NL, hydros, NH; optimizer = optimizer,
					tolerance = tolerance, feedback_lines = new_lines, iteration = iteration+1, max_iterations = max_iterations,
					max_cluster_size=max_cluster_size, refinement_used=refinement_used,
					physical_cuts=physical_cuts, physical_iteration=physical_iteration,
					max_physical_iterations=max_physical_iterations, expanded_units=expanded_units,
					targeted_refinements=targeted_refinements, max_targeted_refinements=max_targeted_refinements,
					use_output_state=use_output_state, output_bins=output_bins)
			end
			return (feasible = false,
				stage = dis.feedback.failure_stage == :network ? :network_disaggregation : :physical_disaggregation,
				message = "$(dis.feedback.message); lines=$(dis.feedback.affected_lines), periods=$(dis.feedback.affected_periods), deviations=$(length(dis.feedback.dispatch_deviation))",
				feedback = dis.feedback,
				cluster_solution = schedules)
		end
		x=Float64.(dis.commitment)
		y=Float64.(dis.startup)
		z=Float64.(dis.shutdown)
		p=dis.power
		r=dis.reserve
		rdown=JuMP.value.(Rdown)
		hydro_values=JuMP.value.(H)
		wind_curtailment=JuMP.value.(wc)
		physical_redispatch_used=false
		if use_extended_hull
			# Output states certify the integer trajectory; this continuous second
			# stage removes discretization error without changing x/y/z.
			physical_dispatch=solve_clustered_physical_network_dispatch(
				x, y, z, units, loads, winds, hydros, lines,
				gsdf_master===nothing ? zeros(0, NB) : gsdf_master,
				config_param, NT, ND, NW, NH; optimizer=optimizer, tolerance=tolerance)
			if physical_dispatch===nothing
				# 受限计数修复可能通过离散证书、但仍无法形成零切负荷连续调度。
				# 使用同一证书继续局部展开，避免在反馈闭环的最后一步直接全量回退。
				if targeted_refinements<max_targeted_refinements &&
					!isempty(dis.feedback.affected_clusters) &&
					C/NG<=1-parse(Float64,get(ENV,"PCM_CLUSTER_MIN_STATE_REDUCTION_PCT","40"))/100
					candidates=[g for g ∈ dis.feedback.affected_clusters
						if g in eachindex(clusters) && length(clusters[g].unit_indices)>1]
					bad=isempty(candidates) ? nothing : first(candidates)
					if bad!==nothing
						println("    Continuous dispatch rejected repaired path; expanding cluster $bad and resolving")
						return solve_true_clustered_pcm_window(NT,NB,NG,ND,units,loads,winds,lines,
							config_param,NL,hydros,NH; optimizer=optimizer,tolerance=tolerance,
							feedback_lines=feedback_lines,iteration=iteration,max_iterations=max_iterations,
							max_cluster_size=max_cluster_size,refinement_used=refinement_used,
							physical_cuts=NamedTuple[],physical_iteration=1,
							max_physical_iterations=max_physical_iterations,
							expanded_units=union(expanded_units,Set(clusters[bad].unit_indices)),
							targeted_refinements=targeted_refinements+1,
							max_targeted_refinements=max_targeted_refinements,
							use_output_state=use_output_state,output_bins=output_bins)
					end
				end
				return (feasible=false,stage=:physical_continuous_dispatch,
					message="fixed extended-hull commitment has no strict continuous physical dispatch")
			end
			p=physical_dispatch.power
			r=physical_dispatch.reserve_up
			rdown=physical_dispatch.reserve_down
			hydro_values=physical_dispatch.hydro
			wind_curtailment=physical_dispatch.wind_curtailment
			physical_redispatch_used=true
			# 二阶段经济反馈：若固定承诺造成显著弃风，排除最大弃风时段中
			# 贡献最大的非单机簇局部 U/Y/Z 组合，再解聚类主问题。切面只
			# 排除一个已验证经济性较差的局部组合，不放松任何物理约束。
			spill_tolerance=parse(Float64,get(ENV,"PCM_CLUSTER_WIND_FEEDBACK_TOL_MWH","0.01"))
			spill_by_period=vec(sum(wind_curtailment;dims=1))
			wind_feedback_enabled=lowercase(get(ENV,"PCM_CLUSTER_ENABLE_WIND_FEEDBACK","false")) in ("1","true","yes","on")
			if wind_feedback_enabled && maximum(spill_by_period;init=0.0)>spill_tolerance &&
				physical_iteration<max_physical_iterations
				t=argmax(spill_by_period)
				candidates=sort([g for g ∈ 1:C if n[g]>1 && Ui[g,t]>0];
					by=g->-(pmin[g]*Ui[g,t]))
				chosen=findfirst(g->!any(cut.cluster==g && cut.period==t &&
					cut.commitment==Ui[g,t] && cut.startup==Yi[g,t] && cut.shutdown==Zi[g,t]
					for cut ∈ physical_cuts),candidates)
				if chosen!==nothing
					g=candidates[chosen]
					newcuts=copy(physical_cuts)
					push!(newcuts,(cluster=g,period=t,commitment=Ui[g,t],startup=Yi[g,t],
						shutdown=Zi[g,t],reason_variable=:wind_spill,
						diagnostic_direction=:economic,magnitude=spill_by_period[t]))
					println("    Wind feedback iteration $physical_iteration: $(round(spill_by_period[t];digits=4)) MWh at period $t; excluding cluster $g local commitment tuple")
					return solve_true_clustered_pcm_window(NT,NB,NG,ND,units,loads,winds,lines,
						config_param,NL,hydros,NH; optimizer=optimizer,tolerance=tolerance,
						feedback_lines=feedback_lines,iteration=iteration,max_iterations=max_iterations,
						max_cluster_size=max_cluster_size,refinement_used=refinement_used,
						physical_cuts=newcuts,physical_iteration=physical_iteration+1,
						max_physical_iterations=max_physical_iterations,expanded_units=expanded_units,
						targeted_refinements=targeted_refinements,
						max_targeted_refinements=max_targeted_refinements,
						use_output_state=use_output_state,output_bins=output_bins)
				end
			end
		end
		pk=zeros(NG, NT, 3)
		for i ∈ 1:NG, t ∈ 1:NT

			rem=max(0.0, p[i, t]-units.p_min[i]*x[i, t])
			block=(units.p_max[i]-units.p_min[i])/3
			for k ∈ 1:3
				pk[i, t, k]=min(block, max(0.0, rem-block*(k-1)))
			end
		end
		su=y .* units.coffi_cold_shutup_1
		sd=z .* units.coffi_cold_shutdown_1
		costs=physical_pcm_economic_cost(config_param, units, x, y, z, p, r, rdown,
			JuMP.value.(ls), wind_curtailment)
		master_cost=objective_value(m)
		physical_cost=sum(costs)
		cost_gap=abs(physical_cost-master_cost)/max(abs(physical_cost), 1.0)
		cost_gap_limit=parse(Float64, get(ENV, "PCM_CLUSTER_COST_GAP_TOL", "0.005"))
		if !physical_redispatch_used && cost_gap>cost_gap_limit
			return (feasible = false, stage = :cost_consistency,
				message = "aggregate/physical cost gap $(round(100cost_gap; digits = 4))% exceeds $(100cost_gap_limit)%",
				master_cost = master_cost, physical_cost = physical_cost, clusters = clusters, checks = checks)
		end
		rdphys=zeros(NG, NT)
		for g ∈ 1:C, t ∈ 1:NT

			ids=clusters[g].unit_indices
			available=sum(max(0.0, p[i, t]-units.p_min[i]*x[i, t]) for i ∈ ids)
			if physical_redispatch_used
				rdphys[ids, t].=rdown[ids, t]
			else
				available>tolerance&&foreach(i->rdphys[i, t]=rdown[g, t]*max(0.0, p[i, t]-units.p_min[i]*x[i, t])/available, ids)
			end
		end
		results=Dict{String, Array{Float64}}(
			"x₀"=>x, "u₀"=>y, "v₀"=>z, "p₀"=>p, "pₖ"=>pk, "su_cost"=>su, "sd_cost"=>sd, "seq_sr⁺"=>r, "seq_sr⁻"=>rdphys,
			"pᵨ"=>JuMP.value.(ls), "pᵩ"=>wind_curtailment, "hydros_output"=>hydro_values, "res_scheduled_costs"=>costs,
			"cluster_ids"=>Float64.([only(c.id for c ∈ clusters if i in c.unit_indices) for i ∈ 1:NG]),
			"cluster_disaggregation_feasible"=>ones(1, 1))
		return (feasible = true, stage = :complete, results = results, clusters = clusters, checks = checks,
			master = m, disaggregation = dis, feedback_iterations = iteration-1, feedback_lines = feedback_lines)
	end
end
