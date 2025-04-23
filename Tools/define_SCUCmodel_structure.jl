using JuMP

"""
	SCUCModel_decision_variables

Structure containing all decision variables for the Security Constrained Unit Commitment (SCUC) model.

Fields:
- `u`: Binary commitment status variables (generators × time periods)
- `x`: Startup variables (generators × time periods)
- `v`: Shutdown variables (generators × time periods)
- `su₀`: Initial startup cost variables (generators × time periods)
- `sd₀`: Initial shutdown cost variables (generators × time periods)
- `pg₀`: Base power generation variables (generators × time periods)
- `pgₖ`: Piecewise linear power generation segments (generators × segments × time periods)
- `sr⁺`: Upward spinning reserve variables (generators × time periods)
- `sr⁻`: Downward spinning reserve variables (generators × time periods)
- `Δpd`: Load curtailment variables (loads × time periods)
- `Δpw`: Wind curtailment variables (wind generators × time periods)
- `κ⁺`: Positive slack variables (nodes × time periods)
- `κ⁻`: Negative slack variables (nodes × time periods)
- `pc⁺`: Storage charging power variables (storage units × time periods)
- `pc⁻`: Storage discharging power variables (storage units × time periods)
- `qc`: Storage state of charge variables (storage units × time periods)
- `pss_sumchargeenergy`: Cumulative energy charged to storage (storage units × time periods)
- `α`: Auxiliary variables for linearization (purpose-specific)
- `β`: Auxiliary variables for linearization (purpose-specific)
- `θ`: Flexible field for debugging or additional variables
"""
mutable struct SCUCModel_decision_variables{T <: VariableRef} # Decision variables for SCUC model
    u::Matrix{T}                # Commitment status (binary) (generators × time periods)
    x::Matrix{T}                # Startup indicator (generators × time periods)
    v::Matrix{T}                # Shutdown indicator (generators × time periods)
    su₀::Matrix{T}              # Initial startup costs
    sd₀::Matrix{T}              # Initial shutdown costs
    pg₀::Matrix{T}              # Base power generation
    pgₖ::Array{T,3}            # Piecewise linear power generation segments
    sr⁺::Matrix{T}              # Upward spinning reserve
    sr⁻::Matrix{T}              # Downward spinning reserve
    Δpd::Matrix{T}              # Load curtailment
    Δpw::Matrix{T}              # Wind curtailment
    κ⁺::Matrix{T}               # Positive slack variables
    κ⁻::Matrix{T}               # Negative slack variables
    pc⁺::Matrix{T}              # Storage charging power
    pc⁻::Matrix{T}              # Storage discharging power
    qc::Matrix{T}               # Storage state of charge
    pss_sumchargeenergy::Matrix{T} # Cumulative energy charged to storage
    α::Matrix{T}                # Auxiliary variable for linearization
    β::Matrix{T}                # Auxiliary variable for linearization
    θ::Any                                # Flexible field for debugging or additional variables. Consider replacing `Any` with a concrete type or a type parameter.

    function SCUCModel_decision_variables(u::Matrix{T}, x::Matrix{T}, v::Matrix{T}, su₀::Matrix{T}, sd₀::Matrix{T}, pg₀::Matrix{T},
        pgₖ::Array{T,3}, sr⁺::Matrix{T}, sr⁻::Matrix{T}, Δpd::Matrix{T}, Δpw::Matrix{T},
        κ⁺::Matrix{T}, κ⁻::Matrix{T}, pc⁺::Matrix{T}, pc⁻::Matrix{T}, qc::Matrix{T},
        pss_sumchargeenergy::Matrix{T}, α::Matrix{T}, β::Matrix{T}, θ::Any) where {T <: VariableRef}

        new{T}(u, x, v, su₀, sd₀, pg₀, pgₖ, sr⁺, sr⁻, Δpd, Δpw, κ⁺, κ⁻, pc⁺, pc⁻, qc, pss_sumchargeenergy, α, β, θ)
    end
end

"""
	build_decision_variables(; kwargs...)

Constructs an SCUCModel_decision_variables object with the provided variables.
Initializes empty matrices/arrays for any fields not explicitly provided.

# Arguments
- `kwargs...`: Named arguments corresponding to fields in SCUCModel_decision_variables

# Returns
- An initialized SCUCModel_decision_variables object

# Example
# ```julia
# vars = build_decision_variables(u = rand(0:1, 5, 24))
# ```
"""
function build_decision_variables(; kwargs...)
    fields = fieldnames(SCUCModel_decision_variables)
    defaults = Dict{Symbol,Any}()

    # Initialize default empty containers for each field
    for f in fields
        if f == :pgₖ
            defaults[f] = Array{VariableRef,3}(undef, 0, 0, 0)
        elseif f == :θ
            defaults[f] = nothing
        else
            defaults[f] = Matrix{VariableRef}(undef, 0, 0)
        end
    end

    # Override defaults with user-provided values
    for (k, v) in kwargs
        if haskey(defaults, k)
            if haskey(defaults, k)
                defaults[k] = v
            else
                error("Invalid field name: $k. Valid fields are: $(join(string.(fields), ", "))")
            end
        end
    end

    # Construct and return the struct
    return SCUCModel_decision_variables(
        defaults[:u], defaults[:x], defaults[:v], defaults[:su₀], defaults[:sd₀], defaults[:pg₀],
        defaults[:pgₖ], defaults[:sr⁺], defaults[:sr⁻], defaults[:Δpd], defaults[:Δpw],
        defaults[:κ⁺], defaults[:κ⁻], defaults[:pc⁺], defaults[:pc⁻], defaults[:qc],
        defaults[:pss_sumchargeenergy], defaults[:α], defaults[:β], defaults[:θ]
    )
