# PCM 三方案统一计算结果与性能对比

- 输入：`D:\GithubClonefiles\module_unitcommitment\data\data_118_clustered_pcm_10x.xlsx`
- 场景：smooth
- 方法：standard, clustered_pcm, adaptive_overlap, clustered_adaptive_overlap
- 滚动范围：7 × 24 h
- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。

## 汇总指标

| profile | method | solver | successful_runs | success_rate_pct | median_simulation_time_sec | median_offline_training_time_sec | median_offline_preprocess_time_sec | median_wall_time_sec | median_peak_rss_mb | median_total_cost | speedup_vs_standard | cost_delta_pct | cluster_fallbacks | mean_overlap_hours | ramp_event_intervals | reference_repairs | mean_pre_repair_cost_gap_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| smooth | standard | gurobi | 1 | 100.0 | 1471.9229998588562 | 0.0 | 0.0 | 1487.6989996 | 5437.40234375 | 2.9133028376351e8 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | clustered_pcm | gurobi | 1 | 100.0 | 463.3710000514984 | 0.0 | 0.003000020980834961 | 487.7918282 | 5368.4453125 | 2.8849029717408e8 | 3.176553991715642 | -0.9748339763178793 | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| smooth | adaptive_overlap | gurobi | 1 | 100.0 | 3308.255000114441 | 0.0 | 0.0 | 3336.8006648 | 7375.69921875 | 2.8950270790195566e8 | 0.444924287821809 | -0.6273209355186271 | 0.0 | 12.0 | 0.0 | 0.0 | 0.0 |
| smooth | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 912.3700006008148 | 0.0 | 0.003000020980834961 | 957.2414142 | 7381.76953125 | 2.8714670061565876e8 | 1.6132961396029724 | -1.436027553952235 | 1.0 | 12.0 | 0.0 | 0.0 | 0.0 |

## 规模与降维

| profile | method | physical_units | equivalent_units | state_reduction_pct | median_integer_variables | integer_reduction_pct | median_allocated_mb | allocated_delta_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| smooth | standard | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | 2.8491315142412186e6 | 0.0 |
| smooth | clustered_pcm | 1080.0 | 31.0 | 97.12962962962963 | 2232.0 | 97.12962962962963 | 475569.000500679 | -83.30828190543066 |
| smooth | adaptive_overlap | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | 5.945167283031464e6 | 108.66594796747324 |
| smooth | clustered_adaptive_overlap | 1080.0 | 31.0 | 97.12962962962963 | 2232.0 | 97.12962962962963 | 955417.751083374 | -66.46635136680165 |

## clustered_pcm 关键中间过程

该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。

| profile | run | interval | attempt | physical_units | equivalent_units | state_reduction_pct | status | failure_stage | diagnostic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| smooth | 1 | 1 | 1 | 1080 | 31 | 97.1 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 2 | 1 | 1080 | 34 | 96.9 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| smooth | 1 | 3 | 1 | 1080 | 33 | 96.9 | completed |  | ✓ True clustered UC completed (33 virtual units) |
| smooth | 1 | 4 | 1 | 1080 | 34 | 96.9 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| smooth | 1 | 5 | 1 | 1080 | 33 | 96.9 | completed |  | ✓ True clustered UC completed (33 virtual units) |
| smooth | 1 | 6 | 1 | 1080 | 34 | 96.9 | attempted |  |  |
| smooth | 1 | 6 | 2 | 1080 | 34 | 96.9 | attempted |  |  |
| smooth | 1 | 6 | 3 | 1080 | 34 | 96.9 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 7 | 1 | 1080 | 31 | 97.1 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 1 | 1080 | 31 | 97.1 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| smooth | 1 | 0 | 2 | 1080 | 36 | 96.7 | completed |  | ✓ True clustered UC completed (36 virtual units) |
| smooth | 1 | 0 | 3 | 1080 | 32 | 97.0 | completed |  | ✓ True clustered UC completed (32 virtual units) |
| smooth | 1 | 0 | 4 | 1080 | 34 | 96.9 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| smooth | 1 | 0 | 5 | 1080 | 33 | 96.9 | completed |  | ✓ True clustered UC completed (33 virtual units) |
| smooth | 1 | 0 | 6 | 1080 | 35 | 96.8 | attempted |  |  |
| smooth | 1 | 0 | 7 | 1080 | 35 | 96.8 | attempted |  |  |
| smooth | 1 | 0 | 8 | 1080 | 35 | 96.8 | failed | cluster_master | INFEASIBLE |
| smooth | 1 | 0 | 9 | 1080 | 33 | 96.9 | completed |  | ✓ True clustered UC completed (33 virtual units) |

## adaptive_overlap 关键中间过程

该表保留每个滚动区间的交叠窗决策来源、最终交叠长度和实际求解时域。

| profile | run | Interval_ID | Steady_State_Overlap_h | Unit_Dwell_Overlap_h | Ramp_Event_Detected | Ramp_Overlap_h | Limiting_Factor | Final_Adaptive_Overlap_h | Total_Solved_Horizon_h | Subproblem_SolveTime_sec | Optimization_Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| smooth | 1 | 1 | 12 | 0 | false | 0 | steady | 12 | 36 | 480.9099998474121 | OK |
| smooth | 1 | 2 | 12 | 0 | false | 0 | steady | 12 | 36 | 471.2809998989105 | OK |
| smooth | 1 | 3 | 12 | 3 | false | 0 | steady | 12 | 36 | 461.04500007629395 | OK |
| smooth | 1 | 4 | 12 | 0 | false | 0 | steady | 12 | 36 | 476.46599984169006 | OK |
| smooth | 1 | 5 | 12 | 4 | false | 0 | steady | 12 | 36 | 462.2480001449585 | OK |
| smooth | 1 | 6 | 12 | 0 | false | 0 | steady | 12 | 36 | 507.6410000324249 | OK |
| smooth | 1 | 7 | 12 | 7 | false | 0 | steady | 12 | 36 | 447.00600004196167 | OK |
| smooth | 1 | 1 | 12 | 0 | false | 0 | steady | 12 | 36 | 103.9430000782013 | OK |
| smooth | 1 | 2 | 12 | 5 | false | 0 | steady | 12 | 36 | 54.569000005722046 | OK |
| smooth | 1 | 3 | 12 | 3 | false | 0 | steady | 12 | 36 | 51.36400008201599 | OK |
| smooth | 1 | 4 | 12 | 1 | false | 0 | steady | 12 | 36 | 50.045000076293945 | OK |
| smooth | 1 | 5 | 12 | 3 | false | 0 | steady | 12 | 36 | 56.610000133514404 | OK |
| smooth | 1 | 6 | 12 | 7 | false | 0 | steady | 12 | 36 | 543.6080000400543 | OK |
| smooth | 1 | 7 | 12 | 3 | false | 0 | steady | 12 | 36 | 49.91199994087219 | OK |

## 解释口径

- 存在 `integrated_uc` 时，成本误差以完整时域单机 UC 为基准；否则仅兼容性回退到 standard。
- `median_simulation_time_sec` 是在线 PCM 仿真时间；ML 训练和聚类预处理分别单列，不计入该指标。
- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。
- `reference_repairs` 表示组合方法因提交期物理成本偏差超限而采用单机参考解的窗口数；修复前偏差单独保留。

原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。

