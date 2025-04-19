include(joinpath(pwd(), "src", "environment_config.jl"));
include(joinpath(pwd(), "src", "renewableresource_modules", "stochasticsimulation.jl"));
include(joinpath(pwd(), "src", "read_inputdata_modules", "readdatas.jl"));
include(joinpath(pwd(), "src", "unitcommitment_model_modules", "SUCuccommitmentmodel.jl"));

include("define_masterproblem.jl")
include("define_subproblem.jl")
include("benderdecomposition_module.jl")
UnitsFreqParam, WindsFreqParam, StrogeData, DataGen, GenCost, DataBranch, LoadCurve, DataLoad, datacentra_Data = readxlssheet()

# Form input data for the model
config_param, units, lines, loads, psses, NB, NG, NL, ND, NT, NC, ND2, DataCentras = forminputdata(
	DataGen, DataBranch, DataLoad, LoadCurve, GenCost, UnitsFreqParam, StrogeData, datacentra_Data)

# Generate wind scenarios
winds, NW = genscenario(WindsFreqParam, 1)

# Apply boundary conditions
# boundrycondition(NB, NL, NG, NT, ND, units, loads, lines, winds, psses, config_param)

# Run the SUC-SCUC model
# Define scenario probability (assuming equal probability)
scenarios_prob = 1.0 / winds.scenarios_nums
@show NS = Int64(winds.scenarios_nums)
refcost, eachslope = linearizationfuelcurve(units, NG)
# println("this is the sub function of the bender decomposition process")
# Δp_contingency = define_contingency_size(units, NG)
scuc_subproblem = Model(Gurobi.Optimizer)
set_silent(scuc_subproblem)
# set_silent(scuc_subproblem)
# --- Define Variables ---
# Define decision variables for the optimization model
define_subproblem_decision_variables!(
	scuc_subproblem::Model, NT, NG, ND, NC, ND2, NS, NW, config_param
)

# --- Set Objective ---
# Set the objective function to be minimized
set_subproblem_objective_economic!(
	scuc_subproblem::Model, NT, NG, ND, NW, NS, units, config_param, scenarios_prob
)

# NS = winds.scenarios_nums
# NW = length(winds.index)
Gsdf = calculate_gsdf(config_param, NL, units, lines, loads, NG, NB, ND)

# println("subject to.") # Indicate the start of constraint definitions
onoffinit = calculate_initial_unit_status(units, NG)
Δp_contingency = define_contingency_size(units, NG)

# --- Add Constraints ---
all_constr_sets = []
# Add the constraints to the optimization model
units_minuptime_constr, units_mindowntime_constr, units_init_stateslogic_consist_constr, units_states_consist_constr, units_init_shutup_cost_constr, units_init_shutdown_cost_costr, units_shutup_cost_constr,
units_shutdown_cost_constr = add_unit_operation_constraints!(scuc_subproblem, NT, NG, units, onoffinit)
winds_curt_constr, loads_curt_const = add_curtailment_constraints!(scuc_subproblem, NT, ND, NW, NS, loads, winds)
units_minpower_constr, units_maxpower_constr = add_generator_power_constraints!(scuc_subproblem, NT, NG, NS, units)
sys_upreserve_constr, sys_down_reserve_constr = add_reserve_constraints!(scuc_subproblem, NT, NG, NC, NS, units, loads, winds, config_param)
sys_balance_constr = add_power_balance_constraints!(scuc_subproblem, NT, NG, ND, NC, NW, NS, loads, winds, config_param, ND2)
units_upramp_constr, units_downramp_constr = add_ramp_constraints!(scuc_subproblem, NT, NG, NS, units, onoffinit)
units_pwlpower_sum_constr, units_pwlblock_upbound_constr, units_pwlblock_dwbound_constr = add_pwl_constraints!(scuc_subproblem, NT, NG, NS, units)
transmissionline_powerflow_upbound_constr, transmissionline_powerflow_downbound_constr = add_transmission_constraints!(
	scuc_subproblem, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, psses, Gsdf, config_param, ND2, DataCentras)
