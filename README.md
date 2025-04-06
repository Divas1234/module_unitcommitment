# Datacentra Unit Commitment

This project implements a unit commitment model for a power system with datacenters.

## Usage

1.  Ensure you have Julia installed.
2.  Activate the project environment: `julia --project=.`
3.  Run the main script: `julia mainfun.jl`

## Description

The `mainfun.jl` script reads data from an Excel sheet, formulates input data for the model, generates wind scenarios, applies boundary conditions, runs the SUC-SCUC model, and saves the results to CSV files.

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