include("mainfunc.jl")
scuc_masterproblem, scuc_subproblem, master_re_constr_sets, sub_re_constr_sets, config_param, units, lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main();

batch_scuc_subproblem_dic =
	(config_param.is_ConsiderMultiCUTs == 1) ?
	get_batch_scuc_subproblems_for_scenario(scuc_subproblem::Model, winds::wind, config_param::config) :
	OrderedDict(1 => scuc_subproblem)

# DEBUG - benderdecomposition_module
# bd_framework(scuc_masterproblem::Model, batch_scuc_subproblem_dic::OrderedDict, master_re_constr_sets, sub_re_constr_sets, winds, config_param)
#DEBUG - TODO -  缺省定义
scuc_masterproblem = Model(Gurobi.Optimizer)
	set_silent(scuc_masterproblem)

	# set_silent(scuc_masterproblem)
	# --- Define Variables ---
	# Define decision variables for the optimization model
	scuc_masterproblem, x, u, v, su₀, sd₀, θ = define_masterproblem_decision_variables!(
		scuc_masterproblem::Model, NT, NG, ND, NC, ND2, NS, NW, config_param)

	pg₀ = Matrix{VariableRef}(undef, 0, 0)
	pgₖ = Array{VariableRef, 3}(undef, 0, 0, 0)
	sr⁺ = Matrix{VariableRef}(undef, 0, 0)
	sr⁻ = Matrix{VariableRef}(undef, 0, 0)
	Δpd = Matrix{VariableRef}(undef, 0, 0)
	Δpw = Matrix{VariableRef}(undef, 0, 0)
	κ⁺ = Matrix{VariableRef}(undef, 0, 0)
	κ⁻ = Matrix{VariableRef}(undef, 0, 0)
	pc⁺ = Matrix{VariableRef}(undef, 0, 0)
	pc⁻ = Matrix{VariableRef}(undef, 0, 0)
	qc = Matrix{VariableRef}(undef, 0, 0)
	pss_sumchargeenergy = Matrix{VariableRef}(undef, 0, 0)
	α = Matrix{VariableRef}(undef, 0, 0)
	β = Matrix{VariableRef}(undef, 0, 0)
	# Ensure SCUCModel_decision_variables is defined or imported
	master_vars = SCUCModel_decision_variables_1(u, x, v, su₀, sd₀, pg₀, pgₖ, sr⁺, sr⁻, Δpd, Δpw, κ⁺, κ⁻, pc⁺, pc⁻, qc, pss_sumchargeenergy, α, β, θ)

x

struct SCUCModel_decision_variables_1
	u::Matrix{VariableRef}
	x::Matrix{VariableRef}
	v::Matrix{VariableRef}
	su₀::Matrix{VariableRef}
	sd₀::Matrix{VariableRef}
	pg₀::Matrix{VariableRef}
	pgₖ::Array{VariableRef, 3}
	sr⁺::Matrix{VariableRef}
	sr⁻::Matrix{VariableRef}
	Δpd::Matrix{VariableRef}
	Δpw::Matrix{VariableRef}
	κ⁺::Matrix{VariableRef}
	κ⁻::Matrix{VariableRef}
	pc⁺::Matrix{VariableRef}
	pc⁻::Matrix{VariableRef}
	qc::Matrix{VariableRef}
	pss_sumchargeenergy::Matrix{VariableRef}
	α::Matrix{VariableRef}
	β::Matrix{VariableRef}
	θ::Any #add for debug
end

struct SCUCModel_constraints
	units_minuptime_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_mindowntime_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_init_stateslogic_consist_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_states_consist_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_init_shutup_cost_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_init_shutdown_cost_costr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_shutup_cost_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_shutdown_cost_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	winds_curt_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	loads_curt_const::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_minpower_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_maxpower_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	sys_upreserve_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	sys_down_reserve_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_upramp_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_downramp_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_pwlpower_sum_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_pwlblock_upbound_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	units_pwlblock_dwbound_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	balance_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	transmissionline_powerflow_upbound_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
	transmissionline_powerflow_downbound_constr::Vector{ConstraintRef} = Vector{ConstraintRef}(undef, 0, 0)
end