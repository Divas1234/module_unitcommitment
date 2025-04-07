using JuMP

export add_transmission_constraints!

# Helper function for transmission line constraints
function add_transmission_constraints!(
		scuc::Model, NT, NG, ND, NC, NW, NL, NS, units, loads, winds, lines, stroges, Gsdf)

	# Check if network constraints should be applied
	# if NL == 0 || Gsdf === nothing
	#     println("\t constraints: 10) transmissionline limits skipped (NL=0 or Gsdf missing)")
	#     return
	# end

	pg₀ = scuc[:pg₀]
	Δpd = scuc[:Δpd]
	Δpw = scuc[:Δpw]

	# Check if storage variables exist before accessing them
	pc⁺ = scuc[:pc⁺]
	pc⁻ = scuc[:pc⁻]

	# This function assumes Gsdf is pre-calculated and passed
	for l in 1:NL
		subGsdf_units = Gsdf[l, units.locatebus]
		subGsdf_winds = Gsdf[l, winds.index]
		subGsdf_loads = Gsdf[l, loads.locatebus]
		# Ensure stroges.locatebus is valid and Gsdf has correct dimensions
		subGsdf_psses = (NC > 0 && isdefined(stroges, :locatebus)) ? Gsdf[l, stroges.locatebus] : [] # Handle NC=0 or missing locatebus

		@constraint(scuc,
			[s = 1:NS, t = 1:NT],
			sum(subGsdf_units[i] * pg₀[i + (s - 1) * NG, t] for i in 1:NG) + sum(
				subGsdf_winds[w] * (
					winds.scenarios_curve[s, t] * winds.p_max[w, 1] -
					Δpw[(s - 1) * NW + w, t]
				) for w in 1:NW
			) - sum(
				subGsdf_loads[d] * (loads.load_curve[d, t] - Δpd[(s - 1) * ND + d, t])
			for d in 1:ND
			) + sum(
			# Check if NC > 0, storage variables exist, and subGsdf_psses is valid before summing storage contribution
				(NC > 0 && pc⁺ !== nothing && pc⁻ !== nothing && c <= length(subGsdf_psses) ?
				 subGsdf_psses[c] * (pc⁻[(s - 1) * NC + c, t] - pc⁺[(s - 1) * NC + c, t]) : 0.0)
			for c in 1:NC # Loop will not run if NC=0
			)<=lines.p_max[l, 1])
		@constraint(scuc,
			[s = 1:NS, t = 1:NT],
			sum(subGsdf_units[i] * pg₀[i + (s - 1) * NG, t] for i in 1:NG) + sum(
				subGsdf_winds[w] * (
					winds.scenarios_curve[s, t] * winds.p_max[w, 1] -
					Δpw[(s - 1) * NW + w, t]
				) for w in 1:NW
			) - sum(
				subGsdf_loads[d] * (loads.load_curve[d, t] - Δpd[(s - 1) * ND + d, t])
			for d in 1:ND
			) + sum(
			# Check if NC > 0, storage variables exist, and subGsdf_psses is valid before summing storage contribution
				(NC > 0 && pc⁺ !== nothing && pc⁻ !== nothing && c <= length(subGsdf_psses) ?
				 subGsdf_psses[c] * (pc⁻[(s - 1) * NC + c, t] - pc⁺[(s - 1) * NC + c, t]) : 0.0)
			for c in 1:NC # Loop will not run if NC=0
			)>=lines.p_min[l, 1])
	end
	println("\t constraints: 10) transmissionline limits for basline\t\t\t done")
end
