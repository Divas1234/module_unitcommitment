# PCM 三方案统一计算结果与性能对比

- 输入：`D:\GithubClonefiles\module_unitcommitment\data\data_118_clustered_pcm_10x.xlsx`
- 场景：baseline
- 方法：standard, clustered_pcm, adaptive_overlap, clustered_adaptive_overlap
- 滚动范围：7 × 24 h
- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。

## 汇总指标

| profile | method | solver | successful_runs | success_rate_pct | median_simulation_time_sec | median_offline_training_time_sec | median_offline_preprocess_time_sec | median_wall_time_sec | median_peak_rss_mb | median_total_cost | speedup_vs_standard | cost_delta_pct | cluster_fallbacks | mean_overlap_hours | ramp_event_intervals | reference_repairs | mean_pre_repair_cost_gap_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | gurobi | 0 | 0.0 | NA | 0.0 | 0.0 | NA | 5296.08984375 | 0.0 | NA | NA | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_pcm | gurobi | 0 | 0.0 | NA | 0.0 | 0.0 | NA | 4947.53125 | 0.0 | NA | NA | 1.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| baseline | adaptive_overlap | gurobi | 1 | 100.0 | 3836.9040002822876 | 0.0 | 0.0 | 3883.2446002 | 7440.95703125 | 3.047461559790856e8 | NA | NA | 0.0 | 12.0 | 0.0 | 0.0 | 0.0 |
| baseline | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 4808.865000009537 | 0.0 | 0.10199999809265137 | 4837.6502592 | 10373.015625 | 3.0741356928977144e8 | NA | NA | 5.0 | 12.0 | 0.0 | 0.0 | 0.0 |

## 规模与降维

| profile | method | physical_units | equivalent_units | state_reduction_pct | median_integer_variables | integer_reduction_pct | median_allocated_mb | allocated_delta_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | standard | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | NA | NA |
| baseline | clustered_pcm | 1080.0 | 31.0 | 97.12962962962963 | 2232.0 | 97.12962962962963 | NA | NA |
| baseline | adaptive_overlap | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | 5.945165633971214e6 | NA |
| baseline | clustered_adaptive_overlap | 1080.0 | 31.0 | 97.12962962962963 | 2232.0 | 97.12962962962963 | 4.855368050963402e6 | NA |

## clustered_pcm 关键中间过程

该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。

| profile | run | interval | attempt | physical_units | equivalent_units | state_reduction_pct | status | failure_stage | diagnostic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 1 | 1080 | 31 | 97.1 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 2 | 1 | 1080 | 34 | 96.9 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| baseline | 1 | 3 | 1 | 1080 | 31 | 97.1 | attempted |  |  |
| baseline | 1 | 3 | 2 | 1080 | 31 | 97.1 | attempted |  |  |
| baseline | 1 | 3 | 3 | 1080 | 31 | 97.1 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 1 | 1080 | 31 | 97.1 | completed |  | ✓ True clustered UC completed (31 virtual units) |
| baseline | 1 | 0 | 2 | 1080 | 34 | 96.9 | completed |  | ✓ True clustered UC completed (34 virtual units) |
| baseline | 1 | 0 | 3 | 1080 | 31 | 97.1 | attempted |  |  |
| baseline | 1 | 0 | 4 | 1080 | 31 | 97.1 | attempted |  |  |
| baseline | 1 | 0 | 5 | 1080 | 31 | 97.1 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 6 | 1080 | 38 | 96.5 | attempted |  |  |
| baseline | 1 | 0 | 7 | 1080 | 38 | 96.5 | attempted |  |  |
| baseline | 1 | 0 | 8 | 1080 | 38 | 96.5 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 9 | 1080 | 31 | 97.1 | attempted |  |  |
| baseline | 1 | 0 | 10 | 1080 | 31 | 97.1 | attempted |  |  |
| baseline | 1 | 0 | 11 | 1080 | 31 | 97.1 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 12 | 1080 | 31 | 97.1 | attempted |  |  |
| baseline | 1 | 0 | 13 | 1080 | 31 | 97.1 | attempted |  |  |
| baseline | 1 | 0 | 14 | 1080 | 31 | 97.1 | failed | cluster_master | INFEASIBLE |
| baseline | 1 | 0 | 15 | 1080 | 31 | 97.1 | attempted |  |  |
| baseline | 1 | 0 | 16 | 1080 | 31 | 97.1 | attempted |  |  |
| baseline | 1 | 0 | 17 | 1080 | 31 | 97.1 | attempted |  |  |
| baseline | 1 | 0 | 18 | 1080 | 110 | 89.8 | attempted |  |  |
| baseline | 1 | 0 | 19 | 1080 | 129 | 88.1 | attempted |  |  |
| baseline | 1 | 0 | 20 | 1080 | 168 | 84.4 | attempted |  |  |
| baseline | 1 | 0 | 21 | 1080 | 187 | 82.7 | attempted |  |  |
| baseline | 1 | 0 | 22 | 1080 | 206 | 80.9 | attempted |  |  |
| baseline | 1 | 0 | 23 | 1080 | 305 | 71.8 | attempted |  |  |
| baseline | 1 | 0 | 24 | 1080 | 364 | 66.3 | attempted |  |  |
| baseline | 1 | 0 | 25 | 1080 | 383 | 64.5 | failed | physical_disaggregation | physical fleet cannot follow clustered total-power trajectory; lines=Int64[], periods=[9, 20, 22], deviations=3 |

