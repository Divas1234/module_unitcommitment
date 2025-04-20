using JuMP

struct SCUCModel_decision_variables
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
	θ::Any  # for debugging or flexibility
end

function build_decision_variables(; kwargs...)
	fields = fieldnames(SCUCModel_decision_variables)
	defaults = Dict{Symbol, Any}()

	for f in fields
		if f == :pgₖ
			defaults[f] = Array{VariableRef, 3}(undef, 0, 0, 0)
		elseif f == :θ
			defaults[f] = nothing
		else
			defaults[f] = Matrix{VariableRef}(undef, 0, 0)
		end
	end

	# Merge user input
	for (k, v) in kwargs
		if haskey(defaults, k)
			defaults[k] = v
		else
			error("Invalid field name: $k")
		end
	end

	return SCUCModel_decision_variables(
		defaults[:u], defaults[:x], defaults[:v], defaults[:su₀], defaults[:sd₀], defaults[:pg₀],
		defaults[:pgₖ], defaults[:sr⁺], defaults[:sr⁻], defaults[:Δpd], defaults[:Δpw],
		defaults[:κ⁺], defaults[:κ⁻], defaults[:pc⁺], defaults[:pc⁻], defaults[:qc],
		defaults[:pss_sumchargeenergy], defaults[:α], defaults[:β], defaults[:θ]
	)
end

struct SCUCModel_constraints
	units_minuptime_constr::Vector{ConstraintRef}
	units_mindowntime_constr::Vector{ConstraintRef}
	units_init_stateslogic_consist_constr::Vector{ConstraintRef}
	units_states_consist_constr::Vector{ConstraintRef}
	units_init_shutup_cost_constr::Vector{ConstraintRef}
	units_init_shutdown_cost_constr::Vector{ConstraintRef}
	units_shutup_cost_constr::Vector{ConstraintRef}
	units_shutdown_cost_constr::Vector{ConstraintRef}
	winds_curt_constr::Vector{ConstraintRef}
	loads_curt_const::Vector{ConstraintRef}
	units_minpower_constr::Vector{ConstraintRef}
	units_maxpower_constr::Vector{ConstraintRef}
	sys_upreserve_constr::Vector{ConstraintRef}
	sys_down_reserve_constr::Vector{ConstraintRef}
	units_upramp_constr::Vector{ConstraintRef}
	units_downramp_constr::Vector{ConstraintRef}
	units_pwlpower_sum_constr::Vector{ConstraintRef}
	units_pwlblock_upbound_constr::Vector{ConstraintRef}
	units_pwlblock_dwbound_constr::Vector{ConstraintRef}
	balance_constr::Vector{ConstraintRef}
	transmissionline_powerflow_upbound_constr::Vector{ConstraintRef}
	transmissionline_powerflow_downbound_constr::Vector{ConstraintRef}
end

function build_constraints(; kwargs...)
	fields = fieldnames(SCUCModel_constraints)
	defaults = Dict{Symbol, Vector{ConstraintRef}}()

	for f in fields
		defaults[f] = ConstraintRef[]
	end

	for (k, v) in kwargs
		if haskey(defaults, k)
			defaults[k] = v
		else
			error("Invalid field name: $k")
		end
	end

	return SCUCModel_constraints(
		defaults[:units_minuptime_constr],
		defaults[:units_mindowntime_constr],
		defaults[:units_init_stateslogic_consist_constr],
		defaults[:units_states_consist_constr],
		defaults[:units_init_shutup_cost_constr],
		defaults[:units_init_shutdown_cost_constr],  # corrected typo here
		defaults[:units_shutup_cost_constr],
		defaults[:units_shutdown_cost_constr],
		defaults[:winds_curt_constr],
		defaults[:loads_curt_const],
		defaults[:units_minpower_constr],
		defaults[:units_maxpower_constr],
		defaults[:sys_upreserve_constr],
		defaults[:sys_down_reserve_constr],
		defaults[:units_upramp_constr],
		defaults[:units_downramp_constr],
		defaults[:units_pwlpower_sum_constr],
		defaults[:units_pwlblock_upbound_constr],
		defaults[:units_pwlblock_dwbound_constr],
		defaults[:balance_constr],
		defaults[:transmissionline_powerflow_upbound_constr],
		defaults[:transmissionline_powerflow_downbound_constr]
	)
end

struct SCUCModel_reformat_constraints
	_equal_to::Vector{ConstraintRef}
	_greater_than::Vector{ConstraintRef}
	_smaller_than::Vector{ConstraintRef}
end

struct SCUCModel_objective_function
	objective_function::Union{Missing, AffExpr}
end

struct SCUC_Model
	model::Union{Missing, JuMP.Model}
	decision_variables::SCUCModel_decision_variables
	objective_function::SCUCModel_objective_function
	constraints::SCUCModel_constraints
	reformated_constraints::SCUCModel_reformat_constraints
end
