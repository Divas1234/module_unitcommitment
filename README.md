# Datacentra Unit Commitment

## Table of Contents
1. [Description](#description)
2. [Usage](#usage)
3. [Files](#files)
4. [License](#license)

## Description

This project implements a unit commitment model for a power system integrated with datacenters, aiming to optimize the commitment and dispatch of generation units while considering the power consumption characteristics of datacenters. The model considers various factors such as generation costs, transmission constraints, renewable energy integration, and datacenter operational requirements to provide cost-effective and reliable power system operation.


## Usage

1.  **Prerequisites:**
    *   Ensure you have Julia installed (version 1.6 or higher is recommended). You can download it from the official Julia website: [https://julialang.org/downloads/](https://julialang.org/downloads/)
    *   Install the required Julia packages by running `] instantiate` in the Julia REPL within the project directory. This will install all dependencies listed in the `Project.toml` file.
2.  **Activating the Environment:**
    *   Open a Julia REPL (interactive session) in the project directory.
    *   Activate the project environment using the command: `julia --project=.` or `julia -p auto --project=.`
3.  **Running the Model:**
    *   Execute the main script: `julia main_function.jl`
    *   Alternatively, you can run the script from within the Julia REPL using `include("main_function.jl")`


##

## Files

*   `mainfun.jl`: Main script to run the unit commitment model.
*   `src/environment_config.jl`: Includes environment configurations.
*   `src/formatteddata.jl`: Formats the input data.
*   `src/renewableenergysimulation.jl`: Simulates renewable energy sources.
*   `src/showboundarycase.jl`: Shows boundary cases.
*   `src/readdatafromexcel.jl`: Reads data from Excel sheets.
*   `src/SUCuccommitmentmodel.jl`: Implements the SUC-SCUC model.
*   `src/casesplotting.jl`: Plots the cases.
*   `src/saveresult.jl`: Saves the results.
*   `src/generatefittingparameters.jl`: Generates fitting parameters.
*   `src/draw_onlineactivepowerbalance.jl`: Draws online active power balance.
*   `src/draw_addditionalpower.jl`: Draws additional power.

## Dependencies

The project depends on the following Julia packages:

*   CSV
*   Clustering
*   DataFrames
*   DelimitedFiles
*   Distributions
*   Gurobi
*   JLD
*   JuMP
*   LaTeXStrings
*   MultivariateStats
*   PlotlyJS
*   Plots
*   Revise
*   StatsPlots
*   Test
*   XLSX

## Files

*   `main_function.jl`: Main script to run the unit commitment model.
*   `src/environment_config.jl`: Includes environment configurations.
*   `src/read_inputdata_modules/_formatteddata.jl`: Formats the input data.
*   `src/read_inputdata_modules/_readdatafromexcel.jl`: Reads data from Excel sheets.
*   `src/read_inputdata_modules/_showboundrycase.jl`: Shows boundary cases.
*   `src/read_inputdata_modules/readdatas.jl`: Reads data.
*   `src/renewableresource_modules/_renewableenergysimulation.jl`: Simulates renewable energy sources.
*   `src/renewableresource_modules/stochasticsimulation.jl`: Performs stochastic simulations.
*   `src/unitcommitment_model_modules/SUCuccommitmentmodel.jl`: Implements the SUC-SCUC model.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_datacentra.jl`: Defines constraints for datacenters.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_frequencydynamic.jl`: Defines frequency dynamic constraints.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_generator.jl`: Defines generator constraints.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_network.jl`: Defines network constraints.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_storage.jl`: Defines storage constraints.
*   `src/unitcommitment_model_modules/constraints_lib/_constraint_systemwide.jl`: Defines system-wide constraints.
*   `src/unitcommitment_model_modules/constraints_lib/_constraints_generatefittingparameters.jl`: Generates fitting parameters constraints.
*   `src/unitcommitment_model_modules/constraints_lib/constraints.jl`: Includes constraint definitions.
*   `src/unitcommitment_model_modules/objectives_lib/_objective_econimic.jl`: Defines the economic objective.
*   `src/unitcommitment_model_modules/objectives_lib/objections.jl`: Includes objective definitions.
*   `src/unitcommitment_model_modules/tests_lib/_validata_input.jl`: Validates input data.
*   `src/unitcommitment_model_modules/tests_lib/tests.jl`: Includes test functions.
*   `src/unitcommitment_model_modules/utilitie_modules_lib/_define_decision_variables.jl`: Defines decision variables.
*   `src/unitcommitment_model_modules/utilitie_modules_lib/_export_res_to_txtfiles.jl`: Exports results to text files.
*   `src/unitcommitment_model_modules/utilitie_modules_lib/_linearization.jl`: Implements linearization techniques.
*   `src/unitcommitment_model_modules/utilitie_modules_lib/utilities.jl`: Includes utility functions.
*   `src/visualization_modules/casesploting.jl`: Plots the cases.
*   `src/visualization_modules/draw_addditionalpower.jl`: Draws additional power.
*   `src/visualization_modules/draw_onlineactivepowerbalance.jl`: Draws online active power balance.

## License

This project is licensed under the [MIT License](LICENSE). See the `LICENSE` file for details.