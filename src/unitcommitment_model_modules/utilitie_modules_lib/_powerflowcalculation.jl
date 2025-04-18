function linearpowerflow(units::unit,
	lines::transmissionline,
	loads::load,
	NG::Int64,
	NB::Int64,
	ND::Int64,
	NL::Int64)
	B = zeros(NB, NB)
	M = zeros(NB, NL)

	for k in 1:NL
		n1 = lines.from[k, 1]
		n2 = lines.to[k, 1]
		M[n1, k] = 1
		M[n2, k] = -1
		n5 = 1.0 / lines.x[k, 1]
		B[n1, n1] = B[n1, n1] + n5
		B[n2, n2] = B[n2, n2] + n5
		B[n1, n2] = B[n1, n2] - n5
		B[n2, n1] = B[n2, n1] - n5
	end

	G2B = zeros(NB, NG)
	D2B = zeros(NB, ND)

	for i in 1:NG
		G2B[units.locatebus[i, 1], i] = 1
	end
	for i in 1:ND
		D2B[loads.locatebus[i, 1], i] = 1
	end
	# UnitsPower = sum(loads.load_curve) / NT / sum(units.p_max) .* units.p_max
	Note_slack = 1
	# P_injection = G2B * UnitsPower - D2B * sum(loads.load_curve[:,i] for i in 1:NT) / ND
	# P_injection = P_injection[1: NB .!=Note_slack,:]

	B1 = zeros(NB - 1, NB - 1)
	if Note_slack == 1
		B1[1:(NB - 1), :] = B[2:NB, 2:NB]
	else
		B1[1:(Note_slack - 1), 1:(Note_slack - 1)] = B[1:(Note_slack - 1), 1:(Note_slack - 1)]
		B1[Note_slack:(NB - 1), 1:(Note_slack - 1)] = B[Note_slack:NB, 1:(Note_slack - 1)]
		B1[1:(Note_slack - 1), (Note_slack - 1):(NB - 1)] = B[1:(Note_slack - 1), Note_slack:NB]
		B1[(Note_slack - 1):(NB - 1), (Note_slack - 1):(NB - 1)] = B[Note_slack:NB, Note_slack:NB]
	end

	Z = inv(B1)
	M1 = M
	M1 = M1[1:NB .!= Note_slack, :]

	# Line_power = (M1' * inv(B1) * P_injection) ./ lines.x

	T1 = M1' / B1
	for k in 1:(NB - 1)
		T1[:, k] = T1[:, k] ./ lines.x
	end

	Gsdf = zeros(NL, NB)
	if Note_slack == 1
		Gsdf[:, (Note_slack + 1):NB] = T1[:, Note_slack:(NB - 1)]
	else
		Gsdf[:, 1:(Note_slack - 1)] = T1[:, 1:(Note_slack - 1)]
		Gsdf[:, (Note_slack + 1):NB] = T1[:, Note_slack:(NB - 1)]
	end

	return G2B, D2B, Gsdf
end