end

"""
	SCUCModel_constraints

Structure containing all constraints for the SCUC model, organized by constraint type.

Each field is a vector of JuMP ConstraintRef objects representing a specific type of constraint
in the optimization model.
"""
mutable struct SCUCModel_constraints # Constraints for SCUC model
    units_minuptime_constr::Vector{ConstraintRef}                    # Minimum up time constraints
    units_mindowntime_constr::Vector{ConstraintRef}                  # Minimum down time constraints
    units_init_stateslogic_consist_constr::Vector{ConstraintRef}     # Initial state logic consistency
    units_states_consist_constr::Vector{ConstraintRef}               # State consistency constraints
    units_init_shutup_cost_constr::Vector{ConstraintRef}             # Initial startup cost constraints
    units_init_shutdown_cost_constr::Vector{ConstraintRef}           # Initial shutdown cost constraints
    units_shutup_cost_constr::Vector{ConstraintRef}                  # Startup cost constraints
    units_shutdown_cost_constr::Vector{ConstraintRef}                # Shutdown cost constraints
    winds_curt_constr::Vector{ConstraintRef}                         # Wind curtailment constraints
    loads_curt_const::Vector{ConstraintRef}                          # Load curtailment constraints
    units_minpower_constr::Vector{ConstraintRef}                     # Minimum power output constraints
    units_maxpower_constr::Vector{ConstraintRef}                     # Maximum power output constraints
    sys_upreserve_constr::Vector{ConstraintRef}                      # System upward reserve constraints
    sys_down_reserve_constr::Vector{ConstraintRef}                   # System downward reserve constraints
    units_upramp_constr::Vector{ConstraintRef}                       # Upward ramping constraints
    units_downramp_constr::Vector{ConstraintRef}                     # Downward ramping constraints
    units_pwlpower_sum_constr::Vector{ConstraintRef}                 # Piecewise linear power sum constraints
    units_pwlblock_upbound_constr::Vector{ConstraintRef}             # Upper bounds for piecewise blocks
    units_pwlblock_dwbound_constr::Vector{ConstraintRef}             # Lower bounds for piecewise blocks
    balance_constr::Vector{ConstraintRef}                            # Power balance constraints
    transmissionline_powerflow_upbound_constr::Vector{ConstraintRef} # Transmission line upper limits
    transmissionline_powerflow_downbound_constr::Vector{ConstraintRef} # Transmission line lower limits
end

"""
	build_constraints(; kwargs...)

Constructs an SCUCModel_constraints object with the provided constraint vectors.
Initializes empty vectors for any constraint types not explicitly provided.

# Arguments
- `kwargs...`: Named arguments corresponding to fields in SCUCModel_constraints

# Returns
- An initialized SCUCModel_constraints object
"""
function build_constraints(; kwargs...)
    fields = fieldnames(SCUCModel_constraints)
    defaults = Dict{Symbol,Vector{ConstraintRef}}()

    # Initialize empty constraint vectors for each field
    for f in fields
        defaults[f] = ConstraintRef[]
    end

    # Override defaults with user-provided values
    for (k, v) in kwargs
        if haskey(defaults, k)
            defaults[k] = v
        else
            error("Invalid field name: $k. Valid fields are: $(join(string.(fields), ", "))")
        end
    end

    # Construct and return the struct
    return SCUCModel_constraints(
        defaults[:units_minuptime_constr],
        defaults[:units_mindowntime_constr],
        defaults[:units_init_stateslogic_consist_constr],
        defaults[:units_states_consist_constr],
        defaults[:units_init_shutup_cost_constr],
        defaults[:units_init_shutdown_cost_constr],
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

"""
	SCUCModel_reformat_constraints

Structure for organizing constraints by their mathematical form (equality, inequality).
This allows for easier manipulation and analysis of the constraint structure.

Fields:
- `_equal_to`: Constraints of the form a = b
- `_greater_than`: Constraints of the form a ≥ b
- `_smaller_than`: Constraints of the form a ≤ b
"""
mutable struct SCUCModel_reformat_constraints
    _equal_to::Dict{Symbol,Any}          # Equality constraints (a = b)
    _greater_than::Dict{Symbol,Any}      # Greater-than constraints (a ≥ b)
    _smaller_than::Dict{Symbol,Any}      # Less-than constraints (a ≤ b)
end

"""
	SCUCModel_objective_function

Structure containing the objective function for the SCUC model.

Fields:
- `objective_function`: The JuMP expression representing the objective function
"""
mutable struct SCUCModel_objective_function
    objective_function::Union{Missing,AffExpr}  # Objective function expression
end

"""
	SCUC_Model

Main structure for the Security Constrained Unit Commitment model.
Contains the JuMP model, all decision variables, constraints, and the objective function.

Fields:
- `model`: The JuMP optimization model
- `decision_variables`: All decision variables used in the model
- `objective_function`: The objective function to be minimized/maximized
- `constraints`: All constraints organized by type
- `reformated_constraints`: Constraints reorganized by mathematical form
"""
mutable struct SCUC_Model
    model::Union{Missing,JuMP.Model}                       # JuMP optimization model
    decision_variables::SCUCModel_decision_variables        # All decision variables
    objective_function::SCUCModel_objective_function        # Objective function
    constraints::SCUCModel_constraints                      # Constraints by type
    reformated_constraints::SCUCModel_reformat_constraints  # Constraints by mathematical form
end
