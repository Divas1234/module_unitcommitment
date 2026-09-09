"""
PCM Benchmark Detailed Progress Monitor & Email Notifier (Upgraded)
-------------------------------------------------------------------
Automatically collects comprehensive benchmark progress, exact execution steps,
intermediate rolling interval checkpoints, solver telemetry, and system resource stats,
formats a crystal-clear engineering HTML report, and dispatches it to 1570364925@qq.com via SMTP.
Active broadcast window: 08:00 to 22:00 (every 3 hours: 08:00, 11:00, 14:00, 17:00, 20:00).
"""

import os
import re
import sys
import glob
import json
import ssl
import smtplib
import datetime
import subprocess
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from pathlib import Path

RECIPIENT_EMAIL = "1570364925@qq.com"
PROJECT_ROOT = Path(__file__).resolve().parents[2]
CONFIG_FILE = PROJECT_ROOT / "tools" / "monitoring" / "email_config.json"

PROFILES = ["baseline", "smooth", "extreme_ramp"]
METHODS = ["standard", "clustered_pcm", "adaptive_overlap", "clustered_adaptive_overlap"]

PROFILE_NAMES = {
    "baseline": "基准负荷 (Baseline)",
    "smooth": "平滑负荷 (Smooth)",
    "extreme_ramp": "极端强爬坡 (Extreme Ramp)",
    "base": "基准负荷 (Baseline)",
    "extreme": "极端强爬坡 (Extreme Ramp)",
}

METHOD_NAMES = {
    "standard": "Standard PCM (固定24h单机)",
    "clustered_pcm": "Clustered PCM (聚类机组固定窗)",
    "adaptive_overlap": "Adaptive Overlap (自适应交叠单机)",
    "clustered_adaptive_overlap": "Clustered Adaptive Overlap (聚类自适应交叠)",
    "std": "Standard PCM (固定24h单机)",
    "clu": "Clustered PCM (聚类机组固定窗)",
    "ovl": "Adaptive Overlap (自适应交叠单机)",
    "clu_ovl": "Clustered Adaptive Overlap (聚类自适应交叠)",
}


def is_in_active_window() -> bool:
    """Check if current time is within active broadcast hours (08:00 - 22:00)."""
    now = datetime.datetime.now().time()
    start_time = datetime.time(8, 0, 0)
    end_time = datetime.time(22, 0, 0)
    return start_time <= now <= end_time


def load_smtp_config():
    default_config = {
        "smtp_server": "smtp.qq.com",
        "smtp_port": 465,
        "use_ssl": True,
        "sender_email": "1570364925@qq.com",
        "sender_password": "zedxnxmyyooxgcah",
    }
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                default_config.update(cfg)
        except Exception:
            pass
    return default_config


def get_process_summary():
    """Extract detailed status for Julia and Gurobi solver processes."""
    processes = []
    try:
        cmd = 'Get-Process julia, gurobi* -ErrorAction SilentlyContinue | Select-Object Id, ProcessName, CPU, WorkingSet64 | ConvertTo-Json'
        res = subprocess.run(["powershell", "-NoProfile", "-Command", cmd], capture_output=True, text=True)
        if res.stdout.strip():
            data = json.loads(res.stdout)
            if isinstance(data, dict):
                data = [data]
            for p in data:
                cpu_sec = float(p.get("CPU", 0) or 0)
                mem_mb = float(p.get("WorkingSet64", 0) or 0) / (1024 * 1024)
                processes.append({
                    "id": p.get("Id"),
                    "name": p.get("ProcessName"),
                    "cpu_hours": f"{cpu_sec / 3600:.2f} 核·时 ({cpu_sec:,.0f}s)",
                    "mem_mb": f"{mem_mb:.1f} MB",
                })
    except Exception as e:
        print(f"Process check error: {e}")
    return processes


