# reformat data
struct config
	# member variables
	is_NetWorkCon::Int64
	is_ThermalUnitCon::Int64
	is_WindUnitCon::Int64
	is_SysticalCon::Int64
	is_PieceLinear::Int64
	is_NumSeg::Int64
	is_Alpha::Float64
	is_Belta::Float64
	is_CoalPrice::Int64
	is_ActiveLoad::Int64
	is_WindIntegration::Int64
	is_LoadsCuttingCoefficient::Float64
	is_WindsCuttingCoefficient::Float64
	is_MaxIterationsNum::Int64
	is_CalculPrecision::Float64
	is_ConsiderDataCentra::Int64
	is_ConsiderFrequencyControl::Int64
	is_ConsiderBESS::Int64
	is_ConsiderMultiCUTs::Int64
	# function config(is_NetWorkCon::Int64,
	# 		is_ThermalUnitCon::Int64,
	# 		is_WindUnitCon::Int64,
	# 		is_SysticalCon::Int64,
	# 		is_PieceLinear::Int64,
	# 		is_NumSeg::Int64,
	# 		is_Alpha::Float64,
	# 		is_Belta::Float64,
	# 		is_CoalPrice::Int64,
	# 		is_ActiveLoad::Int64,
	# 		is_WindIntegration::Int64,
	# 		is_LoadsCuttingCoefficient::Float64,
	# 		is_WindsCuttingCoefficient::Float64,
	# 		is_MaxIterationsNum::Int64,
	# 		is_CalculPrecision::Float64,
	# 		is_ConsiderDataCentra::Int64,
	# 		is_ConsiderFrequencyControl::Int64)
	# 	return new(
	# 		is_NetWorkCon,
	# 		is_ThermalUnitCon,
	# 		is_WindUnitCon,
	# 		is_SysticalCon,
	# 		is_PieceLinear,
	# 		is_NumSeg,
	# 		is_Alpha,
	# 		is_Belta,
	# 		is_CoalPrice,
	# 		is_ActiveLoad,
	# 		is_WindIntegration,
	# 		is_LoadsCuttingCoefficient,
	# 		is_WindsCuttingCoefficient,
	# 		is_MaxIterationsNum,
	# 		is_CalculPrecision,
	# 		is_ConsiderDataCentra,
	# 		is_ConsiderFrequencyControl
	# 	)
	# end
end

struct unit
	index::Vector{Int64}
	locatebus::Vector{Int64}
	p_max::Vector{Float64}
	p_min::Vector{Float64}
	ramp_up::Vector{Float64}
	ramp_down::Vector{Float64}
	shut_up::Vector{Float64}
	shut_down::Vector{Float64}
	min_shutup_time::Vector{Float64}
	min_shutdown_time::Vector{Float64}
	x_0::Vector{Float64}
	t_0::Vector{Float64}
	p_0::Vector{Float64}
	coffi_a::Vector{Float64}
	coffi_b::Vector{Float64}
	coffi_c::Vector{Float64}
	coffi_cold_shutup_1::Vector{Float64}
	coffi_cold_shutup_2::Vector{Float64}
	coffi_cold_shutdown_1::Vector{Float64}
	coffi_cold_shutdown_2::Vector{Float64}

	# frequenct constrol parameters

	# Part-1 interia response process
	Hg::Vector{Float64} # interia constant of conventional units
	Dg::Vector{Float64} # damping constant

	# Part-2 primary frequency response process
	Kg::Vector{Float64} # Mechnical power gain of conventional units
	Fg::Vector{Float64} # Fraction of total power generated by the turbine of conventional units
	Tg::Vector{Float64} # time constant
	Rg::Vector{Float64} # Droop grain of conventional units

	function unit(index,
		locatebus,
		p_max,
		p_min,
		ramp_up,
		ramp_down,
		shut_up,
		shut_down,
		min_shutup_time,
		min_shutdown_time,
		x_0,
		t_0,
		p_0,
		coffi_a,
		coffi_b,
		coffi_c,
		coffi_cold_shutup_1,
		coffi_cold_shutup_2,
		coffi_cold_shutdown_1,
		coffi_cold_shutdown_2,
		Hg,
		Dg,
		Kg,
		Fg,
		Tg,
		Rg)
		return new(index,
			locatebus,
			p_max,
			p_min,
			ramp_up,
			ramp_down,
			shut_up,
			shut_down,
			min_shutup_time,
			min_shutdown_time,
			x_0,
			t_0,
			p_0,
			coffi_a,
			coffi_b,
			coffi_c,
			coffi_cold_shutup_1,
			coffi_cold_shutup_2,
			coffi_cold_shutdown_1,
			coffi_cold_shutdown_2,
			Hg,
			Dg,
			Kg,
			Fg,
			Tg,
			Rg)
	end

	# units(Hg,Dg,Kg,Fg,Tg,Rg) = new(Hg,Dg,Kg,Fg,Tg,Rg)
	#
	# function unit(args...)
	#     new(index, p_max, p_min, ramp_up, ramp_down, shut_up, shut_down, min_shutup_time, min_shutdown_time,
	#         x_0, t_0, p_0, coffi_a, coffi_b, coffi_c, coffi_cold_shutup_1, coffi_cold_shutup_2, coffi_cold_shutdown_1, coffi_cold_shutdown_2, Hg, Dg, Kg, Fg, Tg, Rg, nothing)
	# end
