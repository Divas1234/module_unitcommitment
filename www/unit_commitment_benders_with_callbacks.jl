using JuMP, Gurobi

# Problem data
num_units = 3
num_periods = 24
demand = [100.0 + 50 * sin(π * t / 12) for t in 1:num_periods]  # Sinusoidal demand
p_min = [20.0, 15.0, 10.0]  # Minimum power (MW)
p_max = [100.0, 80.0, 60.0]  # Maximum power (MW)
c_var = [20.0, 25.0, 30.0]  # Variable cost ($/MWh)
c_fixed = [1000.0, 800.0, 600.0]  # Fixed cost ($/h)
c_startup = [2000.0, 1500.0, 1000.0]  # Startup cost ($)
ramp_rate = [50.0, 40.0, 30.0]  # Ramp rate (MW/h)

# Callback function for Benders cuts
function benders_callback(cb_data)
    # Get current master solution
    u_val = callback_value.(cb_data, u)
    η_val = callback_value(cb_data, η)

    # Subproblem
    sub = Model(Gurobi.Optimizer)
    set_optimizer_attribute(sub, "OutputFlag", 0)
    @variable(sub, p[1:num_units, 1:num_periods] >= 0)
    @objective(sub, Min, sum(c_var[i] * p[i, t] for i in 1:num_units, t in 1:num_periods))
    @constraint(sub, demand_con[t=1:num_periods], sum(p[i, t] for i in 1:num_units) == demand[t])
    @constraint(sub, gen_min[i=1:num_units, t=1:num_periods], p[i, t] >= p_min[i] * u_val[i, t])
    @constraint(sub, gen_max[i=1:num_units, t=1:num_periods], p[i, t] <= p_max[i] * u_val[i, t])
    @constraint(sub, ramp_up[i=1:num_units, t=2:num_periods], p[i, t] - p[i, t-1] <= ramp_rate[i])
    @constraint(sub, ramp_down[i=1:num_units, t=2:num_periods], p[i, t-1] - p[i, t] <= ramp_rate[i])

    optimize!(sub)
    status = termination_status(sub)

    if status == MOI.OPTIMAL
        # Optimality cut
        π = dual.(sub[:demand_con])
        μ_min = dual.(sub[:gen_min])
        μ_max = dual.(sub[:gen_max])
        ρ_up = dual.(sub[:ramp_up])
        ρ_down = dual.(sub[:ramp_down])

        # Construct optimality cut
        cut = sum(π[t] * demand[t] for t in 1:num_periods) +
              sum(μ_min[i, t] * p_min[i] * u[i, t] for i in 1:num_units, t in 1:num_periods) +
              sum(μ_max[i, t] * (-p_max[i] * u[i, t]) for i in 1:num_units, t in 1:num_periods) +
              sum(ρ_up[i, t] * (p[i, t] - p[i, t-1]) for i in 1:num_units, t in 2:num_periods) +
              sum(ρ_down[i, t] * (p[i, t-1] - p[i, t]) for i in 1:num_units, t in 2:num_periods)
        add_lazy_constraint(cb_data, η >= cut)
    else
        # Feasibility subproblem
        feas_sub = Model(Gurobi.Optimizer)
        set_optimizer_attribute(feas_sub, "OutputFlag", 0)
        @variable(feas_sub, p[1:num_units, 1:num_periods] >= 0)
        @variable(feas_sub, s_pos[1:num_periods] >= 0)
        @variable(feas_sub, s_neg[1:num_periods] >= 0)
        @objective(feas_sub, Min, sum(s_pos[t] + s_neg[t] for t in 1:num_periods))
        @constraint(feas_sub, demand_con[t=1:num_periods], sum(p[i, t] for i in 1:num_units) + s_pos[t] - s_neg[t] == demand[t])
        @constraint(feas_sub, gen_min[i=1:num_units, t=1:num_periods], p[i, t] >= p_min[i] * u_val[i, t])
        @constraint(feas_sub, gen_max[i=1:num_units, t=1:num_periods], p[i, t] <= p_max[i] * u_val[i, t])
        @constraint(feas_sub, ramp_up[i=1:num_units, t=2:num_periods], p[i, t] - p[i, t-1] <= ramp_rate[i])
        @constraint(feas_sub, ramp_down[i=1:num_units, t=2:num_periods], p[i, t-1] - p[i, t] <= ramp_rate[i])

        optimize!(feas_sub)
        if termination_status(feas_sub) == MOI.OPTIMAL
            π = dual.(feas_sub[:demand_con])
            μ_min = dual.(feas_sub[:gen_min])
            μ_max = dual.(feas_sub[:gen_max])
            ρ_up = dual.(feas_sub[:ramp_up])
            ρ_down = dual.(feas_sub[:ramp_down])

            # Construct feasibility cut
            cut = sum(π[t] * demand[t] for t in 1:num_periods) +
                  sum(μ_min[i, t] * p_min[i] * u[i, t] for i in 1:num_units, t in 1:num_periods) +
                  sum(μ_max[i, t] * (-p_max[i] * u[i, t]) for i in 1:num_units, t in 1:num_periods) +
                  sum(ρ_up[i, t] * (p[i, t] - p[i, t-1]) for i in 1:num_units, t in 2:num_periods) +
                  sum(ρ_down[i, t] * (p[i, t-1] - p[i, t]) for i in 1:num_units, t in 2:num_periods)
            add_lazy_constraint(cb_data, cut <= 0)
        else
            error("Feasibility subproblem failed")
        end
    end
end

# Master problem
master = Model(Gurobi.Optimizer)
set_optimizer_attribute(master, "OutputFlag", 1)  # Enable output for debugging
@variable(master, u[1:num_units, 1:num_periods], Bin)  # Commitment
@variable(master, v[1:num_units, 1:num_periods], Bin)  # Startup
@variable(master, w[1:num_units, 1:num_periods], Bin)  # Shutdown
@variable(master, η >= 0)  # Subproblem cost estimate
@objective(master, Min, sum(c_fixed[i] * u[i, t] + c_startup[i] * v[i, t] for i in 1:num_units, t in 1:num_periods) + η)
@constraint(master, logic[i=1:num_units, t=2:num_periods], v[i, t] - w[i, t] == u[i, t] - u[i, t-1])
@constraint(master, initial_logic[i=1:num_units], v[i, 1] - w[i, 1] == u[i, 1])  # Assume initial state off

# Register callback
MOI.set(master, MOI.LazyConstraintCallback(), benders_callback)

# Solve
optimize!(master)
if termination_status(master) == MOI.OPTIMAL
    println("Optimal Objective: ", objective_value(master))
    println("Commitment Schedule: ")
    for i in 1:num_units
        println("Unit $i: ", value.(u[i, :]))
    end
else
    println("Optimization failed with status: ", termination_status(master))
end