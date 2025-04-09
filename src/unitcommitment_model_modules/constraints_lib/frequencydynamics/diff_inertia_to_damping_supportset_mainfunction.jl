include("_automatic_workflow.jl")

const DROOP_PARAMETERS = collect(range(33, 40; length = 20))

function main_module(droop_parameter)
	p = generate_inertia_damping_figure(droop_parameter)
	~, sub_vertices = get_inertiatodamping_functions(droop_parameter)

	# 提取x和y坐标
	x_coords = [v[2] for v in sub_vertices]
	y_coords = [v[3] for v in sub_vertices]

	# 在原图上添加多面体
	plot!(p, x_coords, y_coords;
		  seriestype = :shape,
		  fillalpha = 0.2,
		  fillcolor = :red,
		  label = "Feasible Region")

	return p, sub_vertices
end

p1, sub_vertices = main_module(DROOP_PARAMETERS[1])
p2, sub_vertices = main_module(DROOP_PARAMETERS[4])
p3, sub_vertices = main_module(DROOP_PARAMETERS[6])
p4, sub_vertices = main_module(DROOP_PARAMETERS[10])

Plots.plot(p1, p2, p3, p4;
		   layout = (2, 2), size = (400, 400),
		   dpi = 400,
		   legend = false)

Plots.savefig(joinpath(pwd(), "fig/inertia_damping_feasible_region.png"))
Plots.savefig(joinpath(pwd(), "fig/inertia_damping_feasible_region.pdf"))
