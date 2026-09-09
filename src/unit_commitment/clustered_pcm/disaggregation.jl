module ClusteredDisaggregation
using JuMP, GLPK
import MathOptInterface as MOI

export ClusterSpec, InitialUnitState, PhysicalUnitData, NetworkData, ClusterSchedule, AnonymousUnitPath, TrajectoryCheckResult,
	   DisaggregationFeedback, UnitDisaggregationResult, check_cluster_trajectory_feasibility, decompose_state_flow_to_paths,
	   assign_paths_to_physical_units, solve_unit_disaggregation, solve_exact_unit_disaggregation,
	   run_cluster_disaggregation, validate_disaggregation

Base.@kwdef struct ClusterSpec
	id::Int
	unit_indices::Vector{Int}
	min_up::Int
	min_down::Int
	enforce_terminal_residence::Bool=false
end
Base.@kwdef struct InitialUnitState
	unit::Int
	on::Bool
	duration::Int
end
Base.@kwdef struct PhysicalUnitData
	id::Int
	cluster::Int
	bus::Int
	p_min::Float64
	p_max::Float64
	ramp_up::Float64=Inf
	ramp_down::Float64=Inf
	startup_ramp::Float64=Inf
	shutdown_ramp::Float64=Inf
	initial_on::Bool=false
	initial_duration::Int=0
	initial_power::Float64=0.0
	min_up::Int=1
	min_down::Int=1
	marginal_cost::Float64=0.0
	availability::Vector{Bool}=Bool[]
	must_run::Vector{Bool}=Bool[]
	must_off::Vector{Bool}=Bool[]
end
Base.@kwdef struct NetworkData
	buses::Vector{Int}
	ptdf::Matrix{Float64}=zeros(0, length(buses))
	line_limits::Vector{Float64}=Float64[]
	fixed_injection::Matrix{Float64}=zeros(length(buses), 0)
	line_names::Vector{String}=String[]
end
Base.@kwdef struct ClusterSchedule
	cluster::Int
	commitment::Vector{Int}
	startup::Vector{Int}
	shutdown::Vector{Int}
	power::Vector{Float64}
	reserve::Vector{Float64}=zeros(length(commitment))
end
Base.@kwdef struct AnonymousUnitPath
	id::Int
	initial_on::Bool
	initial_duration::Int
	u::Vector{Int}
	y::Vector{Int}
	z::Vector{Int}
	age::Vector{Int}
	states::Vector{Symbol}
end
Base.@kwdef struct TrajectoryCheckResult
	feasible::Bool
	conflict_cluster::Union{Nothing, Int}=nothing
	conflict_period::Union{Nothing, Int}=nothing
	conflict_type::Union{Nothing, Symbol}=nothing
	state_flow::Any=nothing
	paths::Vector{AnonymousUnitPath}=AnonymousUnitPath[]
	diagnostic_message::String=""
	suggested_cuts::Vector{NamedTuple}=NamedTuple[]
	warnings::Vector{String}=String[]
end
Base.@kwdef struct DisaggregationFeedback
	feasible::Bool
	failure_stage::Symbol=:none
	affected_clusters::Vector{Int}=Int[]
	affected_periods::Vector{Int}=Int[]
	affected_buses::Vector{Int}=Int[]
	affected_lines::Vector{Int}=Int[]
	commitment_deviation::Dict{Tuple{Int, Int}, Float64}=Dict()
	startup_deviation::Dict{Tuple{Int, Int}, Float64}=Dict()
	shutdown_deviation::Dict{Tuple{Int, Int}, Float64}=Dict()
	dispatch_deviation::Dict{Tuple{Int, Int}, Float64}=Dict()
	suggested_cuts::Vector{NamedTuple}=NamedTuple[]
	suggested_cluster_splits::Vector{NamedTuple}=NamedTuple[]
	message::String=""
end
Base.@kwdef struct UnitDisaggregationResult
	feasible::Bool
	diagnostic::Bool=false
	commitment::Matrix{Int}=zeros(Int, 0, 0)
	startup::Matrix{Int}=zeros(Int, 0, 0)
	shutdown::Matrix{Int}=zeros(Int, 0, 0)
	power::Matrix{Float64}=zeros(0, 0)
	reserve::Matrix{Float64}=zeros(0, 0)
	line_flow::Matrix{Float64}=zeros(0, 0)
	assignment::Dict{Int, Int}=Dict()
	feedback::DisaggregationFeedback=DisaggregationFeedback(feasible = true)
end

