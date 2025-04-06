using PlotlyJS, LaTeXStrings

function plotcasestudies(p₀, pᵨ, pᵩ, seq_sr⁺, seq_sr⁻, su_cost, sd_cost, prod_cost, cost_sr⁺, cost_sr⁻, NT, NG, ND, NW, NC)

	# Powerbalance fig
	fig1 = area1(p₀, pᵨ, pᵩ, NT, NG, ND, NW, NC)

	# prod_cost result
	fig2 = bar1(seq_sr⁺, seq_sr⁻, su_cost, sd_cost, prod_cost, cost_sr⁺, cost_sr⁻)

	# spinning reserve
	fig3 = line1(seq_sr⁺, seq_sr⁻, NT, NC)
	fig4 = line2(seq_sr⁺, seq_sr⁻, NT, NC)

	return [fig1 fig2
			fig3 fig4]
end

function area1(p₀, pᵨ, pᵩ, NT, NG, ND, NW, NC)
	y1_index = p₀[1:NG, 1:NT] # units power

	y2_index = zeros(NW, NT)
	for i in 1:NW
		y2_index[i, :] = winds.scenarios_curve[1, :] .* winds.p_max[i, 1] - pᵨ[i, 1:NT] # wind power
	end
	y3_index = pᵩ[1:NW, 1:NT] # spolied wind power

	# y4_index = pss_charge_p⁺[1:NC, 1:NT] # pss charge power
	# y5_index = pss_charge_p⁻[1:NC, 1:NT] # pss discharge power
	y6_index = pᵨ[1:ND, 1:NT] # loadcutting power

	y1_index = sum(y1_index[i, :] for i in 1:NG)
	y2_index = sum(y2_index[i, :] for i in 1:NW)
	y3_index = sum(y3_index[i, :] for i in 1:NW)
	# y4_index = sum(y4_index[i, :] for i in 1:NC)
	# y5_index = sum(y5_index[i, :] for i in 1:NC)
	y6_index = sum(y6_index[i, :] for i in 1:ND)

	# Note: must do not appear the spoliedwinds
	# s0 = (y4_index + y3_index) * -1
	s0 = (y6_index) * -1 # spolied loads
	# s1 = y4_index * -1
	# s2 = y5_index
	s3 = y1_index # units power
	s4 = s3 + y2_index # winds power + units power
	# s5 = s4 + y5_index

	trace1 = PlotlyJS.scatter(; x = 1:NT, y = s0, fill = "tozeroy", mode = "none")
	# trace2 = PlotlyJS.scatter(; x = 1:NT, y = s1, fill = "tozerox", mode = "none")
	# trace3 = PlotlyJS.scatter(; x = 1:NT, y = s2, fill = "tonexty", mode = "none")
	trace4 = PlotlyJS.scatter(; x = 1:NT, y = s3, fill = "tonextx", mode = "none")
	trace5 = PlotlyJS.scatter(; x = 1:NT, y = s4, fill = "tonexty", mode = "none")
	# trace6 = PlotlyJS.scatter(; x = 1:NT, y = s5, fill = "tonexty", mode = "none")

	return PlotlyJS.plot([trace1, trace4, trace5],
		Layout(title = "Fig.1 Powerbalance"))
end

function bar1(seq_sr⁺, seq_sr⁻, su_cost, sd_cost, prod_cost, cost_sr⁺, cost_sr⁻)
	prod_cost = prod_cost / 10
	# sr1_cost = sum(seq_sr⁺) * 1e2
	# sr2_cost = sum(seq_sr⁻) * 1e2
	cost_sr⁺ = cost_sr⁺ * 1e1
	cost_sr⁻ = cost_sr⁻ * 1e1
	x_label = ["su_cost", "sd_cost", "prod_cost", "sr_cost_1", "sr_cost_2"]
	y_label = [su_cost, sd_cost, prod_cost, cost_sr⁺, cost_sr⁻]

	fig2 = PlotlyJS.bar(; x = x_label, y = y_label)
	return PlotlyJS.plot(fig2, Layout(title = "Fig.2 cost_result"))
end

function line1(seq_sr⁺, seq_sr⁻, NT, NC)

	# sr provided by conventional units
	trace1 = PlotlyJS.scatter(; x = 1:NT, y = seq_sr⁺, mode = "lines+markers")
	# sr provided by conventional units and pss
	# str = sum(pss_charge_p⁻[c, :] for c in 1:NC)
	# trace2 = PlotlyJS.scatter(; x=1:NT, y=seq_sr⁺, mode="lines+markers")
	# trace2 = PlotlyJS.scatter(; x = 1:NT, y = seq_sr⁻, mode = "lines+markers")

	return PlotlyJS.plot([trace1], Layout(title = "Fig.3 sr_plus"))
end

function line2(seq_sr⁺, seq_sr⁻, NT, NC)

	# sr provided by conventional units and pss
	trace1 = PlotlyJS.scatter(; x = 1:NT, y = seq_sr⁻, mode = "lines+markers")
	# sr provided by conventional units and pss
	# str = sum(pss_charge_p⁺[c, :] for c in 1:NC)
	# trace2 = PlotlyJS.scatter(; x=1:NT, y=seq_sr⁻, mode="lines+markers")

	return PlotlyJS.plot([trace1], Layout(title = "Fig.4 sr_mins"))
end
