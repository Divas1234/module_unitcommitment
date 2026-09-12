# 自动化全速流水线：跑满24线程 + fast_max_overlap
# 1080机组 168h 基准负荷 (baseline) 全4种方法对比计算
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$baseDir = "D:\GithubClonefiles\module_unitcommitment\output\pcm_com4_loadall_h168_1080u_baseline"

Set-Location "D:\GithubClonefiles\module_unitcommitment"

Write-Host "=========================================================="
Write-Host ">>> 启动 1080机组 168h Baseline 基准工况任务 (24线程跑满 + fast_max_overlap)"
Write-Host "=========================================================="

$env:PCM_INPUT_XLSX = 'data/data_118_clustered_pcm_10x.xlsx'
$env:PCM_INTERVALS = '7'
$env:PCM_WINDOW_HOURS = '24'
$env:PCM_BENCHMARK_PROFILES = 'baseline'
$env:PCM_BENCHMARK_METHODS = 'standard,clustered_pcm,adaptive_overlap,clustered_adaptive_overlap'
$env:PCM_SUITE_OUTPUT = $baseDir
$env:PCM_BENCHMARK_RESUME = 'true'
$env:PCM_OVERLAP_MODE = 'ml_prediction'
$env:PCM_SOLVER_THREADS = '24'
$env:PCM_TRAINING_MODE = 'fast_max_overlap'

julia --project=pkg tools/pcm/run_pcm_suite.jl

Write-Host "=========================================================="
Write-Host ">>> 1080机组 168h Baseline 基准工况计算完成！触发邮件汇报通知..."
Write-Host "=========================================================="
python tools/monitoring/send_progress_email.py