function _bad(c, t, k, msg, w, cuts = NamedTuple[])
	TrajectoryCheckResult(; feasible = false, conflict_cluster = c.id, conflict_period = t,
		conflict_type = k, diagnostic_message = msg, warnings = w, suggested_cuts = cuts)
end

"""
O(NT) construction of an integral flow over ON(a), ON(L+), OFF(a), OFF(D+) states.
"""
function check_cluster_trajectory_feasibility(c::ClusterSpec, U0, Y0, Z0, initial = nothing)
	U, Y, Z=Int.(U0), Int.(Y0), Int.(Z0)
	T=length(U)
	N=length(c.unit_indices)
	w=String[]
	length(Y)==T==length(Z) || throw(ArgumentError("U/Y/Z horizon mismatch"))
	min(c.min_up, c.min_down)>=1 || throw(ArgumentError("minimum times must be >= 1"))
	if initial===nothing
		push!(w, "initial residence distribution missing; inferred initial count and assumed mature states")
		n0=T==0 ? 0 : U[1]-Y[1]+Z[1]
		initial=[InitialUnitState(; unit = c.unit_indices[i], on = i<=n0, duration = i<=n0 ? c.min_up : c.min_down) for i ∈ 1:N]
	else
		initial=collect(initial)
	end
	length(initial)==N || throw(ArgumentError("one initial state per unit is required"))
	any(s->s.duration<0, initial) && throw(ArgumentError("negative initial duration"))
	on=[s.on for s ∈ initial]
	age=[s.duration for s ∈ initial]
	n0=count(on)
	u=zeros(Int, N, T)
	y=zeros(Int, N, T)
	z=zeros(Int, N, T)
	ages=zeros(Int, N, T)
	states=fill(:OFF_MATURE, N, T)
	arcs=NamedTuple[]
	for t ∈ 1:T
		prev=t==1 ? n0 : U[t - 1]
		(0<=U[t]<=N && Y[t]>=0 && Z[t]>=0) || return _bad(c, t, :count_bounds, "count outside valid bounds", w)
		U[t]==prev+Y[t]-Z[t] || return _bad(c, t, :state_balance, "U[$t] does not satisfy U[t]-U[t-1]=Y[t]-Z[t]", w)
		# Prefer the longest-resident units.  All units are homogeneous inside
		# one cluster, so this maximizes future switching freedom and avoids a
		# unit-index-dependent false negative in the constructive certificate.
		starts=sort([i for i ∈ 1:N if !on[i]&&age[i]>=c.min_down]; by = i->(-age[i], i))
		stops=sort([i for i ∈ 1:N if on[i]&&age[i]>=c.min_up]; by = i->(-age[i], i))
		length(starts)>=Y[t] || return _bad(c, t, :minimum_down_time, "insufficient mature off pool", w,
			[(type = :mature_off_pool, cluster = c.id, period = t, required = Y[t], available = length(starts))])
		length(stops)>=Z[t] || return _bad(c, t, :minimum_up_time, "insufficient mature on pool", w,
			[(type = :mature_on_pool, cluster = c.id, period = t, required = Z[t], available = length(stops))])
		ss, ds=Set(starts[1:Y[t]]), Set(stops[1:Z[t]])
		for i ∈ 1:N
			oldon, oldage=on[i], age[i]
			if i in ss
				on[i]=true
				age[i]=1
				y[i, t]=1
			elseif i in ds
				on[i]=false
				age[i]=1
				z[i, t]=1
			else
				age[i]+=1
			end
			u[i, t]=on[i]
			ages[i, t]=age[i]
			states[i, t]=on[i] ? (age[i]>=c.min_up ? :ON_MATURE : Symbol("ON_$(age[i])")) :
						 (age[i]>=c.min_down ? :OFF_MATURE : Symbol("OFF_$(age[i])"))
			from=oldon ? (oldage>=c.min_up ? :ON_MATURE : Symbol("ON_$(oldage)")) : (oldage>=c.min_down ? :OFF_MATURE : Symbol("OFF_$(oldage)"))
			push!(arcs, (period = t, unit = i, from = from, to = states[i, t], flow = 1.0, startup = y[i, t], shutdown = z[i, t]))
		end
	end
	if c.enforce_terminal_residence && T>0
		any(i->age[i]<(on[i] ? c.min_up : c.min_down), 1:N) && return _bad(c, T, :terminal_residence, "unfinished terminal residence", w)
	end
	paths=[AnonymousUnitPath(; id = i, initial_on = initial[i].on, initial_duration = initial[i].duration, u = vec(u[i, :]),
			   y = vec(y[i, :]), z = vec(z[i, :]), age = vec(ages[i, :]), states = vec(states[i, :])) for i ∈ 1:N]
	counts=Dict{Tuple{Int, Symbol}, Float64}()
	for t ∈ 1:T, i ∈ 1:N

		counts[(t, states[i, t])]=get(counts, (t, states[i, t]), 0.0)+1
	end
	TrajectoryCheckResult(; feasible = true, state_flow = (arcs = arcs, state_counts = counts, target = (U = U, Y = Y, Z = Z), initial = initial),
		paths = paths, diagnostic_message = "integral state flow found", warnings = w)
