using Plots
gr()

methods = ["Standard", "Clustered", "Adaptive Overlap", "Clustered Overlap"]

# 1. 成功率对比 (1080机组, 3种负荷)
p1 = bar(
    methods,
    [100 100 100 100; 0 0 100 100; 0 0 100 100]',
    label=["Smooth" "Baseline" "Extreme Ramp"],
    title="1080-Unit 168h Benchmark Success Rate (%)",
    ylabel="Success Rate (%)",
    legend=:topleft,
    ylim=(0, 120),
    palette=:tab10,
    size=(900, 500)
)
savefig(p1, "output/benchmark_success_rate_1080u.png")

# 2. 求解耗时对比 (Wall Time in seconds)
times_smooth = [1487.7, 487.8, 3336.8, 957.2]
times_base = [0.0, 0.0, 3883.2, 4837.7]
times_extreme = [0.0, 0.0, 5437.9, 5683.4]

p2 = bar(
    methods,
    [times_smooth times_base times_extreme],
    label=["Smooth" "Baseline (Failed=0)" "Extreme Ramp (Failed=0)"],
    title="1080-Unit 168h Wall Time by Method (seconds)",
    ylabel="Wall Time (s)",
    legend=:topleft,
    palette=:tab10,
    size=(900, 500)
)
savefig(p2, "output/benchmark_walltime_1080u.png")

# 3. 成本对比 (万元 / 10k CNY)
cost_smooth = [29133.0, 28849.0, 28950.3, 28714.7]
cost_base = [0.0, 0.0, 30474.6, 30741.4]
cost_extreme = [0.0, 0.0, 31885.8, 31885.8]

p3 = bar(
    methods,
    [cost_smooth cost_base cost_extreme],
    label=["Smooth" "Baseline (Failed=0)" "Extreme Ramp (Failed=0)"],
    title="1080-Unit 168h System Total Cost (10k CNY)",
    ylabel="Total Cost (10k CNY)",
    legend=:topleft,
    palette=:tab10,
    size=(900, 500)
)
savefig(p3, "output/benchmark_cost_1080u.png")

println("English label charts regenerated successfully!")
