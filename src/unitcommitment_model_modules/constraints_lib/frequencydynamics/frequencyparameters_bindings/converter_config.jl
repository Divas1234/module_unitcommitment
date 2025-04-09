function converter_formming_configuations()
	# Define the converter configurations
	converter_config = Dict(
		"VSM" => Dict(
			"controller" => "VSM",
			"control_parameters" => Dict(
				"inertia" => 2,  # 添加VSM的惯量系数
				"damping" => 0.5,  # 添加VSM的阻尼
				"time_constant" => 0.05  # 统一时间系数
			)
		),
		"Droop" => Dict(
			"controller" => "P-Q",
			"control_parameters" => Dict(
				"droop" => 0.05,  # 添加Droop的系数
				"time_constant" => 0.01  # 统一时间系数
			)
		)
	)

	return converter_config
end
