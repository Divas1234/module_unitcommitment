using JuMP

export add_datacentra_constraints!

# Helper function for Data Center constraints
function add_datacentra_constraints!(scuc::Model, NT, NS, config_param, ND2 = nothing, DataCentras = nothing)
	# Check if data centers exist and variables are defined
	if isnothing(ND2)
		println("\t constraints: 12) data centra constraints skipped (ND2=0 or variables not defined)")
		return # Skip if no data centers or variables missing
	end

	if config_param.is_ConsiderDataCentra == 0
		println("\t constraints: 12) data centra constraints skipped (is_ConsiderDataCentra != 1)")
	else
		dc_p = scuc[:dc_p]
		dc_f = scuc[:dc_f]
		dc_v² = scuc[:dc_v²]
		dc_λ = scuc[:dc_λ]
		dc_Δu1 = scuc[:dc_Δu1]
		dc_Δu2 = scuc[:dc_Δu2]

		p_max_dc = DataCentras.p_max
		p_min_dc = DataCentras.p_min
		idale_dc = DataCentras.idale
		sv_const_dc = DataCentras.sv_constant
		mu_dc = DataCentras.μ

		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .<= p_max_dc)
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_p[((s - 1) * ND2 + 1):(s * ND2), t] .>= p_min_dc)
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_p[((s - 1) * ND2 + 1):(s * ND2), t]
					.==
					idale_dc .+
					sv_const_dc .* dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t] ./
					mu_dc)

		# McCormick envelopes for bilinear terms (approximated by binary logic here)
		# v² * f = Δu1
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t] .<= dc_v²[((s - 1) * ND2 + 1):(s * ND2), t])
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t] .<= dc_f[((s - 1) * ND2 + 1):(s * ND2), t])
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t]
					.>=
					dc_v²[((s - 1) * ND2 + 1):(s * ND2), t] .+
					dc_f[((s - 1) * ND2 + 1):(s * ND2), t] .- ones(ND2, 1)) # Assuming v², f are binary [0,1]

		# Δu1 * λ = Δu2
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t] .<= dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t])
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t] .<= dc_λ[((s - 1) * ND2 + 1):(s * ND2), t])
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_Δu2[((s - 1) * ND2 + 1):(s * ND2), t]
					.>=
					dc_λ[((s - 1) * ND2 + 1):(s * ND2), t] .+
					dc_Δu1[((s - 1) * ND2 + 1):(s * ND2), t] .- ones(ND2, 1)) # Assuming Δu1, λ are binary [0,1]

		# Assuming computational task constraints
		iter_num = 6
		coeff = 0.05
		iter_block = Int64(round(NT / iter_num))
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_λ[((s - 1) * ND2 + 1):(s * ND2), t] .<= ones(ND2, 1))
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_f[((s - 1) * ND2 + 1):(s * ND2), t] .<= ones(ND2, 1))
		@constraint(scuc, [s = 1:NS, t = 1:NT],
					dc_v²[((s - 1) * ND2 + 1):(s * ND2), t] .<= ones(ND2, 1)) # Assuming v² represents a binary/normalized value

		# Check dimensions and logic for computational_power_tasks
		# Ensure DataCentras.λ is defined and has appropriate dimensions (e.g., scalar or vector of length ND2)
		# Ensure DataCentras.computational_power_tasks is defined and is a vector of length NT
		# lambda_dc = get(DataCentras, :λ, ones(ND2)) # Default lambda if missing
		# comp_tasks = get(DataCentras, :computational_power_tasks, nothing)

		lambda_dc = DataCentras.λ
		comp_tasks = DataCentras.computational_power_tasks

		if comp_tasks !== nothing && length(comp_tasks) == NT
			@constraint(scuc, [s = 1:NS, iter = 1:iter_num],
						sum(dc_λ[((s - 1) * ND2 + 1):(s * ND2),
								 ((iter - 1) * iter_block + 1):(iter * iter_block)])
						.<=
						(1 + coeff) *
						sum(DataCentras.λ) *
						iter_block .*
						sum(DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)]))
			@constraint(scuc, [s = 1:NS, iter = 1:iter_num],
						sum(dc_λ[((s - 1) * ND2 + 1):(s * ND2),
								 ((iter - 1) * iter_block + 1):(iter * iter_block)])
						.>=
						(1 - coeff) *
						sum(DataCentras.λ) *
						iter_block .*
						sum(DataCentras.computational_power_tasks[((iter - 1) * iter_block + 1):(iter * iter_block)]))
		else
			println("Warning: DataCentras.computational_power_tasks or DataCentras.λ not suitable for constraints. Skipping related constraints.")
		end

		println("\t constraints: 12) data centra constraints\t\t\t\t done")
	end
end