end

decompose_state_flow_to_paths(::ClusterSpec, r::TrajectoryCheckResult, h::Integer) = r.feasible && (isempty(r.paths)||length(r.paths[1].u)==h) ?
																					 r.paths : throw(ArgumentError(r.diagnostic_message))

_flag(v, t, d) = isempty(v) ? d : v[t]
function _compatible(p, u)
	p.initial_on==u.initial_on || return false
	p.initial_duration<=u.initial_duration || return false
	if !isempty(p.u)
		# Anonymous residence paths are interchangeable only if their first
		# transition is reachable from the physical unit's actual boundary
		# dispatch.  Without this check a shutdown path could be assigned to a
		# high-output unit that cannot ramp to zero, even though another member
		# of the same homogeneous cluster can take that path.
		if p.initial_on && p.u[1]==0
			u.initial_power<=u.shutdown_ramp+1e-9 || return false
		elseif p.initial_on && p.u[1]==1
			lower=max(u.p_min, u.initial_power-u.ramp_down)
			upper=min(u.p_max, u.initial_power+u.ramp_up)
			lower<=upper+1e-9 || return false
		elseif !p.initial_on && p.u[1]==1
			u.p_min<=u.startup_ramp+1e-9 || return false
		end
	end
	for t ∈ eachindex(p.u)
		(!_flag(u.availability, t, true)&&p.u[t]==1) && return false
		(_flag(u.must_run, t, false)&&p.u[t]==0) && return false
		(_flag(u.must_off, t, false)&&p.u[t]==1) && return false
	end
	true
end

"""
Deterministic maximum bipartite matching; returns path-id => physical-unit-id.
"""
function assign_paths_to_physical_units(c::ClusterSpec, paths, data, network = nothing)
	units=[data[i] for i ∈ c.unit_indices]
	length(units)==length(paths)||throw(ArgumentError("path/unit count mismatch"))
	match=Dict{Int, Int}()
	function aug(pi, seen)
		shutdown_now=!isempty(paths[pi].z) && paths[pi].z[1]==1
		for j ∈ sortperm(units; by = u->(u.bus, u.marginal_cost,
			shutdown_now ? u.initial_power : -u.initial_power, u.id))
			(j in seen||!_compatible(paths[pi], units[j]))&&continue
			push!(seen, j)
			old=get(match, j, 0)
			if old==0||aug(old, seen)
				match[j]=pi
				return true
			end
		end
		false
	end
	all(aug(i, Set{Int}()) for i ∈ eachindex(paths)) || return nothing
	Dict(paths[pi].id=>units[j].id for (j, pi) ∈ match)
end

