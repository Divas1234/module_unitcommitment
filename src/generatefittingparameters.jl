using MultivariateStats

function generatefreq_fittingparameters(units, winds, NG, NW, NN, flag_method_type, μ, σ)

    # flag_method_type = 1
	whitenoise_parameter = rand(Normal(μ, σ), NN)
	whitenoise_parameter_probability = cdf(Normal(μ, σ), whitenoise_parameter)
    fittingparameter_vector = zeros(NN, 4)
    for n in 1:NN
        println(n)
        fittingparameter_vector[n, :] = creatfrequencyfittingfunction(units, winds, NG, NW, flag_method_type, whitenoise_parameter[n])
    end
    return fittingparameter_vector, whitenoise_parameter, whitenoise_parameter_probability
end

function generate_fitting_parameters(units, winds, NG, NW, flag_method_type, whitenoise_parameter)
    Set_f_nadir, set_H, set_δp, set_Dg, set_Fg, set_Kg, set_Rg, sampleStatues = montecalrosimulation(
        units, winds, NG, NW, flag_method_type, whitenoise_parameter,
    )

    res = transpose(
        vcat(
            transpose(set_H),
            transpose(set_Fg ./ set_Rg),
            transpose(1 ./ set_Rg),
            transpose(Set_f_nadir),
        ),
    )

    new_res = sortslices(res; dims = 1, lt = (x, y) -> isless(x[1], y[1]))
    R = kmeans(transpose(new_res), 10; maxiter = 200, display = :iter)

    PWL_model = Model(Gurobi.Optimizer)
    set_optimizer_attribute(PWL_model, "OutputFlag", 0)
    set_silent(PWL_model)
    coeffi_num = Int32(4)
    dataset = transpose(R.centers)
    bigM = 1e4
    clusteringnumber = size(dataset, 1)
    @variable(PWL_model, coefficient[1, 1:coeffi_num])
    @variable(PWL_model, tem[1:clusteringnumber, 1] >= 0)
    @objective(PWL_model, Min, 1e3 * sum(tem[i, 1] for i in 1:clusteringnumber))
    @constraint(
        PWL_model,
        [i = 1:clusteringnumber, j = 1:4],
        tem[i, 1] >= dataset[i, 4] - sum(sum(coefficient[1, 1:3] .* dataset[i, 1:3]) + coefficient[1, 4])
    )
    JuMP.optimize!(PWL_model)

    res = JuMP.value.(coefficient).data

    return res
end