## adaptive_overlap 关键中间过程

该表保留每个滚动区间的交叠窗决策来源、最终交叠长度和实际求解时域。

| profile | run | Interval_ID | Steady_State_Overlap_h | Unit_Dwell_Overlap_h | Ramp_Event_Detected | Ramp_Overlap_h | Limiting_Factor | Final_Adaptive_Overlap_h | Total_Solved_Horizon_h | Subproblem_SolveTime_sec | Optimization_Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| baseline | 1 | 1 | 12 | 0 | false | 0 | steady | 12 | 36 | 742.1870000362396 | OK |
| baseline | 1 | 2 | 12 | 4 | false | 0 | steady | 12 | 36 | 639.1510000228882 | OK |
| baseline | 1 | 3 | 12 | 0 | false | 0 | steady | 12 | 36 | 517.7180001735687 | OK |
| baseline | 1 | 4 | 12 | 7 | false | 0 | steady | 12 | 36 | 507.87000012397766 | OK |
| baseline | 1 | 5 | 12 | 0 | false | 0 | steady | 12 | 36 | 546.7769999504089 | OK |
| baseline | 1 | 6 | 12 | 0 | false | 0 | steady | 12 | 36 | 442.577999830246 | OK |
| baseline | 1 | 7 | 12 | 0 | false | 0 | steady | 12 | 36 | 437.82800006866455 | OK |
| baseline | 1 | 1 | 12 | 0 | false | 0 | steady | 12 | 36 | 37.48099994659424 | OK |
| baseline | 1 | 2 | 12 | 3 | false | 0 | steady | 12 | 36 | 27.384999990463257 | OK |
| baseline | 1 | 3 | 12 | 0 | false | 0 | steady | 12 | 36 | 614.029000043869 | OK |
| baseline | 1 | 4 | 12 | 7 | false | 0 | steady | 12 | 36 | 455.8619999885559 | OK |
| baseline | 1 | 5 | 12 | 0 | false | 0 | steady | 12 | 36 | 580.6930000782013 | OK |
| baseline | 1 | 6 | 12 | 0 | false | 0 | steady | 12 | 36 | 804.0490000247955 | OK |
| baseline | 1 | 7 | 12 | 0 | false | 0 | steady | 12 | 36 | 2287.906000137329 | OK |

## 解释口径

- 存在 `integrated_uc` 时，成本误差以完整时域单机 UC 为基准；否则仅兼容性回退到 standard。
- `median_simulation_time_sec` 是在线 PCM 仿真时间；ML 训练和聚类预处理分别单列，不计入该指标。
- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。
- `reference_repairs` 表示组合方法因提交期物理成本偏差超限而采用单机参考解的窗口数；修复前偏差单独保留。

原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。

