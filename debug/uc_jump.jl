!isdefined(scuc, :pg₀)

Δp_contingency = define_contingency_size(units, NG)
scuc = Model(Gurobi.Optimizer)

@variable(scuc, x[1:NG, 1:NT], Bin)
@variable(scuc, u[1:NG, 1:NT], Bin)
@variable(scuc, v[1:NG, 1:NT], Bin)

isdefined(scuc["x"])

scuc(scuc, :x)

@variable(scuc, x)

isempty(scuc[:q])

# Removed invalid function call
# JuMP.is_valid(scuc, x)

model_2 = Model();
JuMP.is_valid.(scuc, y)

@isdefined(k)

all_variables(scuc)

is_variable_in_set(x)

isdefined(scuc, :su₀) &&
return println("\t constraints: 4) Curtailment skipped (Δpd not defined)")

# continuous variables
@variable(scuc, pg₀[1:(NG * NS), 1:NT]>=0)
@variable(scuc, pgₖ[1:(NG * NS), 1:NT, 1:3]>=0)
@variable(scuc, su₀[1:NG, 1:NT]>=0)
@variable(scuc, sd₀[1:NG, 1:NT]>=0)
@variable(scuc, sr⁺[1:(NG * NS), 1:NT]>=0)
@variable(scuc, sr⁻[1:(NG * NS), 1:NT]>=0)
@variable(scuc, Δpd[1:(ND * NS), 1:NT]>=0)
@variable(scuc, Δpw[1:(NW * NS), 1:NT]>=0)