function _dispatch(schedules, pathpairs, units, net, diag, optimizer)
	I, T, C=length(units), length(first(schedules).power), length(schedules)
	pos=Dict(u.id=>i for (i, u) ∈ enumerate(units))
	bpos=Dict(b=>i for (i, b) ∈ enumerate(net.buses))
	U=zeros(Int, I, T)
	Y=similar(U)
	Z=similar(U)
	for (p, id) ∈ pathpairs
		i       = pos[id]
		U[i, :] .= p.u
		Y[i, :] .= p.y
		Z[i, :] .= p.z
	end
	m=Model(optimizer)
	set_silent(m)
	@variable(m, p[1:I, 1:T]>=0)
	@variable(m, r[1:I, 1:T]>=0)
	@variable(m, bp[1:T]>=0)
	@variable(m, bm[1:T]>=0)
	L=size(net.ptdf, 1)
	@variable(m, lp[1:L, 1:T]>=0)
	@variable(m, lm[1:L, 1:T]>=0)
	if diag
		@variable(m, dp[1:C, 1:T]>=0)
		@variable(m, dm[1:C, 1:T]>=0)
	end
	for i ∈ 1:I, t ∈ 1:T

		@constraint(m, p[i, t]>=units[i].p_min*U[i, t])
		@constraint(m, p[i, t]+r[i, t]<=units[i].p_max*U[i, t])
		prev=t==1 ? units[i].initial_power : p[i, t - 1]
		pu=t==1 ? Int(units[i].initial_on) : U[i, t - 1]
		# Match the physical single-unit PCM exactly.  The former p_max big-M
		# terms admitted trajectories that passed disaggregation but violated
		# the standard ramp boundary and could make the next rolling window
		# infeasible.
		@constraint(m, p[i, t]-prev<=units[i].ramp_up*pu+units[i].startup_ramp*Y[i, t])
		@constraint(m, prev-p[i, t]<=units[i].ramp_down*U[i, t]+units[i].shutdown_ramp*Z[i, t])
	end
	for (c, s) ∈ enumerate(schedules), t ∈ 1:T

		idx=findall(u->u.cluster==s.cluster, units)
		diag ? @constraint(m, sum(p[i, t] for i ∈ idx)==s.power[t]+dp[c, t]-dm[c, t]) : @constraint(m, sum(p[i, t] for i ∈ idx)==s.power[t])
	end
	for t ∈ 1:T
		@constraint(m, sum(r[:, t])>=sum(s.reserve[t] for s ∈ schedules))
	end
	fixed=size(net.fixed_injection, 2)==0 ? zeros(length(net.buses), T) : net.fixed_injection
	size(fixed)==(length(net.buses), T)||throw(ArgumentError("fixed_injection dimensions"))
	flows=Matrix{AffExpr}(undef, L, T)
	for t ∈ 1:T
		@constraint(m, sum(p[:, t])+sum(fixed[:, t])+bp[t]-bm[t]==0)
		for l ∈ 1:L
			flows[l, t]=@expression(m,
				sum(net.ptdf[l, bpos[units[i].bus]]*p[i, t] for i ∈ 1:I)+sum(net.ptdf[l, b]*fixed[b, t] for b ∈ eachindex(net.buses)))
			@constraint(m, flows[l, t]<=net.line_limits[l]+lp[l, t])
			@constraint(m, -flows[l, t]<=net.line_limits[l]+lm[l, t])
		end
	end
	mapdev=diag ? sum(dp)+sum(dm) : 0
	# Keep the feasibility-relaxation objective numerically well scaled.  The
	# former 1e12/1e9/1e6 hierarchy combined with the physical marginal costs
	# produced objective coefficients up to 1e15 on the 108-unit workbook and
	# caused Gurobi to return a numerical/unknown status instead of a useful
	# disaggregation certificate.  Balance and line violations remain dominant;
	# cluster-P deviation is only used after those system constraints are met.
	marginal_scale=max(maximum(abs(u.marginal_cost) for u ∈ units; init = 1.0), 1.0)
	@objective(m, Min,
		1e6*(sum(bp)+sum(bm)) +
		1e4*(sum(lp)+sum(lm)) +
		1e2*mapdev +
		sum((units[i].marginal_cost/marginal_scale)*p[i, t] for i ∈ 1:I, t ∈ 1:T))
	optimize!(m)
	status=termination_status(m)
	status in (MOI.OPTIMAL, MOI.LOCALLY_SOLVED) || return (status = status, solved = false)
	(U = U, Y = Y, Z = Z, p = value.(p), r = value.(r), flow = value.(flows), balance = value.(bp) .+ value.(bm),
		line = value.(lp) .+ value.(lm), dev = diag ? value.(dp) .- value.(dm) : zeros(C, T), status = status, solved = true)
end

