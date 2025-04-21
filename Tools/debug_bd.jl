include("mainfunc.jl")
scuc_masterproblem, scuc_subproblem, master_model_struct, sub_model_struct, batch_sub_model_struct_dic, config_param, units,
lines, loads, winds, psses, NB, NG, NL, ND, NS, NT, NC, ND2, DataCentras = main();

# DEBUG - benderdecomposition_module
bd_framework(scuc_masterproblem, scuc_subproblem, master_model_struct,
		batch_sub_model_struct_dic, winds, config_param)

scuc_subproblem
optimize!(scuc_subproblem)
dual.(scuc_subproblem[:units_minuptime_constr])

batch_sub_model_struct_dic[1].model
optimize!(batch_sub_model_struct_dic[1].model)
dual.(batch_sub_model_struct_dic[1].constraints.units_minuptime_constr)

@show dual.(batch_sub_model_struct_dic[1].reformated_constraints._smaller_than[:key_units_downramp_constr])

tem = batch_sub_model_struct_dic[1].reformated_constraints._smaller_than
keys(tem)
values(tem)

length(tem)

dual_values_dic = Dict{Symbol,Array{Float64,1}}()
dual_values_dic = Dict(keys => dual.(values) for (keys, values) in tem)

dual_smaller_than_constr_dic = Dict(k => shadow_price.(v) for (k, v) in batch_sub_model_struct_dic[1].reformated_constraints._smaller_than)
dual_smaller_than_constr_dic = Dict(k => dual.(v) for (k, v) in batch_sub_model_struct_dic[1].reformated_constraints._smaller_than)

dual_greater_than_constr_dic = Dict(k => shadow_price.(v) for (k, v) in batch_sub_model_struct_dic[1].reformated_constraints._greater_than)
dual_equal_to_constr_dic = Dict(k => shadow_price.(v) for (k, v) in batch_sub_model_struct_dic[1].reformated_constraints._equal_to)