end

struct transmissionline
	index::Vector{Int64}
	from::Vector{Int64}
	to::Vector{Int64}
	x::Vector{Float64}
	p_max::Vector{Float64}
	p_min::Vector{Float64}
	# b::Vector{Float64}
	# ratio::Vector{Int64}
	# transmissionline(from,to,x,b,p_max,p_min) = new(from,to,x,b,p_max,p_min)
	function transmissionline(index, from, to, x, p_max, p_min)
		return new(index, from, to, x, p_max, p_min)
	end
end

struct load
	index::Vector{Int64}
	locatebus::Vector{Int64}
	load_curve::Array{Float64}
	function load(index, locatebus, load_curve) # Using consistent constructor syntax
		return new(index, locatebus, load_curve)
	end
end

struct pss
	index::Vector{Int64}
	locatebus::Vector{Int64}
	Q_max::Vector{Float64}
	Q_min::Vector{Float64}
	p⁺::Vector{Float64}
	p⁻::Vector{Float64}
	P₀::Vector{Float64}
	γ⁺::Vector{Float64} # charging rate
	γ⁻::Vector{Float64} # dicharging rate
	η⁺::Vector{Float64} # charging efficiency
	η⁻::Vector{Float64} # discharge efficiency
	δₛ::Vector{Float64} # lossing efficiency
	function pss(index, locatebus, Q_max, Q_min, p⁺, p⁻, P₀, γ⁺, γ⁻, η⁺, η⁻, δₛ) # Corrected constructor name, also fixed p₀ -> P₀ to match definition
		return new(index, locatebus, Q_max, Q_min, p⁺, p⁻, P₀, γ⁺, γ⁻, η⁺, η⁻, δₛ) # Fixed p₀ -> P₀
	end
end

struct data_centra
	index::Vector{Int64}
	locatebus::Vector{Int64}
	p_max::Vector{Float64}
	p_min::Vector{Float64}
	voltage_regulation::Vector{Float64}
	idale::Vector{Float64}
	sv_constant::Vector{Float64}
	λ::Vector{Float64}
	μ::Vector{Float64}
	computational_power_tasks::Matrix{Float64}
	function data_centra(index, locatebus, p_max, p_min, voltage_regulation,
		idale, sv_constant, λ, μ, computational_power_tasks)
		return new(index, locatebus, p_max, p_min, voltage_regulation,
			idale, sv_constant, λ, μ, computational_power_tasks)
	end
end
