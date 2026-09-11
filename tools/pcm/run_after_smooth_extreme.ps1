# 自动化全速流水线：跑满24线程 + fast_max_overlap
# 1. 续跑 smooth 工况剩余方法 (adaptive_overlap, clustered_adaptive_overlap)
# 2. 自动启动 extreme_ramp 极限爬坡工况全部4种方法对比
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$smoothDir = "D:\GithubClonefiles\module_unitcommitment\output\pcm_com4_loadall_h168_1080u_smooth"
$extremeDir = "D:\GithubClonefiles\module_unitcommitment\output\pcm_com4_loadall_h168_1080u_extreme"

Set-Location "D:\GithubClonefiles\module_unitcommitment"

Write-Host "=========================================================="
Write-Host ">>> [STEP 1/2] 启动 Smooth 工况剩余任务 (24线程跑满 + fast_max_overlap)"
Write-Host "=========================================================="

$env:PCM_INPUT_XLSX = 'data/data_118_clustered_pcm_10x.xlsx'
$env:PCM_INTERVALS = '7'
$env:PCM_WINDOW_HOURS = '24'
$env:PCM_BENCHMARK_PROFILES = 'smooth'
$env:PCM_BENCHMARK_METHODS = 'standard,clustered_pcm,adaptive_overlap,clustered_adaptive_overlap'
$env:PCM_SUITE_OUTPUT = $smoothDir
$env:PCM_BENCHMARK_RESUME = 'true'
$env:PCM_OVERLAP_MODE = 'ml_prediction'
$env:PCM_SOLVER_THREADS = '24'
$env:PCM_TRAINING_MODE = 'fast_max_overlap'

julia --project=pkg tools/pcm/run_pcm_suite.jl

Write-Host "=========================================================="
Write-Host ">>> [STEP 2/2] Smooth 完成，启动 Extreme Ramp 工况对比计算 (24线程跑满)"
Write-Host "=========================================================="

$env:PCM_INPUT_XLSX = 'data/data_118_clustered_pcm_10x.xlsx'
$env:PCM_INTERVALS = '7'
$env:PCM_WINDOW_HOURS = '24'
$env:PCM_BENCHMARK_PROFILES = 'extreme_ramp'
$env:PCM_BENCHMARK_METHODS = 'standard,clustered_pcm,adaptive_overlap,clustered_adaptive_overlap'
$env:PCM_SUITE_OUTPUT = $extremeDir
$env:PCM_BENCHMARK_RESUME = 'false'
$env:PCM_OVERLAP_MODE = 'ml_prediction'
$env:PCM_SOLVER_THREADS = '24'
$env:PCM_TRAINING_MODE = 'fast_max_overlap'

julia --project=pkg tools/pcm/run_pcm_suite.jl

Write-Host "=========================================================="
Write-Host ">>> 所有平滑与极限爬坡任务全部完成！触发邮件汇报通知..."
Write-Host "=========================================================="
python tools/monitoring/send_progress_email.py