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

	function SCUCModel_decision_variables(
		u::Matrix{VariableRef},
		x::Matrix{VariableRef},
		v::Matrix{VariableRef},
		su₀::Matrix{VariableRef},
		sd₀::Matrix{VariableRef},
		pg₀::Matrix{VariableRef},
		pgₖ::Array{VariableRef, 3},
		sr⁺::Matrix{VariableRef},
		sr⁻::Matrix{VariableRef},
		Δpd::Matrix{VariableRef},
		Δpw::Matrix{VariableRef},
		κ⁺::Matrix{VariableRef},
		κ⁻::Matrix{VariableRef},
		pc⁺::Matrix{VariableRef},
		pc⁻::Matrix{VariableRef},
		qc::Matrix{VariableRef},
		pss_sumchargeenergy::Matrix{VariableRef},
		α::Matrix{VariableRef},
		β::Matrix{VariableRef}
	)
		return SCUCModel_decision_variables(u, x, v, su₀, sd₀, pg₀, pgₖ, sr⁺, sr⁻, Δpd, Δpw, κ⁺, κ⁻, pc⁺, pc⁻, qc, pss_sumchargeenergy, α, β)
	end
end

struct SCUCModel_constraints
	units_minuptime_constr::Union{Missing, Vector{ConstraintRef}}
	units_mindowntime_constr::Union{Missing, Vector{ConstraintRef}}
	units_init_stateslogic_consist_constr::Union{Missing, Vector{ConstraintRef}}
	units_states_consist_constr::Union{Missing, Vector{ConstraintRef}}
	units_init_shutup_cost_constr::Union{Missing, Vector{ConstraintRef}}
	units_init_shutdown_cost_costr::Union{Missing, Vector{ConstraintRef}}
	units_shutup_cost_constr::Union{Missing, Vector{ConstraintRef}}
	units_shutdown_cost_constr::Union{Missing, Vector{ConstraintRef}}
	winds_curt_constr::Union{Missing, Vector{ConstraintRef}}
	loads_curt_const::Union{Missing, Vector{ConstraintRef}}
	units_minpower_constr::Union{Missing, Vector{ConstraintRef}}
	units_maxpower_constr::Union{Missing, Vector{ConstraintRef}}
	sys_upreserve_constr::Union{Missing, Vector{ConstraintRef}}
	sys_down_reserve_constr::Union{Missing, Vector{ConstraintRef}}
	units_upramp_constr::Union{Missing, Vector{ConstraintRef}}
	units_downramp_constr::Union{Missing, Vector{ConstraintRef}}
	units_pwlpower_sum_constr::Union{Missing, Vector{ConstraintRef}}
	units_pwlblock_upbound_constr::Union{Missing, Vector{ConstraintRef}}
	units_pwlblock_dwbound_constr::Union{Missing, Vector{ConstraintRef}}
	balance_constr::Union{Missing, Vector{ConstraintRef}}
	transmissionline_powerflow_upbound_constr::Union{Missing, Vector{ConstraintRef}}
	transmissionline_powerflow_downbound_constr::Union{Missing, Vector{ConstraintRef}}

	function SCUCModel_constraints(
		units_minuptime_constr = missing,
		units_mindowntime_constr = missing,
		units_init_stateslogic_consist_constr = missing,
		units_states_consist_constr = missing,
		units_init_shutup_cost_constr = missing,
		units_init_shutdown_cost_costr = missing,
		units_shutup_cost_constr = missing,
		units_shutdown_cost_constr = missing,
		winds_curt_constr = missing,
		loads_curt_const = missing,
		units_minpower_constr = missing,
		units_maxpower_constr = missing,
		sys_upreserve_constr = missing,
		sys_down_reserve_constr = missing,
		units_upramp_constr = missing,
		units_downramp_constr = missing,
		units_pwlpower_sum_constr = missing,
		units_pwlblock_upbound_constr = missing,
		units_pwlblock_dwbound_constr = missing,
		balance_constr = missing,
		transmissionline_powerflow_upbound_constr = missing,
		transmissionline_powerflow_downbound_constr = missing
	)
		units_minuptime_constr = units_minuptime_constr
		units_mindowntime_constr = units_mindowntime_constr
		units_init_stateslogic_consist_constr = units_init_stateslogic_consist_constr
		units_states_consist_constr = units_states_consist_constr
		units_init_shutup_cost_constr = units_init_shutup_cost_constr
		units_init_shutdown_cost_costr = units_init_shutdown_cost_costr
		units_shutup_cost_constr = units_shutup_cost_constr
		units_shutdown_cost_constr = units_shutdown_cost_constr
		winds_curt_constr = winds_curt_constr
		loads_curt_const = loads_curt_const
		units_minpower_constr = units_minpower_constr
		units_maxpower_constr = units_maxpower_constr
		sys_upreserve_constr = sys_upreserve_constr
		sys_down_reserve_constr = sys_down_reserve_constr
		units_upramp_constr = units_upramp_constr
		units_downramp_constr = units_downramp_constr
		units_pwlpower_sum_constr = units_pwlpower_sum_constr
		units_pwlblock_upbound_constr = units_pwlblock_upbound_constr
		units_pwlblock_dwbound_constr = units_pwlblock_dwbound_constr
		balance_constr = balance_constr
		transmissionline_powerflow_upbound_constr = transmissionline_powerflow_upbound_constr
		transmissionline_powerflow_downbound_constr = transmissionline_powerflow_downbound_constr
		return new(
			units_minuptime_constr,
			units_mindowntime_constr,
			units_init_stateslogic_consist_constr,
			units_states_consist_constr,
			units_init_shutup_cost_constr,
			units_init_shutdown_cost_costr,
			units_shutup_cost_constr,
			units_shutdown_cost_constr,
			winds_curt_constr,
			loads_curt_const,
			units_minpower_constr,
			units_maxpower_constr,
			sys_upreserve_constr,
			sys_down_reserve_constr,
			units_upramp_constr,
			units_downramp_constr,
			units_pwlpower_sum_constr,
			units_pwlblock_upbound_constr,
			units_pwlblock_dwbound_constr,
			balance_constr,
			transmissionline_powerflow_upbound_constr,
			transmissionline_powerflow_downbound_constr
		)
	end
end

struct SCUCModel_objective_function
	objective_function::Union{Missing, AffExpr}

	function SCUCModel_objective_function(objective_function = missing)
		return new(objective_function)
	end
end

struct SCUC_Model
	model::Union{Missing, JuMP.Model}
	decision_variables::SCUCModel_decision_variables
	objective_function::SCUCModel_objective_function
	constraints::SCUCModel_constraints

	function SCUC_Model(decision_variables::SCUCModel_decision_variables, objective_function::SCUCModel_objective_function, constraints::SCUCModel_constraints, model = missing)
		return new(model, decision_variables, objective_function, constraints)
	end
end
