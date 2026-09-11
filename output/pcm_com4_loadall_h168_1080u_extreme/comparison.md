# PCM 三方案统一计算结果与性能对比

- 输入：`D:\GithubClonefiles\module_unitcommitment\data\data_118_clustered_pcm_10x.xlsx`
- 场景：extreme_ramp
- 方法：standard, clustered_pcm, adaptive_overlap, clustered_adaptive_overlap
- 滚动范围：7 × 24 h
- 成本、耗时和内存均按重复实验中位数汇总；失败样本不参与成本中位数。

## 汇总指标

| profile | method | solver | successful_runs | success_rate_pct | median_simulation_time_sec | median_offline_training_time_sec | median_offline_preprocess_time_sec | median_wall_time_sec | median_peak_rss_mb | median_total_cost | speedup_vs_standard | cost_delta_pct | cluster_fallbacks | mean_overlap_hours | ramp_event_intervals | reference_repairs | mean_pre_repair_cost_gap_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| extreme_ramp | standard | gurobi | 0 | 0.0 | NA | 0.0 | 0.0 | NA | 5400.33203125 | 0.0 | NA | NA | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | clustered_pcm | gurobi | 0 | 0.0 | NA | 0.0 | 0.0 | NA | 5446.640625 | 0.0 | NA | NA | 2.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| extreme_ramp | adaptive_overlap | gurobi | 1 | 100.0 | 5392.209999799728 | 0.0 | 0.0 | 5437.8709271 | 7602.96875 | 3.188578695217e8 | NA | NA | 0.0 | 12.0 | 4.0 | 0.0 | 0.0 |
| extreme_ramp | clustered_adaptive_overlap | gurobi | 1 | 100.0 | 5638.888000249863 | 0.0 | 0.007999658584594727 | 5683.4113412 | 7678.98828125 | 3.188578695217e8 | NA | NA | 7.0 | 12.0 | 4.0 | 0.0 | 0.0 |

## 规模与降维

| profile | method | physical_units | equivalent_units | state_reduction_pct | median_integer_variables | integer_reduction_pct | median_allocated_mb | allocated_delta_pct |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| extreme_ramp | standard | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | NA | NA |
| extreme_ramp | clustered_pcm | 1080.0 | 31.0 | 97.12962962962963 | 2232.0 | 97.12962962962963 | NA | NA |
| extreme_ramp | adaptive_overlap | 1080.0 | 1080.0 | 0.0 | 77760.0 | 0.0 | 5.9451768948020935e6 | NA |
| extreme_ramp | clustered_adaptive_overlap | 1080.0 | 31.0 | 97.12962962962963 | 2232.0 | 97.12962962962963 | 6.053105770245552e6 | NA |

## clustered_pcm 关键中间过程

该表保留每次聚类主问题尝试及其后验解群校核结果；`failed` 表示该聚合解未通过物理单机路径校核，随后进入安全回退。

| profile | run | interval | attempt | physical_units | equivalent_units | state_reduction_pct | status | failure_stage | diagnostic |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| extreme_ramp | 1 | 1 | 1 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 1 | 2 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 1 | 3 | 1080 | 31 | 97.1 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 2 | 1 | 1080 | 34 | 96.9 | attempted |  |  |
| extreme_ramp | 1 | 2 | 2 | 1080 | 34 | 96.9 | attempted |  |  |
| extreme_ramp | 1 | 2 | 3 | 1080 | 34 | 96.9 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 1 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 2 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 3 | 1080 | 31 | 97.1 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 4 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 5 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 6 | 1080 | 31 | 97.1 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 7 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 8 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 9 | 1080 | 31 | 97.1 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 10 | 1080 | 32 | 97.0 | attempted |  |  |
| extreme_ramp | 1 | 0 | 11 | 1080 | 32 | 97.0 | attempted |  |  |
| extreme_ramp | 1 | 0 | 12 | 1080 | 32 | 97.0 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 13 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 14 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 15 | 1080 | 31 | 97.1 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 16 | 1080 | 36 | 96.7 | attempted |  |  |
| extreme_ramp | 1 | 0 | 17 | 1080 | 36 | 96.7 | attempted |  |  |
| extreme_ramp | 1 | 0 | 18 | 1080 | 36 | 96.7 | failed | cluster_master | INFEASIBLE |
| extreme_ramp | 1 | 0 | 19 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 20 | 1080 | 31 | 97.1 | attempted |  |  |
| extreme_ramp | 1 | 0 | 21 | 1080 | 31 | 97.1 | failed | cluster_master | INFEASIBLE |

## adaptive_overlap 关键中间过程

该表保留每个滚动区间的交叠窗决策来源、最终交叠长度和实际求解时域。

| profile | run | Interval_ID | Steady_State_Overlap_h | Unit_Dwell_Overlap_h | Ramp_Event_Detected | Ramp_Overlap_h | Limiting_Factor | Final_Adaptive_Overlap_h | Total_Solved_Horizon_h | Subproblem_SolveTime_sec | Optimization_Status |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| extreme_ramp | 1 | 1 | 12 | 0 | false | 0 | steady | 12 | 36 | 616.6640000343323 | OK |
| extreme_ramp | 1 | 2 | 12 | 4 | true | 12 | steady+ramp | 12 | 36 | 874.5500001907349 | OK |
| extreme_ramp | 1 | 3 | 12 | 0 | false | 0 | steady | 12 | 36 | 804.8120000362396 | OK |
| extreme_ramp | 1 | 4 | 12 | 4 | true | 12 | steady+ramp | 12 | 36 | 880.5139999389648 | OK |
| extreme_ramp | 1 | 5 | 12 | 0 | false | 0 | steady | 12 | 36 | 956.0089998245239 | OK |
| extreme_ramp | 1 | 6 | 12 | 4 | true | 12 | steady+ramp | 12 | 36 | 706.0749998092651 | OK |
| extreme_ramp | 1 | 7 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 551.1219999790192 | OK |
| extreme_ramp | 1 | 1 | 12 | 0 | false | 0 | steady | 12 | 36 | 644.3999998569489 | OK |
| extreme_ramp | 1 | 2 | 12 | 4 | true | 12 | steady+ramp | 12 | 36 | 895.1319999694824 | OK |
| extreme_ramp | 1 | 3 | 12 | 0 | false | 0 | steady | 12 | 36 | 825.5449998378754 | OK |
| extreme_ramp | 1 | 4 | 12 | 4 | true | 12 | steady+ramp | 12 | 36 | 908.9639999866486 | OK |
| extreme_ramp | 1 | 5 | 12 | 0 | false | 0 | steady | 12 | 36 | 984.4289999008179 | OK |
| extreme_ramp | 1 | 6 | 12 | 4 | true | 12 | steady+ramp | 12 | 36 | 771.4170000553131 | OK |
| extreme_ramp | 1 | 7 | 12 | 0 | true | 12 | steady+ramp | 12 | 36 | 606.5480000972748 | OK |

## 解释口径

- 存在 `integrated_uc` 时，成本误差以完整时域单机 UC 为基准；否则仅兼容性回退到 standard。
- `median_simulation_time_sec` 是在线 PCM 仿真时间；ML 训练和聚类预处理分别单列，不计入该指标。
- 聚类回退次数和 adaptive 的交叠窗来自各自运行日志/统计文件，不用缺失值替代。
- `reference_repairs` 表示组合方法因提交期物理成本偏差超限而采用单机参考解的窗口数；修复前偏差单独保留。

原始逐次计量见 `metrics.csv`，聚合结果见 `summary.csv`，相对基线结果见 `comparison.csv`。