function solve_unit_disaggregation(sol, assigned, data, bus = nothing, line = nothing, load = nothing, ptdf = nothing;
		network_data = nothing, optimizer = GLPK.Optimizer, tolerance = 1e-7)
	schedules=sol isa ClusterSchedule ? [sol] : collect(sol)
	units=collect(data)
	net=network_data===nothing ?
		NetworkData(; buses = collect(bus), ptdf = Matrix(ptdf), line_limits = Float64.(line), fixed_injection = -Matrix(load)) : network_data
	pairs=Dict{AnonymousUnitPath, Int}()
	for x ∈ assigned
		x isa Pair ? pairs[x.first]=x.second : pairs[x.path]=x.unit
	end
	a=_dispatch(schedules, pairs, units, net, false, optimizer)
	diagnostic=!a.solved||maximum(a.balance; init = 0.0)>tolerance||maximum(a.line; init = 0.0)>tolerance
	diagnostic&&(a=_dispatch(schedules, pairs, units, net, true, optimizer))
	!a.solved&&return UnitDisaggregationResult(; feasible = false, diagnostic = true,
		feedback = DisaggregationFeedback(; feasible = false, failure_stage = :solver,
			message = "disaggregation solver status $(a.status)"))
	lines=unique([l for l ∈ axes(a.line, 1), t ∈ axes(a.line, 2) if a.line[l, t]>tolerance])
	periods=unique(vcat(
		[t for t ∈ eachindex(a.balance) if a.balance[t]>tolerance], [t for l ∈ axes(a.line, 1), t ∈ axes(a.line, 2) if a.line[l, t]>tolerance],
		[t for c ∈ axes(a.dev, 1), t ∈ axes(a.dev, 2) if abs(a.dev[c, t])>tolerance]))
	dev=Dict((schedules[c].cluster, t)=>a.dev[c, t] for c ∈ axes(a.dev, 1), t ∈ axes(a.dev, 2) if abs(a.dev[c, t])>tolerance)
	# A diagnostic redispatch may change cluster-level P while preserving the
	# already accepted U/Y/Z paths.  This is a valid network-constrained physical
	# disaggregation whenever the hard balance and line slacks are zero.
	feasible=maximum(a.balance; init = 0.0)<=tolerance&&maximum(a.line; init = 0.0)<=tolerance
	capacity_conflict=false
	for schedule ∈ schedules
		cluster_units=findall(unit->unit.cluster==schedule.cluster, units)
		for t ∈ eachindex(schedule.power)
			capacity_conflict |= schedule.power[t]>sum(units[i].p_max*a.U[i, t] for i ∈ cluster_units)+tolerance
		end
	end
	stage=!isempty(lines) ? :network :
		  !isempty(dev) ? (feasible ? :physical_redispatch : (capacity_conflict ? :capacity : :ramp)) :
		  maximum(a.balance; init = 0.0)>tolerance ? :balance : :none
	bpos=Dict(b=>i for (i, b) ∈ enumerate(net.buses))
	buses=unique(units[i].bus for i ∈ eachindex(units) if any(l->l<=size(net.ptdf, 1)&&abs(net.ptdf[l, bpos[units[i].bus]])>tolerance, lines))
	fb=DisaggregationFeedback(; feasible = feasible,
		failure_stage = stage,
		affected_clusters = unique(first.(keys(dev))),
		affected_periods = periods,
		affected_buses = collect(buses),
		affected_lines = lines,
		dispatch_deviation = dev,
		suggested_cluster_splits = [(cluster = c, reason = :heterogeneous_dispatch) for c ∈ unique(first.(keys(dev)))],
		message = feasible ? (isempty(dev) ? "strict disaggregation feasible" : "network-constrained physical redispatch feasible") :
				  "diagnostic relaxation identified $stage")
	UnitDisaggregationResult(; feasible = feasible, diagnostic = diagnostic, commitment = a.U, startup = a.Y, shutdown = a.Z, power = a.p,
		reserve = a.r, line_flow = a.flow, assignment = Dict(p.id=>id for (p, id) ∈ pairs), feedback = fb)
end

