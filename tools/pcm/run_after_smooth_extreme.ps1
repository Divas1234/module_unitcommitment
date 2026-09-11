# 自动等待 1080u 168h smooth 完成后启动 1080u 168h extreme_ramp 对比计算
Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

Write-Host "[09/10/2026 09:46:33] Monitor script started. Waiting for smooth 1080u 168h benchmark to finish..."

$smoothDir = "D:\GithubClonefiles\module_unitcommitment\output\pcm_com4_loadall_h168_1080u_smooth"
$extremeDir = "D:\GithubClonefiles\module_unitcommitment\output\pcm_com4_loadall_h168_1080u_extreme"

# 检查当前 smooth 是否完成 (存在 catalog.csv 或 4 个方法的 metrics.csv 均已产出)
while ($true) {
    $covlMetrics = Join-Path $smoothDir "smooth\clu_ovl\r01\metrics.csv"
    $catalog = Join-Path $smoothDir "catalog.csv"
    $juliaProc = Get-Process julia -ErrorAction SilentlyContinue

    if (Test-Path $catalog) {
        Write-Host "[09/10/2026 09:46:33] Smooth suite catalog.csv detected! Proceeding to launch extreme ramp suite..."
        break
    }
    if ((Test-Path $covlMetrics) -and ($null -eq $juliaProc -or $juliaProc.Count -le 1)) {
        Write-Host "[09/10/2026 09:46:33] Clustered adaptive overlap metrics detected and solver idle! Proceeding to launch extreme ramp suite..."
        break
    }
    Start-Sleep -Seconds 60
}

Write-Host "[09/10/2026 09:46:33] Starting 1080u 168h Extreme Ramp Benchmark Suite..."

$env:PCM_INPUT_XLSX = 'data/data_118_clustered_pcm_10x.xlsx'
$env:PCM_INTERVALS = '7'
$env:PCM_WINDOW_HOURS = '24'
$env:PCM_BENCHMARK_PROFILES = 'extreme_ramp'
$env:PCM_BENCHMARK_METHODS = 'standard,clustered_pcm,adaptive_overlap,clustered_adaptive_overlap'
$env:PCM_SUITE_OUTPUT = $extremeDir
$env:PCM_BENCHMARK_RESUME = 'false'
$env:PCM_OVERLAP_MODE = 'ml_prediction'
$env:PCM_SOLVER_THREADS = '16'
$env:PCM_TRAINING_MODE = 'fast_max_overlap'

Set-Location "D:\GithubClonefiles\module_unitcommitment"
julia --project=pkg tools/pcm/run_pcm_suite.jl

Write-Host "[09/10/2026 09:46:33] 1080u 168h Extreme Ramp Benchmark Suite finished!"