# linearization
function linearizationfuelcurve(units, NG)
	linearpower_limits = (units.p_max - units.p_min) ./ 3
	cost = zeros(NG, 4)
	temp = units.p_min
	cost[:, 1] = units.coffi_a .* (units.p_min .^ 2) +
				 units.coffi_b .* units.p_min +
				 units.coffi_c
	for i in 2:4
		temp = temp + linearpower_limits
		cost[:, i] = units.coffi_a .* (temp .^ 2) + units.coffi_b .* temp + units.coffi_c
	end
	eachslope = zeros(NG, 3)
	for i in 1:3
		eachslope[:, i] = (cost[:, i + 1] - cost[:, i]) ./ linearpower_limits
	end
	#     println("baselinecost>>\t\t", cost[:,1])
	#     println("eachslope>>\t\t", eachslope)
	return cost[:, 1], eachslope'
end