def parse_subtask_deep_details(run_dir: Path, total_intervals: int):
    """Deeply inspect a specific run directory to extract step-by-step rolling status."""
    sub_info = {
        "status": "QUEUED",
        "solve_time_sec": None,
        "total_cost": None,
        "intervals_done": 0,
        "total_intervals": total_intervals,
        "current_step_desc": "排队等待中",
        "latest_gurobi_metrics": {},
        "tail_lines": [],
    }

    metrics_file = run_dir / "metrics.csv"
    run_log = run_dir / "run.log"

    if metrics_file.exists():
        try:
            with open(metrics_file, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read().strip()
                lines = content.splitlines()
                if len(lines) > 1:
                    parts = lines[1].split(",")
                    run_status = parts[3] if len(parts) >= 4 else "SUCCESS"
                    sub_info["status"] = "COMPLETED"
                    sub_info["intervals_done"] = total_intervals
                    if len(parts) >= 8 and parts[7].strip():
                        try:
                            sub_info["solve_time_sec"] = float(parts[7])
                        except Exception:
                            pass
                    if len(parts) >= 23 and parts[22].strip():
                        try:
                            cost_val = float(parts[22])
                            sub_info["total_cost"] = f"{cost_val / 10000:.2f} 万元" if cost_val > 0 else "0.00"
                        except Exception:
                            pass
                    if run_status == "FAILED":
                        sub_info["current_step_desc"] = "计算完成：物理不可行 (传统PCM跨日断裂，验证算法局限)"
                        sub_info["total_cost"] = "不可行 (Infeasible)"
                    else:
                        sub_info["current_step_desc"] = f"已顺利求解完毕 (耗时: {sub_info['solve_time_sec'] or 0:.1f}s)"
                    return sub_info
        except Exception:
            pass

    if not run_log.exists():
        return sub_info

    # Parse in-progress run.log
    sub_info["status"] = "RUNNING"
    try:
        sim_res_dir = run_dir / "output" / "details_schedule_results" / "pcm_simulation_results"
        if sim_res_dir.exists():
            int_dirs = list(sim_res_dir.glob("intervels_[*]"))
            sub_info["intervals_done"] = len(int_dirs)

        with open(run_log, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
            sub_info["tail_lines"] = [l.strip() for l in lines[-8:] if l.strip()]
            full_text = "".join(lines[-250:])

            if "SAMPLING AND CALIBRATING ACCURACY LOSS MAPPING MODEL" in full_text or "sampling training will be conducted" in full_text:
                sub_info["current_step_desc"] = "【阶段1/3】离线交叠样本密集采样与 ML 模型标定中"
            elif "falling back to full unit-network SCUC" in full_text:
                sub_info["current_step_desc"] = f"【阶段2/3】滚动调度 (区间 {min(sub_info['intervals_done']+1, total_intervals)}/{total_intervals}) - 触发单机全尺寸 MILP 安全回退求解"
            elif "Clustered PCM:" in full_text and "virtual units" in full_text:
                sub_info["current_step_desc"] = f"【阶段2/3】滚动调度 (区间 {min(sub_info['intervals_done']+1, total_intervals)}/{total_intervals}) - 聚类降维主问题求解与解群校核中"
            elif "Starting PCM simulation" in full_text or "RUNNING" in full_text:
                sub_info["current_step_desc"] = f"【阶段2/3】滚动调度求解推进中 (第 {min(sub_info['intervals_done']+1, total_intervals)}/{total_intervals} 滚动区间)"
            else:
                sub_info["current_step_desc"] = f"【执行中】正在进行第 {min(sub_info['intervals_done']+1, total_intervals)}/{total_intervals} 滚动区间求解"

            times = re.findall(r"solve_time \(sec\)\s+:\s+([0-9\.e\+\-]+)", full_text)
            gaps = re.findall(r"relative_gap\s+:\s+([0-9\.e\+\-]+)", full_text)
            objs = re.findall(r"objective_value\s+:\s+([0-9\.e\+\-]+)", full_text)
            bounds = re.findall(r"objective_bound\s+:\s+([0-9\.e\+\-]+)", full_text)
            simplex = re.findall(r"simplex_iterations\s+:\s+([0-9]+)", full_text)
            vars_nt = re.findall(r"DEBUG set_objective_economic!:\s+NT=([0-9]+),\s+NG=([0-9]+)", full_text)

            if times and gaps:
                sub_info["latest_gurobi_metrics"] = {
                    "last_solve_time": float(times[-1]),
                    "last_gap_pct": float(gaps[-1]) * 100,
                    "last_obj": float(objs[-1]) if objs else None,
                    "last_bound": float(bounds[-1]) if bounds else None,
                    "simplex_iter": int(simplex[-1]) if simplex else None,
                    "active_nt_ng": f"NT={vars_nt[-1][0]}h, NG={vars_nt[-1][1]}台" if vars_nt else None,
                }
    except Exception as e:
        print(f"Error parsing {run_dir}: {e}")

    return sub_info


def parse_task_details(label: str, root_dir: Path, scale_desc: str, total_intervals: int):
    """Parse complete metrics, matrix grid, and micro-step telemetry."""
    task_info = {
        "label": label,
        "scale_desc": scale_desc,
        "dir_name": root_dir.name if root_dir.exists() else "Not Found",
        "status": "进行中",
        "total_subtasks": 12,
        "completed_subtasks": 0,
        "progress_pct": 0.0,
        "last_update": "无数据",
        "matrix": [],
        "active_subtask": None,
        "summary_table": [],
    }

    if not root_dir.exists():
        task_info["status"] = "未启动"
        return task_info

    comp_file = root_dir / "comparison.csv"
    if comp_file.exists():
        try:
            with open(comp_file, "r", encoding="utf-8", errors="ignore") as f:
                lines = f.readlines()
                if len(lines) > 1:
                    headers = [h.strip() for h in lines[0].split(",")]
                    for l in lines[1:]:
                        cols = [c.strip() for c in l.split(",")]
                        if len(cols) >= 6:
                            task_info["summary_table"].append(dict(zip(headers, cols)))
        except Exception:
            pass

    latest_mod_time = datetime.datetime.fromtimestamp(0)
    
    for prof in ["baseline", "smooth", "extreme_ramp"]:
        for meth in ["standard", "clustered_pcm", "adaptive_overlap", "clustered_adaptive_overlap"]:
            prof_slugs = [prof]
            if prof == "baseline":
                prof_slugs.extend(["base"])
            elif prof == "extreme_ramp":
                prof_slugs.extend(["ramp", "extreme", "ext_ramp"])
            elif prof == "smooth":
                prof_slugs.extend(["smo"])

            meth_slugs = [meth]
            if meth == "standard":
                meth_slugs.extend(["std"])
            elif meth == "clustered_pcm":
                meth_slugs.extend(["clu", "cluster"])
            elif meth == "adaptive_overlap":
                meth_slugs.extend(["ovl", "overlap"])
            elif meth == "clustered_adaptive_overlap":
                meth_slugs.extend(["clu_ovl", "clustered_overlap"])

            cand_dirs = [root_dir / ps / ms / "r01" for ps in prof_slugs for ms in meth_slugs]
            matched_dir = next((d for d in cand_dirs if d.exists()), cand_dirs[0])
            
            sub_res = parse_subtask_deep_details(matched_dir, total_intervals)
            
            item_entry = {
                "profile_key": prof,
                "profile_name": PROFILE_NAMES.get(prof, prof),
                "method_key": meth,
                "method_name": METHOD_NAMES.get(meth, meth),
                "status": sub_res["status"],
                "solve_time_sec": sub_res["solve_time_sec"],
                "total_cost": sub_res["total_cost"],
                "intervals_done": sub_res["intervals_done"],
                "total_intervals": sub_res["total_intervals"],
                "step_desc": sub_res["current_step_desc"],
                "metrics": sub_res["latest_gurobi_metrics"],
                "tail_lines": sub_res["tail_lines"],
            }
            
            if matched_dir.exists():
                for f in matched_dir.glob("*"):
                    mtime = datetime.datetime.fromtimestamp(f.stat().st_mtime)
                    if mtime > latest_mod_time:
                        latest_mod_time = mtime
                        
            if sub_res["status"] == "COMPLETED":
                task_info["completed_subtasks"] += 1
            elif sub_res["status"] == "RUNNING" and not task_info["active_subtask"]:
                task_info["active_subtask"] = item_entry

            task_info["matrix"].append(item_entry)

    task_info["progress_pct"] = (task_info["completed_subtasks"] / task_info["total_subtasks"]) * 100
    if task_info["completed_subtasks"] == task_info["total_subtasks"]:
        task_info["status"] = "100% 已全部完成"
    elif task_info["active_subtask"]:
        task_info["status"] = f"正在求解 ({task_info['completed_subtasks']}/12)"
    else:
        task_info["status"] = f"已归档 ({task_info['completed_subtasks']}/12)"

    if latest_mod_time.year > 2000:
        task_info["last_update"] = latest_mod_time.strftime("%Y-%m-%d %H:%M:%S")

    return task_info


def collect_all_tasks():
    tasks = []
    
    def select_best_dir(pattern: str):
        cands = glob.glob(pattern)
        if not cands:
            return None
        def get_score(d):
            p = Path(d)
            nm = len(list(p.glob("**/*metrics.csv")))
            nl = len(list(p.glob("**/*run.log")))
            return (nm, nl, p.stat().st_mtime)
        cands.sort(key=get_score, reverse=True)
        return Path(cands[0])

    # 1. 108 机组 72h (已完成基准)
    d108_72 = select_best_dir(str(PROJECT_ROOT / "output" / "pcm_com4_loadall_h72_20260822_092947"))
    if d108_72 and d108_72.exists():
        tasks.append(parse_task_details("118母线 / 108机组 72h 算例", d108_72, "3个滚动区间 (3×24h)，4方案×3场景共12组", 3))

    # 2. 108 机组 168h (已完成周级基准)
    d108_168 = select_best_dir(str(PROJECT_ROOT / ".worktrees" / "108_168h" / "output" / "pcm_com4_loadall_h168_*"))
    if not d108_168 or not d108_168.exists():
        d108_168 = select_best_dir(str(PROJECT_ROOT / "output" / "pcm_com4_loadall_h168_108u_final"))
    if d108_168 and d108_168.exists():
        tasks.append(parse_task_details("118母线 / 108机组 168h (周级) 算例", d108_168, "7个滚动区间 (7×24h=168h)，周级全周期调度", 7))

    # 3. 1080 机组 72h (已完成)
    d1080_72 = select_best_dir(str(PROJECT_ROOT / "output" / "pcm_com4_loadall_h72_20260822_094655"))
    if d1080_72 and d1080_72.exists():
        tasks.append(parse_task_details("118母线 / 1080机组 (10x规模) 72h 算例", d1080_72, "超大规模 1080 台机组全时域 MILP 滚动调度 (3×24h)", 3))

    # 4. 1080 机组 168h (平滑负荷专属聚焦算例)
    d1080_168_smooth = select_best_dir(str(PROJECT_ROOT / "output" / "pcm_com4_loadall_h168_1080u_smooth*"))
    if d1080_168_smooth and d1080_168_smooth.exists():
        tasks.append(parse_task_details("118母线 / 1080机组 168h (平滑负荷专属) 算例", d1080_168_smooth, "7个滚动区间 (7×24h=168h)，平滑负荷下 4 类 PCM 方案全景求解", 7))
    else:
        # 兜底旧工作区目录
        d1080_168 = select_best_dir(str(PROJECT_ROOT / ".worktrees" / "1080_168h" / "output" / "pcm_com4_loadall_h168_*"))
        if d1080_168 and d1080_168.exists():
            tasks.append(parse_task_details("118母线 / 1080机组 (10x规模) 168h (周级) 算例", d1080_168, "7个滚动区间 (7×24h=168h)，超大规模1080机组周级全周期调度", 7))

    return tasks


def generate_html_email(processes, tasks):
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Process table rows
    proc_html = ""
    for p in processes:
        proc_html += f"""
        <tr style="border-bottom: 1px solid #e2e8f0;">
            <td style="padding: 8px 12px; font-family: monospace; font-size: 13px;">{p['id']}</td>
            <td style="padding: 8px 12px; font-weight: bold; color: #2b6cb0; font-size: 13px;">{p['name']}</td>
            <td style="padding: 8px 12px; color: #c53030; font-weight: bold; font-size: 13px;">{p['cpu_hours']}</td>
            <td style="padding: 8px 12px; font-size: 13px;">{p['mem_mb']}</td>
        </tr>
        """
    if not proc_html:
        proc_html = "<tr><td colspan='4' style='padding: 12px; text-align: center; color: #718096;'>无活动求解进程</td></tr>"

    # Tasks HTML cards
    tasks_html = ""
    for t in tasks:
        is_done = t["completed_subtasks"] == t["total_subtasks"]
        border_color = "#38a169" if is_done else "#3182ce"
        header_bg = "#f0fff4" if is_done else "#ebf8ff"
        status_badge = f"<span style='background-color: {'#c6f6d5' if is_done else '#bee3f8'}; color: {'#22543d' if is_done else '#2b6cb0'}; padding: 4px 10px; border-radius: 12px; font-weight: bold; font-size: 12px;'>{t['status']}</span>"

        # Subtask matrix table rows
        matrix_rows = ""
        for m in t["matrix"]:
            if m["status"] == "COMPLETED":
                st_badge = "<span style='background: #e6fffa; color: #234e52; padding: 2px 6px; border-radius: 4px; font-size: 11px; font-weight: bold;'>✅ 求解完成</span>"
                cost_str = m["total_cost"] or "-"
                time_str = f"{m['solve_time_sec']:.1f}s" if m["solve_time_sec"] else "-"
                step_str = f"完成全部 {m['total_intervals']} 个滚动区间"
            elif m["status"] == "RUNNING":
                st_badge = "<span style='background: #feebc8; color: #744210; padding: 2px 6px; border-radius: 4px; font-size: 11px; font-weight: bold;'>🔄 正在执行</span>"
                cost_str = "计算中..."
                time_str = "运算中..."
                step_str = f"<b>{m['step_desc']}</b>"
            else:
                st_badge = "<span style='background: #edf2f7; color: #718096; padding: 2px 6px; border-radius: 4px; font-size: 11px;'>⏳ 排队等待</span>"
                cost_str = "-"
                time_str = "-"
                step_str = "排队等待前序方案完成"

            matrix_rows += f"""
            <tr style="border-bottom: 1px solid #edf2f7; font-size: 12px;">
                <td style="padding: 6px 10px; font-weight: 500;">{m['profile_name']}</td>
                <td style="padding: 6px 10px; color: #2d3748;">{m['method_name']}</td>
                <td style="padding: 6px 10px; text-align: center;">{st_badge}</td>
                <td style="padding: 6px 10px; color: #4a5568;">{step_str}</td>
                <td style="padding: 6px 10px; text-align: right; font-family: monospace;">{time_str}</td>
                <td style="padding: 6px 10px; text-align: right; font-family: monospace; font-weight: bold; color: #2b6cb0;">{cost_str}</td>
            </tr>
            """

        # Active subtask deep-dive section
        active_card = ""
        if t["active_subtask"]:
            act = t["active_subtask"]
            met = act.get("metrics", {})
            
            metric_tags = ""
            if met:
                if met.get("active_nt_ng"):
                    metric_tags += f"<div style='margin-bottom: 4px;'><b>📐 当前子模型规模:</b> <code style='background: #edf2f7; padding: 2px 6px; border-radius: 3px;'>{met['active_nt_ng']}</code></div>"
                if met.get("last_solve_time") is not None:
                    metric_tags += f"<div style='margin-bottom: 4px;'><b>⏱️ 最近窗口耗时:</b> <code style='color: #c53030; font-weight: bold;'>{met['last_solve_time']:.1f} 秒 ({met['last_solve_time']/60:.1f} 分钟)</code></div>"
                if met.get("last_gap_pct") is not None:
                    metric_tags += f"<div style='margin-bottom: 4px;'><b>🎯 MIP 相对间隙 (Gap):</b> <code style='color: #2b6cb0; font-weight: bold;'>{met['last_gap_pct']:.4f}%</code></div>"
                if met.get("simplex_iter") is not None:
                    metric_tags += f"<div style='margin-bottom: 4px;'><b>🔄 单纯形迭代步数:</b> <code>{met['simplex_iter']:,} 次</code></div>"
                if met.get("last_bound") is not None:
                    metric_tags += f"<div style='margin-bottom: 4px;'><b>📈 下界 Bound:</b> <code>{met['last_bound']:,.0f}</code></div>"

            log_box = ""
            if act.get("tail_lines"):
                log_box = f"""
                <div style="margin-top: 10px; background: #1a202c; color: #e2e8f0; padding: 10px; border-radius: 6px; font-family: Consolas, monospace; font-size: 11px; white-space: pre-wrap; line-height: 1.4; border-left: 3px solid #63b3ed;">
{'<br>'.join(act['tail_lines'])}
                </div>
                """

            active_card = f"""
            <div style="margin-top: 12px; background: #fffaf0; border: 1px solid #feebc8; border-radius: 6px; padding: 12px;">
                <div style="font-weight: bold; color: #c05621; font-size: 13px; margin-bottom: 6px;">
                    📍 当前正在执行的微观步骤: {act['profile_name']} → {act['method_name']}
                </div>
                <div style="font-size: 12px; color: #4a5568; line-height: 1.6;">
                    <div style="margin-bottom: 6px; font-size: 13px; color: #2d3748;"><b>当前状态:</b> {act['step_desc']}</div>
                    {metric_tags}
                </div>
                {log_box}
            </div>
            """

        tasks_html += f"""
        <div style="background: #ffffff; border: 1px solid #e2e8f0; border-left: 5px solid {border_color}; border-radius: 8px; margin-bottom: 24px; box-shadow: 0 2px 4px rgba(0,0,0,0.04); overflow: hidden;">
            <div style="background: {header_bg}; padding: 12px 16px; border-bottom: 1px solid #e2e8f0; display: flex; justify-content: space-between; align-items: center;">
                <div>
                    <h3 style="margin: 0; color: #2d3748; font-size: 15px;">{t['label']}</h3>
                    <div style="color: #718096; font-size: 12px; margin-top: 2px;">{t['scale_desc']} | 磁盘更新: <b>{t['last_update']}</b></div>
                </div>
                <div>{status_badge}</div>
            </div>
            
            <div style="padding: 16px;">
                <!-- Progress Bar -->
                <div style="margin-bottom: 14px;">
                    <div style="display: flex; justify-content: space-between; font-size: 12px; color: #4a5568; margin-bottom: 4px;">
                        <span><b>子算例总体完成度:</b> {t['completed_subtasks']}/12 ({t['progress_pct']:.1f}%)</span>
                        <span>{t['completed_subtasks']} 组完成 / {12 - t['completed_subtasks']} 组待完成</span>
                    </div>
                    <div style="background: #edf2f7; border-radius: 6px; height: 10px; overflow: hidden;">
                        <div style="background: {'#38a169' if is_done else '#3182ce'}; width: {t['progress_pct']}%; height: 100%;"></div>
                    </div>
                </div>

                <!-- 12 Subtask Matrix -->
                <table style="width: 100%; border-collapse: collapse; margin-top: 8px; border: 1px solid #edf2f7;">
                    <thead>
                        <tr style="background: #f7fafc; color: #4a5568; font-size: 11px; text-transform: uppercase;">
                            <th style="padding: 6px 10px; text-align: left;">场景 (Profile)</th>
                            <th style="padding: 6px 10px; text-align: left;">PCM 方案 (Method)</th>
                            <th style="padding: 6px 10px; text-align: center;">状态</th>
                            <th style="padding: 6px 10px; text-align: left;">具体执行步骤 / 进度</th>
                            <th style="padding: 6px 10px; text-align: right;">仿真耗时</th>
                            <th style="padding: 6px 10px; text-align: right;">总调度成本</th>
                        </tr>
                    </thead>
                    <tbody>
                        {matrix_rows}
                    </tbody>
                </table>

                {active_card}
            </div>
        </div>
        """

    html_content = f"""
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="utf-8">
        <style>
            body {{ font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif; background-color: #f7fafc; margin: 0; padding: 20px; color: #2d3748; }}
            .container {{ max-width: 960px; margin: 0 auto; background: #ffffff; border-radius: 10px; padding: 24px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }}
            h2 {{ color: #1a365d; border-bottom: 2px solid #e2e8f0; padding-bottom: 8px; margin-top: 0; }}
        </style>
    </head>
    <body>
        <div class="container">
            <h2>⚡ PCM 自动化基准测试 · 全量细分进度看板</h2>
            <div style="background-color: #ebf8ff; border-left: 4px solid #3182ce; padding: 10px 14px; margin-bottom: 20px; border-radius: 4px; font-size: 13px; color: #2b6cb0;">
                📅 <b>播报时间:</b> {now_str} &nbsp;|&nbsp; 
                🎯 <b>收件人:</b> {RECIPIENT_EMAIL} &nbsp;|&nbsp; 
                ⏱️ <b>播报周期:</b> 每天白天每 3 小时一次 (08:00~20:00)
            </div>

            <div style="margin-bottom: 24px;">
                <h3 style="color: #2c5282; font-size: 15px; margin-bottom: 8px;">🖥️ 求解引擎核心进程状态 (Julia & Gurobi)</h3>
                <table style="width: 100%; border-collapse: collapse; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 6px;">
                    <thead>
                        <tr style="background: #f7fafc; color: #4a5568; font-size: 12px;">
                            <th style="padding: 8px 12px; text-align: left;">进程 PID</th>
                            <th style="padding: 8px 12px; text-align: left;">程序名</th>
                            <th style="padding: 8px 12px; text-align: left;">累计 CPU 算力耗时</th>
                            <th style="padding: 8px 12px; text-align: left;">实时物理内存 (RSS)</th>
                        </tr>
                    </thead>
                    <tbody>
                        {proc_html}
                    </tbody>
                </table>
            </div>

            <h3 style="color: #2c5282; font-size: 15px; margin-bottom: 12px;">📊 四大算例轨道全景与微观执行步骤</h3>
            {tasks_html}

            <div style="margin-top: 24px; padding-top: 12px; border-top: 1px solid #e2e8f0; color: #a0aec0; font-size: 12px; text-align: center;">
                ModuleUnitCommitmentToolkit.jl · 自动化运维监控系统
            </div>
        </div>
    </body>
    </html>
    """
    return html_content


def send_email_report(force: bool = False):
    """Main execution function to collect metrics and dispatch SMTP email."""
    print(f"[{datetime.datetime.now()}] Collecting comprehensive PCM progress report...")

    if not force and not is_in_active_window():
        print(f"[{datetime.datetime.now()}] Current time outside active broadcast window (08:00 - 22:00). Skipping.")
        return

    processes = get_process_summary()
    tasks = collect_all_tasks()
    html_body = generate_html_email(processes, tasks)

    smtp_cfg = load_smtp_config()
    sender = smtp_cfg.get("sender_email", RECIPIENT_EMAIL)
    auth_code = smtp_cfg.get("sender_password", "zedxnxmyyooxgcah")

    msg = MIMEMultipart("alternative")
    msg["Subject"] = f"【PCM计算进度看板】{datetime.datetime.now().strftime('%m-%d %H:%M')} 全量细分步骤汇报"
    msg["From"] = f"PCM Benchmark Monitor <{sender}>"
    msg["To"] = RECIPIENT_EMAIL

    part_html = MIMEText(html_body, "html", "utf-8")
    msg.attach(part_html)

    tencent_ips = ["183.47.101.192", "14.18.245.164", "58.251.110.155", "183.60.62.24"]
    sent = False

    for ip in tencent_ips:
        try:
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE

            server = smtplib.SMTP_SSL(ip, 465, context=ctx, timeout=15)
            server.login(sender, auth_code)
            server.sendmail(sender, [RECIPIENT_EMAIL], msg.as_string())
            server.quit()
            print(f"[{datetime.datetime.now()}] SUCCESS: Email successfully sent to {RECIPIENT_EMAIL} (via {ip}:465)")
            sent = True
            break
        except Exception as e:
            print(f"Failed via IP {ip}: {e}")

    if not sent:
        try:
            ctx = ssl.create_default_context()
            ctx.check_hostname = False
            ctx.verify_mode = ssl.CERT_NONE
            server = smtplib.SMTP_SSL("smtp.qq.com", 465, context=ctx, timeout=15)
            server.login(sender, auth_code)
            server.sendmail(sender, [RECIPIENT_EMAIL], msg.as_string())
            server.quit()
            print(f"[{datetime.datetime.now()}] SUCCESS: Email successfully sent via smtp.qq.com")
        except Exception as e:
            print(f"[{datetime.datetime.now()}] ERROR: All SMTP attempts failed: {e}")


if __name__ == "__main__":
    force_run = "--force" in sys.argv
    send_email_report(force=force_run)
