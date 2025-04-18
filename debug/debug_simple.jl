NG = 3
onoffinit = zeros(NG, 1)
Lupmin = zeros(NG, 1)     # Minimum startup time
Ldownmin = zeros(NG, 1)   # Minimum shutdown time
min_shutup_time = [3, 2, 1]
min_shutdown_time = [2, 3, 1]
NT = 24
for i in 1:NG
    # Uncomment if initial status is provided
    # onoffinit[i] = ((units.x_0[i, 1] > 0.5) ? 1 : 0)
    # Calculate minimum up/down time limits
    Lupmin[i] = min(NT, min_shutup_time[i] * onoffinit[i])
    Ldownmin[i] = min(NT, min_shutdown_time[i] * (1 - onoffinit[i]))
end

# Min up/down time
for i in 1:NG
    for t in Int64(max(1, Lupmin[i])):NT
        # base_name_con₁ = "units_min_up_time" * "_" * string(i) * "_" * string(t)
        LB = Int64(max(t - units.min_shutup_time[i, 1] + 1, 1))
        # @constraint(scuc, sum(u[i, r] for r in LB:t) <= x[i, t], base_name = base_name_con₁)
    end
end

# 	for t in Int64(max(1, Ldownmin[i])):NT
# 		base_name_con₂ = "units_min_down_time" * "_" * string(i) * "_" * string(t)
# 		LB = Int64(max(t - units.min_shutup_time[i] + 1, 1))
# 		@constraint(scuc, sum(v[i, r] for r in LB:t) <= (1 - x[i, t]), base_name = base_name_con₂)
# 	end
# end

# Define a placeholder for the units struct

# Calculate lower bounds for minimum up/down time constraints
LB_up = [Int64(max(t - min_shutup_time[i] + 1, 1)) for i in 1:NG, t in Int64(max(1, Lupmin[i])):NT]
LB_down = [Int64(max(t - min_shutdown_time[i] + 1, 1)) for i in 1:NG, t in Int64(max(1, Ldownmin[i])):NT]
