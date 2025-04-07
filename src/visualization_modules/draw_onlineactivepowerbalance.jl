function draw_powerbalance(bench_x₀, bench_p₀, bench_pᵨ, bench_pᵩ, bench_seq_sr⁺, bench_seq_sr⁻, bench_pss_charge_p⁺,
		bench_pss_charge_p⁻, bench_su_cost, bench_sd_cost, bench_prod_cost, bench_cost_sr⁺, bench_cost_sr⁻, secnairos)
	#! Plots power balance
	selected_scenarios = secnairos
	NS = winds.scenarios_nums
	#! calculate different output of grid-connected generators
	conventional_generators_output = bench_p₀[(NG * (selected_scenarios - 1) + 1):(NG * selected_scenarios), :]
	winds_generators_mppt_output = zeros(NW, NT)
	for w in 1:NW
		winds_generators_mppt_output[w, :] = winds.scenarios_curve[w, :] * winds.p_max[w, 1]
	end
	winds_generators_output = winds_generators_mppt_output .- bench_pᵩ[(NW * (selected_scenarios - 1) + 1):(NW * selected_scenarios), :]
	load_curve = loads.load_curve
	loadcurtailments = bench_pᵨ[(ND * (selected_scenarios - 1) + 1):(ND * selected_scenarios), :]
	bess_discharge_power = bench_pss_charge_p⁻[(NC * (selected_scenarios - 1) + 1):(NC * selected_scenarios), :]
	bess_charge_power = bench_pss_charge_p⁺[(NC * (selected_scenarios - 1) + 1):(NC * selected_scenarios), :]
	#! calculate different output of samilar generators
	sum_conventional_generators_output = sum(conventional_generators_output, dims = 1)[1, :]
	sum_winds_generators_output = sum(winds_generators_output, dims = 1)[1, :]
	sum_loadcurtailments = sum(loadcurtailments, dims = 1)[1, :]
	sum_bess_discharge_power = sum(bess_discharge_power, dims = 1)[1, :]
	sum_bess_charge_power = sum(bess_charge_power, dims = 1)[1, :]
	#! NOTE: ploting
	basline_output = zeros(1, NT)[1, :]
	xdata = collect(1:NT)
	p1 = Plots.plot(xdata, basline_output,
		fillrange = sum_conventional_generators_output,
		size = (250, 280),
		xlabel = L"t / h",
		ylabel = L"\textrm{Output \,/\, p.u.}",
		framestyle = :box,
		foreground_color_grid = :grey,
		# lc = :cornflowerblue,
		tickfontfamily = "Palatino Bold",
		# legendfontfamily = "Palatino Bold",
		# fa=0.5,
		background_color_inside = :transparent,
		grid = :true,
		# foreground_color_legend = nothing,
		gc = 0.75,
		lw = 0.5,
		lc = :red,
		ls = :dash,
		xlims = (0, 25),
		ylims = (-1, 6.6),
		gridlinewidth = 1,
		# fillalpha = 0.5,
		c = RGB(159 / 255, 66 / 255, 64 / 255),
		# legend_columns=-1,
		label = L"\textrm{conventional \,\,units}",
		legend = :topright)
	p1 = Plots.plot!(xdata, sum_conventional_generators_output,
		fillrange = sum_conventional_generators_output .+ sum_winds_generators_output,
		fillalpha = 0.95,
		lw = 0.5,
		ls = :dash,
		lc = :blue,
		c = RGB(94 / 255, 133 / 255, 149 / 255),
		label = L"\textrm{winds\,\, farms}")
	p1 = Plots.plot!(xdata,
		sum_conventional_generators_output .+ sum_winds_generators_output,
		fillrange = sum_conventional_generators_output .+ sum_winds_generators_output .+ sum_bess_discharge_power,
		fillalpha = 0.95,
		lc = :blue,
		ls = :dash,
		lw = 0.5,
		c = RGB(137 / 255, 176 / 255, 81 / 255),
		label = L"\textrm{BESS \,(discharge)}"        # legend = :topleft
	)
	p1 = Plots.plot!(xdata,
		sum_conventional_generators_output .+ sum_winds_generators_output .+ sum_bess_discharge_power .+ sum_loadcurtailments,
		fillrange = sum_conventional_generators_output .+ sum_winds_generators_output .+ sum_bess_discharge_power .+ sum_loadcurtailments,
		fillalpha = 0.95,
		ls = :dash,
		lw = 0.5,
		lc = :blue,
		c = RGB(251 / 255, 234 / 255, 90 / 255),
		label = L"\textrm{Load\, shedding}"        # legend = :topleft
	)

	p1 = Plots.plot!(xdata, basline_output,
		fillrange = -sum_bess_charge_power, fillalpha = 0.95,
		label = L"\textrm{BESS \,(charge)}", c = RGB(49 / 255, 163 / 255, 84 / 255))

	p1 = Plots.plot!(xdata, -sum_bess_charge_power, ls = :dash,
		lw = 0.5,
		lc = :blue, label = "")

	return p1
end
