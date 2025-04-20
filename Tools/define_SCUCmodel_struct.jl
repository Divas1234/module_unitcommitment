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
	θ::Any #add for debug

	# function SCUCModel_decision_variables(
	# 		u = Matrix{VariableRef}(undef, 0, 0),
	# 		x = Matrix{VariableRef}(undef, 0, 0),
	# 		v = Matrix{VariableRef}(undef, 0, 0),
	# 		su₀ = Matrix{VariableRef}(undef, 0, 0),
	# 		sd₀ = Matrix{VariableRef}(undef, 0, 0),
	# 		pg₀ = Matrix{VariableRef}(undef, 0, 0),
	# 		pgₖ = Array{VariableRef, 3}(undef, 0, 0, 0),
	# 		sr⁺ = Matrix{VariableRef}(undef, 0, 0),
	# 		sr⁻ = Matrix{VariableRef}(undef, 0, 0),
	# 		Δpd = Matrix{VariableRef}(undef, 0, 0),
	# 		Δpw = Matrix{VariableRef}(undef, 0, 0),
	# 		κ⁺ = Matrix{VariableRef}(undef, 0, 0),
	# 		κ⁻ = Matrix{VariableRef}(undef, 0, 0),
	# 		pc⁺ = Matrix{VariableRef}(undef, 0, 0),
	# 		pc⁻ = Matrix{VariableRef}(undef, 0, 0),
	# 		qc = Matrix{VariableRef}(undef, 0, 0),
	# 		pss_sumchargeenergy = Matrix{VariableRef}(undef, 0, 0),
	# 		α = Matrix{VariableRef}(undef, 0, 0),
	# 		β = Matrix{VariableRef}(undef, 0, 0)
	# )
	# 	# Constructor for SCUCModel_decision_variables
	# 	new(u, x, v, su₀, sd₀, pg₀, pgₖ, sr⁺, sr⁻, Δpd, Δpw, κ⁺, κ⁻, pc⁺, pc⁻, qc, pss_sumchargeenergy, α, β)
	# end
end

struct SCUCModel_constraints
	units_minuptime_constr::Vector{ConstraintRef}
	units_mindowntime_constr::Vector{ConstraintRef}
	units_init_stateslogic_consist_constr::Vector{ConstraintRef}
	units_states_consist_constr::Vector{ConstraintRef}
	units_init_shutup_cost_constr::Vector{ConstraintRef}
	units_init_shutdown_cost_costr::Vector{ConstraintRef}
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
