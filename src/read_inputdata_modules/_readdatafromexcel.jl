using XLSX

function readxlssheet()
	println("Step-1: Pkgs and functions are loaded")
	filepath = pwd()
	# df = XLSX.readxlsx(filepath * "\\master-2\\case1\\data\\data.xlsx")
	if Sys.isapple()
		df = XLSX.readxlsx("/Users/yuanyiping/Documents/GitHub/module_unitcommitment/data/data.xlsx")
	elseif Sys.iswindows()
		df = XLSX.readxlsx("D:/GithubClonefiles/datacentra_unitcommitment/data/data.xlsx")
	end

	# part-1: read frequency data
	unitsfreqparam = df["units_frequencyparam"]
	windsfreqparam = df["winds_frequencyparam"]

	Sheet1_list = string("A2", ":", "G", string(size(unitsfreqparam[:], 1)))
	Sheet2_list = string("A2", ":", "F", string(size(windsfreqparam[:], 1)))

	unitsfreqparam = convert(Array{Float64, 2}, unitsfreqparam[Sheet1_list])
	windsfreqparam = convert(Array{Float64, 2}, windsfreqparam[Sheet2_list])

	# part-2: read stroge data
	strogesystemdata = df["strogesystem_data"]
	Sheet3_list = string("A2", ":", "L", string(size(strogesystemdata[:], 1)))
	strogesystemdata = convert(Array{Float64, 2}, strogesystemdata[Sheet3_list])

	# part-3: read conventional unit, network ,and load data
	gendata = df["units_data"]
	Sheet4_list = string("A2", ":", "N", string(size(gendata[:], 1)))
	gendata = convert(Array{Float64, 2}, gendata[Sheet4_list])

	gencost = df["units_cost"]
	Sheet5_list = string("A2", ":", "H", string(size(gencost[:], 1)))
	gencost = convert(Array{Float64, 2}, gencost[Sheet5_list])

	linedata = df["branch_data"]
	Sheet6_list = string("A2", ":", "E", string(size(linedata[:], 1)))
	linedata = convert(Array{Float64, 2}, linedata[Sheet6_list])

	loadcurve = df["load_curve"]
	Sheet7_list = string("A2", ":", "B", string(size(loadcurve[:], 1)))
	loadcurve = convert(Array{Float64, 2}, loadcurve[Sheet7_list])

	loaddata = df["load_data"]
	Sheet8_list = string("A2", ":", "C", string(size(loaddata[:], 1)))
	loaddata = convert(Array{Float64, 2}, loaddata[Sheet8_list])

	data_centra_data = df["data_centra"]
	Sheet9_list = string("A2", ":", "I", string(size(data_centra_data[:], 1)))
	data_centra_data = convert(Array{Float64, 2}, data_centra_data[Sheet9_list])

	hydropower_data = df["hydro_data"]
	Sheet10_list = string("A2", ":", "F", string(size(hydropower_data[:], 1)))
	hydropower_data = convert(Array{Float64, 2}, hydropower_data[Sheet10_list])

	hydropower_curve = df["hydro_seasoncurve"]
	Sheet10_list = string("A2", ":", "B", string(size(hydropower_curve[:], 1)))
	hydropower_curve = convert(Array{Float64, 2}, hydropower_curve[Sheet10_list])

	return unitsfreqparam, windsfreqparam, strogesystemdata, gendata, gencost, linedata,
    loadcurve, loaddata, data_centra_data, hydropower_data, hydropower_curve
end