"""
精确的簇内解群证书。

聚类主问题给定每个簇逐时的 U/Y/Z/P/R 总量，本模型只决定这些计数应由
哪些物理机组承担。它不会重新优化系统层面的机组组合，因此不同于单机 PCM
回退；其作用是消除固定贪心路径在停机顺序和爬坡分配上的假不可行。
"""
function solve_exact_unit_disaggregation(solutions, data;
		network_data, optimizer = GLPK.Optimizer, tolerance = 1e-7, diagnose_counts::Bool = true)
	schedules=solutions isa ClusterSchedule ? [solutions] : collect(solutions)
	units=collect(data)
	I, T=length(units), length(first(schedules).power)
	net=network_data
	bpos=Dict(b=>i for (i, b) ∈ enumerate(net.buses))
	m=Model(optimizer)
	set_silent(m)
	certificate_limit=parse(Float64, get(ENV, "PCM_CLUSTER_CERTIFICATE_TIME_LIMIT_SECONDS", "20"))
	certificate_limit>0 && set_time_limit_sec(m, certificate_limit)
	@variable(m, U[1:I, 1:T], Bin)
	@variable(m, Y[1:I, 1:T], Bin)
	@variable(m, Z[1:I, 1:T], Bin)
	@variable(m, p[1:I, 1:T]>=0)
	@variable(m, r[1:I, 1:T]>=0)
	C=length(schedules)
	@variable(m, dp[1:C, 1:T]>=0)
	@variable(m, dm[1:C, 1:T]>=0)
	@variable(m, balance_plus[1:T]>=0)
	@variable(m, balance_minus[1:T]>=0)
	if diagnose_counts
		@variable(m, uplus[1:C, 1:T]>=0, Int)
		@variable(m, uminus[1:C, 1:T]>=0, Int)
		@variable(m, yplus[1:C, 1:T]>=0, Int)
		@variable(m, yminus[1:C, 1:T]>=0, Int)
		@variable(m, zplus[1:C, 1:T]>=0, Int)
		@variable(m, zminus[1:C, 1:T]>=0, Int)
	end

	for i ∈ 1:I, t ∈ 1:T

		previous=t==1 ? Int(units[i].initial_on) : U[i, t - 1]
		@constraint(m, U[i, t]-previous==Y[i, t]-Z[i, t])
		@constraint(m, Y[i, t]+Z[i, t]<=1)
		@constraint(m, p[i, t]>=units[i].p_min*U[i, t])
		@constraint(m, p[i, t]+r[i, t]<=units[i].p_max*U[i, t])
		previous_power=t==1 ? units[i].initial_power : p[i, t - 1]
		@constraint(m, p[i, t]-previous_power<=units[i].ramp_up*previous+units[i].startup_ramp*Y[i, t])
		@constraint(m, previous_power-p[i, t]<=units[i].ramp_down*U[i, t]+units[i].shutdown_ramp*Z[i, t])
		L=max(1, units[i].min_up)
		D=max(1, units[i].min_down)
		@constraint(m, sum(Y[i, k] for k ∈ max(1, t - L + 1):t)<=U[i, t])
		@constraint(m, sum(Z[i, k] for k ∈ max(1, t - D + 1):t)<=1-U[i, t])
		if units[i].initial_duration>0
			remaining=units[i].initial_on ? max(0, L-units[i].initial_duration) : max(0, D-units[i].initial_duration)
			t<=remaining && @constraint(m, U[i, t]==Int(units[i].initial_on))
		end
	end
	for (c, s) ∈ enumerate(schedules), t ∈ 1:T

		idx=findall(u->u.cluster==s.cluster, units)
		if diagnose_counts
			@constraint(m, sum(U[i, t] for i ∈ idx)==s.commitment[t]+uplus[c, t]-uminus[c, t])
			@constraint(m, sum(Y[i, t] for i ∈ idx)==s.startup[t]+yplus[c, t]-yminus[c, t])
			@constraint(m, sum(Z[i, t] for i ∈ idx)==s.shutdown[t]+zplus[c, t]-zminus[c, t])
		else
			@constraint(m, sum(U[i, t] for i ∈ idx)==s.commitment[t])
			@constraint(m, sum(Y[i, t] for i ∈ idx)==s.startup[t])
			@constraint(m, sum(Z[i, t] for i ∈ idx)==s.shutdown[t])
		end
		# U/Y/Z are the clustered UC decisions and remain exact.  Continuous
		# dispatch may be exchanged between clusters during physical
		# disaggregation; the system balance below forces those exchanges to
		# net to zero in every period.
		@constraint(m, sum(p[i, t] for i ∈ idx)==s.power[t]+dp[c, t]-dm[c, t])
	end
	for t ∈ 1:T
		@constraint(m, sum(r[:, t])>=sum(s.reserve[t] for s ∈ schedules))
	end
	fixed=size(net.fixed_injection, 2)==0 ? zeros(length(net.buses), T) : net.fixed_injection
	L=size(net.ptdf, 1)
	flows=Matrix{AffExpr}(undef, L, T)
	for t ∈ 1:T
		@constraint(m, sum(p[:, t])+sum(fixed[:, t])+balance_plus[t]-balance_minus[t]==0)
		for l ∈ 1:L
			flows[l, t]=@expression(m,
				sum(net.ptdf[l, bpos[units[i].bus]]*p[i, t] for i ∈ 1:I) +
				sum(net.ptdf[l, b]*fixed[b, t] for b ∈ eachindex(net.buses)))
			@constraint(m, -net.line_limits[l]<=flows[l, t])
			@constraint(m, flows[l, t]<=net.line_limits[l])
		end
	end
	marginal_scale=max(maximum(abs(u.marginal_cost) for u ∈ units; init = 1.0), 1.0)
	countdev=diagnose_counts ? sum(uplus)+sum(uminus)+sum(yplus)+sum(yminus)+sum(zplus)+sum(zminus) : 0
	if diagnose_counts
		# Exact lexicographic diagnosis: never trade many commitment changes
		# against a small MW balance residual.  First find the minimum discrete
		# deviation, lock it, then diagnose the continuous power trajectory.
		@objective(m, Min, countdev)
		optimize!(m)
		first_status=termination_status(m)
		# 计数松弛的 incumbent 不是“最小偏差证书”。只有求解器证明最优后
		# 才能锁定该值；TIME_LIMIT 必须作为证书未完成返回，不能误判不可解群。
		first_ok=first_status in (MOI.OPTIMAL, MOI.LOCALLY_SOLVED)
		first_ok || return UnitDisaggregationResult(; feasible = false,
			feedback = DisaggregationFeedback(; feasible = false, failure_stage = :exact_assignment,
				message = "exact disaggregation count-diagnosis status $first_status"))
		minimum_count_deviation=objective_value(m)
		@constraint(m, countdev<=minimum_count_deviation+tolerance)
	end
	@objective(m, Min,
		1e6*(sum(balance_plus)+sum(balance_minus)) +
		1e3*(sum(dp)+sum(dm)) +
		sum((units[i].marginal_cost/marginal_scale)*p[i, t] for i ∈ 1:I, t ∈ 1:T))
	optimize!(m)
	status=termination_status(m)
	acceptable=status in (MOI.OPTIMAL, MOI.LOCALLY_SOLVED) ||
			   (status==MOI.TIME_LIMIT && has_values(m))
	if !acceptable
		return UnitDisaggregationResult(; feasible = false, feedback = DisaggregationFeedback(;
			feasible = false, failure_stage = :exact_assignment, message = "exact disaggregation status $status"))
	end
	if diagnose_counts
		candidates=NamedTuple[]
		for c ∈ 1:C, t ∈ 1:T, (name, plus, minus, target) ∈
							  ((:commitment, uplus, uminus, schedules[c].commitment[t]),
				(:startup, yplus, yminus, schedules[c].startup[t]),
				(:shutdown, zplus, zminus, schedules[c].shutdown[t]))

			delta=value(plus[c, t])-value(minus[c, t])
			abs(delta)>tolerance && push!(candidates, (magnitude = abs(delta), cluster = schedules[c].cluster,
				period = t, variable = name, direction = delta>0 ? :increase : :decrease,
				target = round(Int, target)))
		end
		if !isempty(candidates)
			total_count_deviation=sum(x.magnitude for x ∈ candidates)
			default_limit=max(6, ceil(Int, 0.01*I*T))
			repair_limit=parse(Float64, get(ENV, "PCM_CLUSTER_MAX_COUNT_REPAIR", string(default_limit)))
			balance_candidate=value.(balance_plus) .- value.(balance_minus)
			# 小规模离散修复先返回候选路径；主调用方随后固定修复后的 U/Y/Z
			# 重解严格连续物理调度。这里的 balance 使用主问题旧风水电注入，
			# 不应在再调度之前要求严格为零。
			if total_count_deviation<=repair_limit
				deviations=Dict((schedules[c].cluster, t)=>value(dp[c, t])-value(dm[c, t])
				for c ∈ eachindex(schedules), t ∈ 1:T
				if abs(value(dp[c, t])-value(dm[c, t]))>tolerance)
				return UnitDisaggregationResult(; feasible = true, diagnostic = true,
					commitment = round.(Int, value.(U)), startup = round.(Int, value.(Y)),
					shutdown = round.(Int, value.(Z)), power = value.(p), reserve = value.(r),
					line_flow = L==0 ? zeros(0, T) : value.(flows),
					feedback = DisaggregationFeedback(; feasible = true, failure_stage = :physical_commitment_repair,
						affected_clusters = unique(x.cluster for x ∈ candidates),
						affected_periods = unique(x.period for x ∈ candidates),
						dispatch_deviation = deviations,
						suggested_cuts = candidates,
						message = "bounded physical commitment repair: total count deviation $(round(total_count_deviation; digits=3))"))
			end
			lead=first(sort(candidates; by = x->(-x.magnitude, x.period, x.cluster, string(x.variable))))
			schedule=only(s for s ∈ schedules if s.cluster==lead.cluster)
			# A valid no-good cut excludes only this proven-infeasible local
			# U/Y/Z tuple.  The diagnostic direction is retained for reporting,
			# but is not imposed as a globally valid one-sided inequality.
			cut=(cluster = lead.cluster, period = lead.period,
				commitment = schedule.commitment[lead.period], startup = schedule.startup[lead.period],
				shutdown = schedule.shutdown[lead.period], reason_variable = lead.variable,
				diagnostic_direction = lead.direction, magnitude = lead.magnitude)
			return UnitDisaggregationResult(; feasible = false, diagnostic = true,
				feedback = DisaggregationFeedback(; feasible = false, failure_stage = :count_trajectory,
					affected_clusters = unique(x.cluster for x ∈ candidates),
					affected_periods = unique(x.period for x ∈ candidates), suggested_cuts = [cut],
					message = "minimum-deviation certificate rejects local U/Y/Z tuple at cluster $(cut.cluster), period $(cut.period); total_count_deviation=$(round(total_count_deviation; digits=3)), max_balance_deviation=$(round(maximum(abs.(balance_candidate); init=0.0); digits=6))"))
		end
	end
	balance_dev=value.(balance_plus) .- value.(balance_minus)
	if maximum(abs.(balance_dev); init = 0.0)>tolerance
		periods=findall(x->abs(x)>tolerance, balance_dev)
		return UnitDisaggregationResult(; feasible = false, diagnostic = true,
			feedback = DisaggregationFeedback(; feasible = false, failure_stage = :power_trajectory,
				affected_periods = periods,
				dispatch_deviation = Dict((0, t)=>balance_dev[t] for t ∈ periods),
				message = "physical fleet cannot follow clustered total-power trajectory"))
	end
	deviations=Dict((schedules[c].cluster, t)=>value(dp[c, t])-value(dm[c, t])
	for c ∈ eachindex(schedules), t ∈ 1:T
	if abs(value(dp[c, t])-value(dm[c, t]))>tolerance)
	UnitDisaggregationResult(; feasible = true, diagnostic = !isempty(deviations), commitment = round.(Int, value.(U)), startup = round.(Int, value.(Y)),
		shutdown = round.(Int, value.(Z)), power = value.(p), reserve = value.(r),
		line_flow = L==0 ? zeros(0, T) : value.(flows),
		feedback = DisaggregationFeedback(; feasible = true,
			failure_stage = isempty(deviations) ? :none : :physical_redispatch,
			affected_clusters = unique(first.(keys(deviations))),
			affected_periods = unique(last.(keys(deviations))),
			dispatch_deviation = deviations,
			message = isempty(deviations) ? "exact cluster-internal disaggregation feasible" :
					  "exact cluster-internal disaggregation feasible after continuous redispatch"))
