function exported_scheduling_cost(JuMP.value, NT::Int64, NB::Int64, NG::Int64, ND::Int64, NC::Int64, ND2::Int64, units::unit, loads::load,
		winds::wind, lines::transmissionline, DataCentras::data_centra, config_param::config)
	su_cost = sum(JuMP.value.(su₀))
	sd_cost = sum(JuMP.value.(sd₀))
	pᵪ = JuMP.value.(pgₖ)
	p₀ = JuMP.value.(pg₀)
	x₀ = JuMP.value.(x)
	r⁺ = JuMP.value.(sr⁺)
	r⁻ = JuMP.value.(sr⁻)
	pᵨ = JuMP.value.(Δpd)
	pᵩ = JuMP.value.(Δpw)

	pss_charge_state⁺ = JuMP.value.(κ⁺)
	pss_charge_state⁻ = JuMP.value.(κ⁻)
	pss_charge_p⁺ = JuMP.value.(pc⁺)
	pss_charge_p⁻ = JuMP.value.(pc⁻)
	pss_charge_q = JuMP.value.(qc)
	# pss_sumchargeenergy = JuMP.value.(pss_sumchargeenergy)

	prod_cost = pₛ *
				c₀ *
				(
					sum(
					sum(
						sum(sum(pᵪ[i + (s - 1) * NG, t, :] .* eachslope[:, i] for t in 1:NT))
					for s in 1:NS
					) for i in 1:NG
				) + sum(sum(sum(x₀[:, t] .* refcost[:, 1] for t in 1:NT)) for s in 1:NS)
				)
	cr⁺ = pₛ *
		  c₀ *
		  sum(
			  sum(sum(ρ⁺ * r⁺[i + (s - 1) * NG, t] for i in 1:NG) for t in 1:NT)
		  for s in 1:NS
		  )
	cr⁻ = pₛ *
		  c₀ *
		  sum(
			  sum(sum(ρ⁺ * r⁻[i + (s - 1) * NG, t] for i in 1:NG) for t in 1:NT)
		  for s in 1:NS
		  )
	seq_sr⁺ = pₛ * c₀ * sum(ρ⁺ * r⁺[i, :] for i in 1:NG)
	seq_sr⁻ = pₛ * c₀ * sum(ρ⁺ * r⁻[i, :] for i in 1:NG)
	𝜟pd = pₛ * sum(sum(sum(pᵨ[(1 + (s - 1) * ND):(s * ND), t]) for t in 1:NT) for s in 1:NS)
	𝜟pw = pₛ * sum(sum(sum(pᵩ[(1 + (s - 1) * NW):(s * NW), t]) for t in 1:NT) for s in 1:NS)
	str = zeros(1, 7)
	str[1, 1] = su_cost * 10
	str[1, 2] = sd_cost * 10
	str[1, 3] = prod_cost
	str[1, 4] = cr⁺
	str[1, 5] = cr⁻
	str[1, 6] = 𝜟pd
	str[1, 7] = 𝜟pw

	# Set output directory for results
	output_dir = joinpath(pwd(), "output")

	# Create directory if it doesn't exist
	try
		if !isdir(output_dir)
			mkdir(output_dir)
		end

		# Open output file for writing results
		output_file = joinpath(output_dir, "Bench_calculation_result.txt")
		open(output_file, "w") do io
			writedlm(io, [" "])
			writedlm(io, ["su_cost" "sd_cost" "prod_cost" "cr⁺" "cr⁻" "𝜟pd" "𝜟pw"], '\t')
			writedlm(io, str, '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 1: units stutup/down states"])
			writedlm(io, JuMP.value.(x), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 2: units dispatching power in scenario NO.1"])
			writedlm(io, JuMP.value.(pg₀[1:NG, 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 3: spolied wind power"])
			writedlm(io, JuMP.value.(Δpw[1:NW, 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 4: forced load curtailments"])
			writedlm(io, JuMP.value.(Δpd[1:ND, 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 5: pss charge state"])
			writedlm(io, pss_charge_state⁺[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 6: pss discharge state"])
			writedlm(io, pss_charge_state⁻[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 7: pss charge power"])
			writedlm(io, pss_charge_p⁺[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 8: pss discharge power"])
			writedlm(io, pss_charge_p⁻[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 9: pss strored energy"])
			writedlm(io, pss_charge_q[1:NC, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 10: sr⁺"])
			writedlm(io, r⁺[1:NG, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 11: sr⁻"])
			writedlm(io, r⁻[1:NG, 1:NT], '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 12: α"])
			writedlm(io, JuMP.value.(α[1:NC, 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 13: β"])
			writedlm(io, JuMP.value.(β[1:NC, 1:NT]), '\t')
		end
		println("The calculation result has been saved to: $output_file")
		println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")

		# Open output file for writing results
		output_file = joinpath(output_dir, "Bench_datacentra_result.txt")
		open(output_file, "w") do io
			writedlm(io, [" "])
			writedlm(io, ["list 1: dc_p"], '\t')
			writedlm(io, JuMP.value.(dc_p[1:(ND2 * NS), 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 2: dc_f"])
			writedlm(io, JuMP.value.(dc_f[1:(ND2 * NS), 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 3: dc_v²"])
			writedlm(io, JuMP.value.(dc_v²[1:(ND2 * NS), 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 4: dc_λ"])
			writedlm(io, JuMP.value.(dc_λ[1:(ND2 * NS), 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 5: dc_Δu1"])
			writedlm(io, JuMP.value.(dc_Δu1[1:(ND2 * NS), 1:NT]), '\t')
			writedlm(io, [" "])
			writedlm(io, ["list 6: dc_Δu2"])
			writedlm(io, JuMP.value.(dc_Δu2[1:(ND2 * NS), 1:NT]), '\t')
		end
		println("The calculation result has been saved to: $output_file")
		println("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++")

		# Open output file for csv writing results
		output_dir = "D:/GithubClonefiles/datacentra_unitcommitment/output/data_centra/"

		s = 1
		@show data_to_write = [
			("dc_Δu2.csv", JuMP.value.(dc_Δu2[1:(ND2), 1:NT])),
			("dc_Δu1.csv", JuMP.value.(dc_Δu1[1:(ND2), 1:NT])),
			("dc_v².csv", JuMP.value.(dc_v²[1:(ND2), 1:NT])),
			("dc_λ.csv", JuMP.value.(dc_λ[1:(ND2), 1:NT])),
			("dc_f.csv", JuMP.value.(dc_f[1:(ND2), 1:NT])),
			("dc_p.csv", JuMP.value.(dc_p[1:(ND2), 1:NT])),
			("dc_debug_tasks_1.csv",
				(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((1 - 1) * iter_block + 1):(1 * iter_block)]))),
			("dc_debug_tasks_2.csv",
				(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((2 - 1) * iter_block + 1):(2 * iter_block)]))),
			("dc_debug_tasks_3.csv",
				(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((3 - 1) * iter_block + 1):(3 * iter_block)]))),
			("dc_debug_tasks_4.csv",
				(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((4 - 1) * iter_block + 1):(4 * iter_block)]))),
			("dc_debug_tasks_5.csv",
				(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((5 - 1) * iter_block + 1):(5 * iter_block)]))),
			("dc_debug_tasks_6.csv",
				(JuMP.value.(dc_λ[((s - 1) * ND2 + 1):(s * ND2), ((6 - 1) * iter_block + 1):(6 * iter_block)])))
		]

		# @constraint(scuc, [s = 1:NS, t = 1:NT, iter = 1:iter_num],
		# 	sum(dc_λ[((s - 1) * ND2 + 1):(s * ND2),
		# 		((iter - 1) * iter_block + 1):(iter * iter_block)]).<=(1 + coeff) * sum(DataCentras.λ) .* DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])

		iter = 1
		println("===============================================================================")
		@show (1 + coeff) * sum(DataCentras.λ) * iter_block .*
			  sum(DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])
		@show (1 - coeff) * sum(DataCentras.λ) * iter_block .*
			  sum(DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])
		@show sum(JuMP.value.(dc_λ[
			((s - 1) * ND2 + 1):(s * ND2), ((iter - 1) * iter_block + 1):(iter * iter_block)])) .*
			  sum(DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)])

		println("===============================================================================")

		for (filename, data) in data_to_write
			filepath = joinpath(output_dir, filename)
			try
				CSV.write(filepath, DataFrame(data, :auto))
				println("Successfully wrote to $filepath")
			catch e
				@error "Failed to write to $filepath" exception=(e, catch_backtrace())
			end
		end

	catch e
		println("Error writing results to file: $e")
	end

	dc_p, dc_f, dc_v², dc_λ, dc_Δu1, dc_Δu2 = JuMP.value.(dc_p[1:(ND2 * NS), 1:NT]),
	JuMP.value.(dc_f[1:(ND2 * NS), 1:NT]), JuMP.value.(dc_v²[1:(ND2 * NS), 1:NT]), JuMP.value.(dc_λ[
		1:(ND2 * NS), 1:NT]),
	JuMP.value.(dc_Δu1[1:(ND2 * NS), 1:NT]), JuMP.value.(dc_Δu2[1:(ND2 * NS), 1:NT])

	# Return optimization results
	return x₀, p₀, pᵨ, pᵩ, seq_sr⁺, seq_sr⁻, pss_charge_p⁺, pss_charge_p⁻, su_cost,
	sd_cost, prod_cost, cr⁺, cr⁻, dc_p, dc_f, dc_v², dc_λ, dc_Δu1, dc_Δu2
end
