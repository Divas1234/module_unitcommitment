include(joinpath(pwd(), "src", "environment_config.jl"))
include(joinpath(pwd(), "src", "unitcommitment_model_modules", "SUCuccommitmentmodel.jl"))

"""
    bd_dual_subfunction(NT, NB, NG, ND, NC, ND2, NS, NW, units, config_param)

This function defines the dual of the subproblem for the Bender's decomposition algorithm.

# Arguments
- `NT::Int64`: Number of time periods.
- `NB::Int64`: Number of buses.
- `NG::Int64`: Number of generators.
- `ND::Int64`: Number of loads.
- `NC::Int64`: Number of storage units.
- `ND2::Int64`: Number of data centers.
- `NS::Int64`: Number of scenarios.
- `NW::Int64`: Number of wind power plants.
- `units::unit`: Unit data structure.
- `config_param::config`: Configuration parameters.

# Returns
- `dual_subproblem::Model`: The JuMP model for the dual subproblem.
"""
function bd_dual_subfunction(
    NT::Int64,
    NB::Int64,
    NG::Int64,
    ND::Int64,
    NC::Int64,
    ND2::Int64,
    NS::Int64,
    NW::Int64,
    units::unit,
    config_param::config
)::Model
    # Create the dual subproblem model
    dual_subproblem = Model(Gurobi.Optimizer)
    
    # Define dual variables (one for each primal constraint)
    # Power balance dual variables (λ)
    @variable(dual_subproblem, λ[1:NT, 1:NS])  # Dual variables for power balance constraints
    
    # Transmission constraints dual variables (μ)
    @variable(dual_subproblem, μ_plus[1:NL, 1:NT, 1:NS])  # Line flow upper bound
    @variable(dual_subproblem, μ_minus[1:NL, 1:NT, 1:NS]) # Line flow lower bound
    
    # Generator limits dual variables (π)
    @variable(dual_subproblem, π_max[1:NG, 1:NT, 1:NS])  # Maximum generation
    @variable(dual_subproblem, π_min[1:NG, 1:NT, 1:NS])  # Minimum generation
    
    # Ramp constraints dual variables (ρ)
    @variable(dual_subproblem, ρ_up[1:NG, 1:NT, 1:NS])    # Ramp up
    @variable(dual_subproblem, ρ_down[1:NG, 1:NT, 1:NS])  # Ramp down
    
    # Reserve requirement dual variables (γ)
    @variable(dual_subproblem, γ_plus[1:NT, 1:NS])  # Upward reserve
    @variable(dual_subproblem, γ_minus[1:NT, 1:NS]) # Downward reserve
    
    # Storage constraints dual variables (σ)
    @variable(dual_subproblem, σ_soc[1:NC, 1:NT, 1:NS])  # State of charge
    @variable(dual_subproblem, σ_ch[1:NC, 1:NT, 1:NS])   # Charging limit
    @variable(dual_subproblem, σ_dis[1:NC, 1:NT, 1:NS])  # Discharging limit
    
    # Set objective (negative of primal constraints RHS)
    @objective(dual_subproblem, Max,
        sum(sum(λ[t,s] * (sum(loads.pd[d,t] for d in 1:ND) - 
            sum(winds.pw[w,t,s] for w in 1:NW)) for t in 1:NT) for s in 1:NS) +
        sum(sum(sum(μ_plus[l,t,s] * lines.capacity[l] for l in 1:NL) for t in 1:NT) for s in 1:NS) +
        sum(sum(sum(μ_minus[l,t,s] * lines.capacity[l] for l in 1:NL) for t in 1:NT) for s in 1:NS) +
        sum(sum(sum(π_max[g,t,s] * units.pmax[g] for g in 1:NG) for t in 1:NT) for s in 1:NS)
    )
    
    # Add dual constraints (from primal variables)
    # Generator output variables constraints
    @constraint(dual_subproblem, gen_dual[g=1:NG, t=1:NT, s=1:NS],
        λ[t,s] + π_max[g,t,s] - π_min[g,t,s] + 
        (t < NT ? ρ_up[g,t,s] - ρ_down[g,t+1,s] : 0) -
        (t > 1 ? ρ_up[g,t-1,s] - ρ_down[g,t,s] : 0) <= 
        scenarios_prob * units.cost[g]
    )
    
    # Reserve variables constraints
    @constraint(dual_subproblem, reserve_up_dual[g=1:NG, t=1:NT, s=1:NS],
        γ_plus[t,s] <= scenarios_prob * config_param.cost_sr⁺
    )
    
    @constraint(dual_subproblem, reserve_down_dual[g=1:NG, t=1:NT, s=1:NS],
        γ_minus[t,s] <= scenarios_prob * config_param.cost_sr⁻
    )
    
    # Storage dual constraints
    @constraint(dual_subproblem, storage_dual[c=1:NC, t=1:NT, s=1:NS],
        σ_soc[c,t,s] + (t < NT ? σ_soc[c,t+1,s] : 0) <= 0
    )
    
    # Non-negativity constraints for dual variables
    @constraint(dual_subproblem, [l=1:NL, t=1:NT, s=1:NS], μ_plus[l,t,s] >= 0)
    @constraint(dual_subproblem, [l=1:NL, t=1:NT, s=1:NS], μ_minus[l,t,s] >= 0)
    @constraint(dual_subproblem, [g=1:NG, t=1:NT, s=1:NS], π_max[g,t,s] >= 0)
    @constraint(dual_subproblem, [g=1:NG, t=1:NT, s=1:NS], π_min[g,t,s] >= 0)
    @constraint(dual_subproblem, [g=1:NG, t=1:NT, s=1:NS], ρ_up[g,t,s] >= 0)
    @constraint(dual_subproblem, [g=1:NG, t=1:NT, s=1:NS], ρ_down[g,t,s] >= 0)
    @constraint(dual_subproblem, [t=1:NT, s=1:NS], γ_plus[t,s] >= 0)
    @constraint(dual_subproblem, [t=1:NT, s=1:NS], γ_minus[t,s] >= 0)
    
    return dual_subproblem
end