end

function validate_disaggregation(r, schedules, units; tolerance = 1e-7)
	schedules=schedules isa ClusterSchedule ? [schedules] : schedules
	e=Dict(:commitment=>0.0, :startup=>0.0, :shutdown=>0.0, :power=>0.0, :line=>0.0)
	for s ∈ schedules, t ∈ eachindex(s.commitment)

		idx=findall(u->u.cluster==s.cluster, units)
		e[:commitment]=max(e[:commitment], abs(sum(r.commitment[idx, t])-s.commitment[t]))
		e[:startup]=max(e[:startup], abs(sum(r.startup[idx, t])-s.startup[t]))
		e[:shutdown]=max(e[:shutdown], abs(sum(r.shutdown[idx, t])-s.shutdown[t]))
		e[:power]=max(e[:power], abs(sum(r.power[idx, t])-s.power[t]))
	end
	(valid = e[:commitment]==0&&e[:startup]==0&&e[:shutdown]==0&&e[:power]<=tolerance, errors = e)
end

function run_cluster_disaggregation(clusters, schedules, initial, units, network; optimizer = GLPK.Optimizer, tolerance = 1e-7, max_iterations = 1)
	checks=Dict{Int, TrajectoryCheckResult}()
	assigned=Pair{AnonymousUnitPath, Int}[]
	for c ∈ clusters
		s=only(filter(x->x.cluster==c.id, schedules))
		q=check_cluster_trajectory_feasibility(c, s.commitment, s.startup, s.shutdown, get(initial, c.id, nothing))
		checks[c.id]=q
		q.feasible||return (feasible = false,
			checks = checks,
			result = nothing,
			feedback = DisaggregationFeedback(; feasible = false, failure_stage = :residence_flow, affected_clusters = [c.id],
				affected_periods = [q.conflict_period], suggested_cuts = q.suggested_cuts, message = q.diagnostic_message))
		m=assign_paths_to_physical_units(c, q.paths, units, network)
		m===nothing&&return (feasible = false,
			checks = checks,
			result = nothing,
			feedback = DisaggregationFeedback(; feasible = false, failure_stage = :physical_assignment, affected_clusters = [c.id],
				suggested_cluster_splits = [(cluster = c.id, reason = :incompatible_units)], message = "path assignment infeasible"))
		append!(assigned, [p=>m[p.id] for p ∈ q.paths])
	end
	r=solve_unit_disaggregation(schedules, assigned, units; network_data = network, optimizer = optimizer, tolerance = tolerance)
	(feasible = r.feasible, checks = checks, result = r, feedback = r.feedback)
end
end