# add_storage_constraints!(scuc_subproblem, NT, NC, NS, config_param, psses)
# add_datacentra_constraints!(scuc_subproblem, NT, NS, config_param, ND2, DataCentras)
# add_frequency_constraints!(scuc_subproblem, NT, NG, NC, NS, units, psses, config_param, Δp_contingency)
# @show model_summary(scuc_subproblem)

# typeof(vec(sys_balance_constr[1])) <: AbstractVector


vec(sys_balance_constr[1])

all_constraints_dict = Dict{Symbol, Any}()

# vec(units_init_stateslogic_consist_constr)
# vec(units_states_consist_constr)
# vec(units_init_shutup_cost_constr)
# vec(units_init_shutdown_cost_costr)
# vec(collect(Iterators.flatten(units_shutup_cost_constr.data)))
# vec(collect(Iterators.flatten(units_shutdown_cost_constr.data)))
# vec(winds_curt_constr)
# vec(loads_curt_const)
# vec(units_minpower_constr)
# vec(units_maxpower_constr)
# vec(sys_upreserve_constr)
# vec(sys_down_reserve_constr)
# vec(units_upramp_constr)
# vec(units_downramp_constr)
# vec(units_pwlpower_sum_constr)
# vec(units_pwlblock_upbound_constr)
# vec(units_pwlblock_dwbound_constr)
# vec(transmissionline_powerflow_upbound_constr[1])
# vec(transmissionline_powerflow_downbound_constr[1])
vec(convert_constraints_type_to_vector(sys_balance_constr))

all_constraints_dict[:units_init_stateslogic_consist_constr] = vec(units_init_stateslogic_consist_constr);
all_constraints_dict[:units_states_consist_constr] = vec(units_states_consist_constr);
all_constraints_dict[:units_init_shutup_cost_constr] = vec(units_init_shutup_cost_constr);
all_constraints_dict[:units_init_shutdown_cost_costr] = vec(units_init_shutdown_cost_costr);
all_constraints_dict[:units_shutup_cost_constr] = vec(collect(Iterators.flatten(units_shutup_cost_constr.data)));
all_constraints_dict[:units_shutdown_cost_constr] = vec(collect(Iterators.flatten(units_shutdown_cost_constr.data)));
all_constraints_dict[:winds_curt_constr] = vec(collect(Iterators.flatten(winds_curt_constr)));
all_constraints_dict[:loads_curt_const] = vec(collect(Iterators.flatten(loads_curt_const)));
all_constraints_dict[:units_minpower_constr] = vec(collect(Iterators.flatten(units_minpower_constr)));
all_constraints_dict[:units_maxpower_constr] = vec(collect(Iterators.flatten(units_maxpower_constr)));
all_constraints_dict[:sys_upreserve_constr] = vec(sys_upreserve_constr);
all_constraints_dict[:sys_down_reserve_constr] = vec(sys_down_reserve_constr);
all_constraints_dict[:units_upramp_constr] = vec(collect(Iterators.flatten(units_upramp_constr)));
all_constraints_dict[:units_downramp_constr] = vec(collect(Iterators.flatten(units_downramp_constr)));
all_constraints_dict[:units_pwlpower_sum_constr] = vec(units_pwlpower_sum_constr);
all_constraints_dict[:units_pwlblock_upbound_constr] = vec(units_pwlblock_upbound_constr);
all_constraints_dict[:units_pwlblock_dwbound_constr] = vec(units_pwlblock_dwbound_constr);
all_constraints_dict[:transmissionline_powerflow_upbound_constr] = vec(transmissionline_powerflow_upbound_constr[1]);
all_constraints_dict[:transmissionline_powerflow_dwbound_constr] = vec(transmissionline_powerflow_dwbound_constr[1]);

units_minuptime_constr
