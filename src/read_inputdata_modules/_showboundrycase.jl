using Printf

function boundrycondition(
		NB::Int64,
		NL::Int64,
		NG::Int64,
		NT::Int64,
		ND::Int64,
		units::unit,
		loads::load,
		lines::transmissionline,
		winds::wind,
		stroges::pss
)
	# (Assuming this code is inside a function, e.g., showboundrycase)
	# Consider defining Base.show methods for custom structs (units, loads, etc.)
	# for better encapsulation and reusability of display logic.

	NS = winds.scenarios_nums
	NW = length(winds.index)

	println("\n--- System Totals ---")
	println("  Number of Buses (NB):      ", NB)
	println("  Number of Lines (NL):      ", NL)
	println("  Number of Generators (NG): ", NG)
	println("  Number of Loads (ND):      ", ND)
	println("  Number of Time Periods (NT):", NT)
	println("  Number of Wind Units (NW): ", NW)
	println("  Number of Scenarios (NS):  ", NS)

	println("\n--- Configuration Parameters ---")
	println("  is_NetWorkCon:             ", config_param.is_NetWorkCon)
	println("  is_ThermalUnitCon:         ", config_param.is_ThermalUnitCon)
	println("  is_WindUnitCon:            ", config_param.is_WindUnitCon)
	println("  is_SysticalCon:            ", config_param.is_SysticalCon)
	println("  is_PieceLinear:            ", config_param.is_PieceLinear)
	println("  is_NumSeg:                 ", config_param.is_NumSeg)
	println("  is_Alpha:                  ", config_param.is_Alpha)
	println("  is_Belta:                  ", config_param.is_Belta)
	println("  is_CoalPrice:              ", config_param.is_CoalPrice)
	println("  is_ActiveLoad:             ", config_param.is_ActiveLoad)
	println("  is_WindIntegration:        ", config_param.is_WindIntegration)
	println("  is_LoadsCuttingCoefficient:", config_param.is_LoadsCuttingCoefficient)
	println("  is_WindsCuttingCoefficient:", config_param.is_WindsCuttingCoefficient)
	println("  is_MaxIterationsNum:       ", config_param.is_MaxIterationsNum)
	println("  is_CalculPrecision:        ", config_param.is_CalculPrecision)

	println("\n--- Thermal Units Info (units) ---")
	# Consider implementing Base.show(io::IO, ::MIME"text/plain", u::YourUnitType)
	println("  index:                     ", units.index)
	println("  locatebus:                 ", units.locatebus)
	println("  p_max:                     ", units.p_max)
	println("  p_min:                     ", units.p_min)
	println("  ramp_up:                   ", units.ramp_up)
	println("  ramp_down:                 ", units.ramp_down)
	println("  shut_up:                   ", units.shut_up)
	println("  shut_down:                 ", units.shut_down)
	println("  min_shutup_time:           ", units.min_shutup_time)
	println("  min_shutdown_time:         ", units.min_shutdown_time)
	println("  x_0 (initial state):       ", units.x_0)
	println("  t_0 (initial time in state):", units.t_0)
	println("  p_0 (initial power):       ", units.p_0)
	println("  coffi_a:                   ", units.coffi_a)
	println("  coffi_b:                   ", units.coffi_b)
	println("  coffi_c:                   ", units.coffi_c)
	println("  coffi_cold_shutup_1:       ", units.coffi_cold_shutup_1)
	println("  coffi_cold_shutup_2:       ", units.coffi_cold_shutup_2)
	println("  coffi_cold_shutdown_1:     ", units.coffi_cold_shutdown_1)
	println("  coffi_cold_shutdown_2:     ", units.coffi_cold_shutdown_2)

	println("\n--- Loads Info (loads) ---")
	# Consider implementing Base.show for YourLoadType
	println("  index:                     ", loads.index)
	println("  locatebus:                 ", loads.locatebus)
	println("  load_curve (ND x NT):")
	# Basic matrix print - adjust formatting as needed
	# Could use PrettyTables.jl for nicer output if it's a dependency
	for i in 1:ND
		print("    Load ", i, ": ")
		for j in 1:NT
			@printf("%8.3f ", loads.load_curve[i, j]) # Adjust format width as needed
		end
		println() # Newline after each load's curve
	end

	println("\n--- Lines Info (lines) ---")
	# Consider implementing Base.show for YourLineType
	println("  from:                      ", lines.from)
	println("  to:                        ", lines.to)
	println("  x (reactance):             ", lines.x)
	println("  p_max (forward limit):     ", lines.p_max)
	println("  p_min (backward limit):    ", lines.p_min) # Assuming p_min is backward limit

	println("\n--- Wind Units Info (winds) ---")
	# Consider implementing Base.show for YourWindType
	println("  index:                     ", winds.index)
	println("  scenarios_prob:            ", winds.scenarios_prob)
	println("  scenarios_nums:            ", winds.scenarios_nums) # Same as NS above
	println("  p_max (installed capacity):", winds.p_max)
	println("  scenarios_curve:           ", winds.scenarios_curve) # Consider better display for multi-dim array

	println("\n--- Storage Info (stroges) ---") # Typo in original: stroges -> storages?
	# Consider implementing Base.show for YourStorageType
	println("  index:                     ", stroges.index)
	println("  locatebus:                 ", stroges.locatebus)
	println("  Q_max (energy capacity):   ", stroges.Q_max) # Renamed for clarity
	println("  Q_min (min energy):        ", stroges.Q_min) # Renamed for clarity
	println("  p⁺ (max charge rate):      ", stroges.p⁺)
	println("  p⁻ (max discharge rate):   ", stroges.p⁻)
	println("  P₀ (initial energy):       ", stroges.P₀) # Assuming P₀ is initial energy state?
	println("  γ⁺ (charging cost coeff):  ", stroges.γ⁺) # Guessed meaning
	println("  γ⁻ (discharging cost coeff):", stroges.γ⁻) # Guessed meaning
	println("  η⁺ (charging efficiency):  ", stroges.η⁺)
	println("  η⁻ (discharging efficiency):", stroges.η⁻)
	println("  δₛ (self-discharge rate?): ", stroges.δₛ) # Guessed meaning
end
