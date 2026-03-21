"""HTML template, HTTP server, file watching, and watch-mode for sprint-status.

This module contains:
- DASHBOARD_HTML constant (inline HTML/CSS/JS for the web dashboard)
- render_html() — returns the live dashboard page
- find_watched_files() — lists files relevant for change detection
- LiveServer class — HTTP server with file-watching auto-refresh
"""

from __future__ import annotations

import json
import sys
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from typing import Any, Dict, List

from dashboard_render import collect_data, find_file


# ─── File Watching ────────────────────────────────────────────────────────────

def find_watched_files(root: Path) -> List[Path]:
    """Return only the files that matter for dashboard data (not all *.md)."""
    files = []
    for name in ["TRACKING.md", "Roadmap.md", "CODING_GUARDRAILS.md",
                  "SPRINT-INDEX.md", "Docs/CODING_GUARDRAILS.md", "Docs/SPRINT-INDEX.md"]:
        f = root / name
        if f.is_file():
            files.append(f)
        else:
            found = find_file(root, name.split("/")[-1])
            if found:
                files.append(found)
    # hooks-config + individual hook scripts
    hc = root / ".claude" / "hooks-config.sh"
    if hc.is_file():
        files.append(hc)
    hooks_dir = root / ".claude" / "hooks"
    if hooks_dir.is_dir():
        files.extend(f for f in hooks_dir.iterdir() if f.suffix == ".sh")
    # validation script
    vs = root / "validation" / "validate-structure.sh"
    if vs.is_file():
        files.append(vs)
    for p in root.glob("**/*GATE*.md"):
        files.append(p)
    for p in root.glob("**/*SPRINT_CLOSE*.md"):
        files.append(p)
    if root.parent != root:
        parent = root.parent
        for p in parent.glob("*GATE*.md"):
            files.append(p)
        for p in parent.glob("*/*GATE*.md"):
            files.append(p)
        for p in parent.glob("*SPRINT_CLOSE*.md"):
            files.append(p)
        for p in parent.glob("*/*SPRINT_CLOSE*.md"):
            files.append(p)
    return files


# ─── HTML Dashboard ──────────────────────────────────────────────────────────

DASHBOARD_HTML = r"""<!DOCTYPE html>
<html lang="en"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Sprint Dashboard</title>
<style>
:root{--bg:#0d1117;--bg2:#161b22;--bg3:#21262d;--border:#30363d;--text:#e6edf3;--text2:#8b949e;--green:#3fb950;--yellow:#d29922;--red:#f85149;--blue:#58a6ff;--cyan:#39d2c0;--magenta:#bc8cff;--orange:#f0883e}
@media(prefers-color-scheme:light){:root{--bg:#fff;--bg2:#f6f8fa;--bg3:#eaeef2;--border:#d0d7de;--text:#1f2328;--text2:#656d76;--green:#1a7f37;--yellow:#9a6700;--red:#cf222e;--blue:#0969da;--cyan:#1b7c83;--magenta:#8250df;--orange:#bc4c00}}
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;background:var(--bg);color:var(--text);line-height:1.5;padding:2rem;max-width:1600px;margin:0 auto}
h1{font-size:1.5rem;margin-bottom:.25rem}
.subtitle{font-size:1rem;color:var(--text2);margin-bottom:1rem;display:flex;align-items:center;gap:.5rem}
.live-dot{width:8px;height:8px;border-radius:50%;background:var(--green);animation:pulse 2s infinite;display:none}
.live .live-dot{display:inline-block}
@keyframes pulse{0%,100%{opacity:1}50%{opacity:.3}}
.layout{display:flex;gap:1.5rem;margin-top:1.5rem;align-items:flex-start}
.sidebar{flex:0 0 220px;position:sticky;top:2rem;max-height:calc(100vh - 4rem);overflow-y:auto}
.sidebar::-webkit-scrollbar{width:4px}.sidebar::-webkit-scrollbar-thumb{background:var(--border);border-radius:2px}
.main{flex:1;min-width:0}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(340px,1fr));gap:1rem}
@media(max-width:768px){.layout{flex-direction:column}.sidebar{position:static;flex:none;width:100%;max-height:none}}
.card{background:var(--bg2);border:1px solid var(--border);border-radius:8px;padding:1.25rem}
.card-title{font-size:.8rem;text-transform:uppercase;letter-spacing:.05em;color:var(--text2);margin-bottom:.75rem}
.full{grid-column:1/-1}
.scroll-box{max-height:280px;overflow-y:auto;scrollbar-width:thin;scrollbar-color:var(--border) transparent}
.scroll-box::-webkit-scrollbar{width:4px}.scroll-box::-webkit-scrollbar-thumb{background:var(--border);border-radius:2px}
.show-more{display:inline-block;font-size:.75rem;color:var(--blue);cursor:pointer;padding:.35rem 0;border:none;background:none}
.show-more:hover{text-decoration:underline}

/* Progress Ring */
.progress-wrap{display:flex;align-items:center;gap:1.5rem}
.ring{position:relative;width:80px;height:80px}
.ring svg{transform:rotate(-90deg)}
.ring circle{fill:none;stroke-width:6;stroke-linecap:round}
.ring .bg{stroke:var(--bg3)}.ring .fg{stroke:var(--green);transition:stroke-dashoffset .6s}
.ring .pct{position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);font-size:1.25rem;font-weight:700}
.stats{display:flex;flex-wrap:wrap;gap:.5rem 1rem}
.stat{display:flex;align-items:center;gap:.35rem;font-size:.85rem}
.dot{width:8px;height:8px;border-radius:50%;display:inline-block}

/* Gates */
.gate-row{display:flex;align-items:center;gap:0}
.gate{flex:1;text-align:center;padding:.75rem .5rem;position:relative;font-size:.85rem}
.gate::after{content:'';position:absolute;top:50%;right:0;width:2rem;height:2px;background:var(--border);transform:translateX(50%)}
.gate:last-child::after{display:none}
.gate-icon{width:32px;height:32px;border-radius:50%;display:inline-flex;align-items:center;justify-content:center;margin-bottom:.25rem;font-size:.9rem}
.g-ok .gate-icon{background:var(--green);color:#fff}
.g-wip .gate-icon{background:var(--yellow);color:#fff}
.g-no .gate-icon{background:var(--bg3);color:var(--text2)}
.gate-lbl{font-size:.75rem;color:var(--text2)}

/* Tables */
table{width:100%;font-size:.85rem;border-collapse:collapse}
th{text-align:left;font-weight:600;padding:.5rem .75rem;border-bottom:1px solid var(--border);color:var(--text2);font-size:.75rem;text-transform:uppercase}
td{padding:.5rem .75rem;border-bottom:1px solid var(--border);vertical-align:top}
tr:last-child td{border-bottom:none}
.badge{display:inline-block;padding:.15rem .5rem;border-radius:12px;font-size:.75rem;font-weight:500}
.b-verified{background:color-mix(in srgb,var(--green) 15%,transparent);color:var(--green)}
.b-fixed{background:color-mix(in srgb,var(--cyan) 15%,transparent);color:var(--cyan)}
.b-in_progress{background:color-mix(in srgb,var(--yellow) 15%,transparent);color:var(--yellow)}
.b-open{background:color-mix(in srgb,var(--text2) 15%,transparent);color:var(--text2)}
.b-blocked{background:color-mix(in srgb,var(--red) 15%,transparent);color:var(--red)}
.b-deferred{background:color-mix(in srgb,var(--magenta) 15%,transparent);color:var(--magenta)}
.b-must{background:color-mix(in srgb,var(--red) 12%,transparent);color:var(--red)}
.b-should{background:color-mix(in srgb,var(--yellow) 12%,transparent);color:var(--yellow)}
.b-could{background:color-mix(in srgb,var(--blue) 12%,transparent);color:var(--blue)}
.b-pass{background:color-mix(in srgb,var(--green) 12%,transparent);color:var(--green)}

/* Metrics */
.mrow{display:flex;justify-content:space-between;align-items:center;padding:.4rem 0}
.mrow+.mrow{border-top:1px solid var(--border)}
.mval{font-weight:600;font-variant-numeric:tabular-nums}

/* Bars */
.bar-chart{display:flex;flex-direction:column;gap:.5rem}
.bar-r{display:flex;align-items:center;gap:.5rem;font-size:.8rem}
.bar-l{width:140px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;color:var(--text2)}
.bar-t{flex:1;height:20px;background:var(--bg3);border-radius:4px;overflow:hidden}
.bar-f{height:100%;background:var(--cyan);border-radius:4px;min-width:2px;transition:width .4s}
.bar-v{width:60px;text-align:right;font-variant-numeric:tabular-nums}

/* Failure stats */
.fstat{text-align:center}
.fstat .n{font-size:1.5rem;font-weight:700}
.fstat .l{font-size:.75rem;color:var(--text2)}
.fwrap{display:flex;gap:1rem;flex-wrap:wrap}

/* Sidebar sprint list */
.s-list{display:flex;flex-direction:column;gap:0;margin-top:.5rem}
.s-node{display:flex;align-items:flex-start;gap:.75rem;position:relative;padding:.5rem .75rem;cursor:pointer;border-radius:6px;transition:background .15s}
.s-node:hover{background:var(--bg3)}
.s-node.active{background:var(--bg3);border:1px solid var(--blue)}
.s-dot{width:10px;height:10px;border-radius:50%;flex-shrink:0;margin-top:4px}
.s-info{display:flex;flex-direction:column}
.s-label{font-size:.8rem;font-weight:600;line-height:1.2}
.s-title{font-size:.7rem;color:var(--text2);line-height:1.3}
.s-meta{font-size:.65rem;color:var(--text2);margin-top:.1rem}
.s-project{padding:.5rem .75rem;cursor:pointer;border-radius:6px;font-size:.8rem;font-weight:600;color:var(--text2);transition:background .15s;margin-bottom:.25rem}
.s-project:hover{background:var(--bg3)}
.s-project.active{background:var(--bg3);color:var(--blue);border:1px solid var(--blue)}
.s-divider{height:1px;background:var(--border);margin:.5rem .75rem}

/* Tabs */
.tabs{display:flex;gap:0;border-bottom:2px solid var(--border);margin-bottom:1rem}
.tab{padding:.5rem 1.25rem;cursor:pointer;font-size:.85rem;font-weight:500;color:var(--text2);border-bottom:2px solid transparent;margin-bottom:-2px;transition:color .2s,border-color .2s;user-select:none}
.tab:hover{color:var(--text)}
.tab.active{color:var(--blue);border-bottom-color:var(--blue)}
.tab-panel{display:none}
.tab-panel.active{display:block}

/* Trend cards */
.trend-row{display:flex;gap:1rem;flex-wrap:wrap;margin-bottom:1rem}
.trend-card{flex:1;min-width:140px;background:var(--bg2);border:1px solid var(--border);border-radius:8px;padding:1rem;text-align:center}
.trend-card .tv{font-size:1.75rem;font-weight:700;line-height:1}
.trend-card .tl{font-size:.75rem;color:var(--text2);margin-top:.25rem}
.trend-card .tsub{font-size:.7rem;color:var(--text2);margin-top:.15rem}

/* Small table */
.sm{font-size:.8rem}
.sm td,.sm th{padding:.35rem .5rem}
.dim{color:var(--text2);font-size:.8rem}
.empty{color:var(--text2);font-size:.85rem;padding:.5rem 0}
/* Working Context banner */
.wc-banner{background:var(--bg2);border:1px solid var(--border);border-radius:8px;padding:.75rem 1.25rem;margin-bottom:1rem;display:flex;flex-wrap:wrap;gap:.5rem 1.5rem;font-size:.85rem}
.wc-item{display:flex;align-items:center;gap:.35rem}
.wc-label{font-weight:600;font-size:.75rem;text-transform:uppercase;color:var(--text2)}

/* Mode/version badge */
.mode-badge{display:inline-flex;align-items:center;gap:.35rem;padding:.15rem .6rem;border-radius:12px;font-size:.75rem;font-weight:500;border:1px solid var(--border)}
.mode-standard{border-color:var(--green);color:var(--green)}
.mode-strict{border-color:var(--red);color:var(--red)}
.mode-lite{border-color:var(--yellow);color:var(--yellow)}
.mode-freestyle{border-color:var(--magenta);color:var(--magenta)}

/* Phase badge */
.phase-badge{display:inline-block;padding:.1rem .4rem;border-radius:8px;font-size:.65rem;font-weight:500;letter-spacing:.03em}
.ph-planned{background:var(--bg3);color:var(--text2)}
.ph-entry_gate{background:color-mix(in srgb,var(--blue) 15%,transparent);color:var(--blue)}
.ph-impl_loop{background:color-mix(in srgb,var(--yellow) 15%,transparent);color:var(--yellow)}
.ph-impl_done{background:color-mix(in srgb,var(--cyan) 15%,transparent);color:var(--cyan)}
.ph-close_gate{background:color-mix(in srgb,var(--magenta) 15%,transparent);color:var(--magenta)}
.ph-sprint_close{background:color-mix(in srgb,var(--blue) 15%,transparent);color:var(--blue)}
.ph-done{background:color-mix(in srgb,var(--green) 15%,transparent);color:var(--green)}

/* Note type badges */
.note-badge{display:inline-block;padding:.1rem .35rem;border-radius:6px;font-size:.65rem;font-weight:500;margin-right:.35rem}
.nt-decision{background:color-mix(in srgb,var(--blue) 15%,transparent);color:var(--blue)}
.nt-attempt{background:color-mix(in srgb,var(--yellow) 15%,transparent);color:var(--yellow)}
.nt-observation{background:color-mix(in srgb,var(--cyan) 15%,transparent);color:var(--cyan)}
.nt-side-effect{background:color-mix(in srgb,var(--red) 15%,transparent);color:var(--red)}
.nt-artifact{background:color-mix(in srgb,var(--magenta) 15%,transparent);color:var(--magenta)}

/* Hook status */
.hook-row{display:flex;align-items:center;gap:.5rem;padding:.25rem 0;font-size:.8rem}
.hook-dot{width:8px;height:8px;border-radius:50%}

.footer{margin-top:2rem;padding-top:1rem;border-top:1px solid var(--border);font-size:.75rem;color:var(--text2);text-align:center}
</style></head>
<body>
<h1 id="title">Loading...</h1>
<div class="subtitle"><span class="live-dot"></span><span id="sub"></span><span id="mode-badges" style="margin-left:.5rem"></span></div>
<div id="wc-banner" class="wc-banner" style="display:none"></div>
<div class="layout">
  <div class="sidebar">
    <div class="card">
      <div class="card-title">Navigation</div>
      <div class="s-project active" data-view="project">All Sprints</div>
      <div class="s-divider"></div>
      <div id="sidebar-sprints" class="s-list"></div>
    </div>
  </div>
  <div class="main">
    <div class="tabs">
      <div class="tab active" data-tab="sprint">Sprint</div>
      <div class="tab" data-tab="quality">Quality</div>
      <div class="tab" data-tab="trends">Trends</div>
    </div>
    <div id="tab-sprint" class="tab-panel active"><div class="grid">
      <div class="card"><div class="card-title">Progress</div><div id="progress"></div></div>
      <div class="card"><div class="card-title">Gates</div><div id="gates"></div></div>
      <div class="card"><div class="card-title">Priority Distribution</div><div id="priority"></div></div>
      <div class="card" id="checkmark-card" style="display:none"><div class="card-title">Consistency Check</div><div id="checkmarks"></div></div>
      <div class="card full"><div class="card-title" id="board-title">Sprint Board</div><div id="board"></div></div>
      <div class="card full"><div class="card-title">Recent Activity</div><div id="activity"></div></div>
      <div class="card full" id="notes-card" style="display:none"><div class="card-title">Session Notes</div><div id="notes"></div></div>
    </div></div>
    <div id="tab-quality" class="tab-panel"><div class="grid">
      <div class="card"><div class="card-title">Metrics</div><div id="metrics"></div></div>
      <div class="card"><div class="card-title">Failure Analysis</div><div id="failures"></div></div>
      <div class="card"><div class="card-title">Performance Baseline</div><div id="perf"></div></div>
      <div class="card"><div class="card-title">Active Watchlist</div><div id="watchlist"></div></div>
      <div class="card"><div class="card-title">Risks / Blockers</div><div id="risks"></div></div>
      <div class="card"><div class="card-title">Dismissed Signals</div><div id="dismissed"></div></div>
      <div class="card full"><div class="card-title">Verification Plan</div><div id="vplan"></div></div>
      <div class="card full"><div class="card-title">Close Gate — Audit Detail</div><div id="cgdetail"></div></div>
      <div class="card"><div class="card-title">Test Coverage — Files</div><div id="coverage-files"></div></div>
      <div class="card"><div class="card-title">Test Coverage — Items</div><div id="coverage-items"></div></div>
      <div class="card"><div class="card-title">Hook Status</div><div id="hooks"></div></div>
      <div class="card"><div class="card-title">Knowledge Base</div><div id="knowledge"></div></div>
      <div class="card full"><div class="card-title">Validation</div><div id="validation"></div></div>
    </div></div>
    <div id="tab-trends" class="tab-panel"><div id="trends"></div></div>
  </div>
</div>
<div class="footer">sprint-status · ai-sprint-workflow<span id="live-info"></span></div>
<script>
const E=s=>{const d=document.createElement('div');d.textContent=s;return d.innerHTML};
const $=id=>document.getElementById(id);

// Tab switching
document.querySelectorAll('.tab').forEach(tab=>{
  tab.addEventListener('click',()=>{
    document.querySelectorAll('.tab').forEach(t=>t.classList.remove('active'));
    document.querySelectorAll('.tab-panel').forEach(p=>p.classList.remove('active'));
    tab.classList.add('active');
    $('tab-'+tab.dataset.tab).classList.add('active');
  });
});

// State
let DATA=null;
let currentView='project'; // 'project' or 'S1','S2',...

function selectView(view){
  currentView=view;
  document.querySelectorAll('.s-node,.s-project').forEach(n=>n.classList.remove('active'));
  if(view==='project'){
    document.querySelector('.s-project').classList.add('active');
  } else {
    const node=document.querySelector(`.s-node[data-sprint="${view}"]`);
    if(node)node.classList.add('active');
  }
  if(DATA)renderAll(DATA);
}

// Sidebar click handlers
document.querySelector('.s-project').addEventListener('click',()=>selectView('project'));

function renderAll(D){
  DATA=D;
  const proj=D.project||{};
  const sprints=D.sprints||{};
  const roadmap=D.roadmap||{};
  const trends=D.trends||{};

  $('title').textContent=proj.current_focus||'No active sprint';
  $('sub').textContent=D.root||'';

  // Mode badges
  const wc_cfg=proj.workflow_config||{};
  let mb='';
  if(wc_cfg.workflow_mode){mb+=`<span class="mode-badge mode-${wc_cfg.workflow_mode}">${E(wc_cfg.workflow_mode)}</span> `}
  if(wc_cfg.hooks_version){mb+=`<span style="font-size:.75rem;color:var(--text2)">v${E(wc_cfg.hooks_version)}</span>`}
  $('mode-badges').innerHTML=mb;

  // Working context banner
  const wctx=proj.working_context||{};
  const _wcEmpty=new Set(['','\u2014','-']);
  const _wcVal=v=>v&&!_wcEmpty.has(v);
  if(_wcVal(wctx.task)||_wcVal(wctx.doing)||_wcVal(wctx.decisions)||_wcVal(wctx.blockers)){
    let wh='';
    if(_wcVal(wctx.task))wh+=`<div class="wc-item"><span class="wc-label">Task</span>${E(wctx.task)}</div>`;
    if(_wcVal(wctx.doing))wh+=`<div class="wc-item"><span class="wc-label">Doing</span>${E(wctx.doing)}</div>`;
    if(_wcVal(wctx.decisions))wh+=`<div class="wc-item"><span class="wc-label">Decisions</span>${E(wctx.decisions)}</div>`;
    if(_wcVal(wctx.blockers))wh+=`<div class="wc-item"><span class="wc-label" style="color:var(--red)">Blocked</span><span style="color:var(--red)">${E(wctx.blockers)}</span></div>`;
    $('wc-banner').innerHTML=wh;$('wc-banner').style.display='flex';
  } else {$('wc-banner').style.display='none'}

  // Sidebar sprint list
  const labels=proj.sprint_labels||[];
  let sh='';
  labels.forEach(s=>{
    const sd=sprints[s]||{};
    const st=sd.status||'unknown';
    const phase=sd.phase||'';
    const phaseLabels={planned:'Plan',entry_gate:'Entry',impl_loop:'Impl',impl_done:'Done',close_gate:'CG',sprint_close:'SC',done:'Done'};
    const dotColor=st==='complete'?'var(--green)':st==='active'?'var(--yellow)':'var(--bg3)';
    const border=st==='complete'||st==='active'?'none':'2px solid var(--border)';
    const done=sd.completed_items||0;const tot=sd.total_items||0;
    const meta=tot>0?`${done}/${tot} items`:sd.theme?'sketch':'';
    const phBadge=phase?` <span class="phase-badge ph-${phase}">${phaseLabels[phase]||phase}</span>`:'';
    const act=currentView===s?' active':'';
    sh+=`<div class="s-node${act}" data-sprint="${E(s)}"><div class="s-dot" style="background:${dotColor};border:${border}"></div><div class="s-info"><div class="s-label">${E(s)}${phBadge}${sd.theme?' — '+E(sd.theme):''}</div><div class="s-meta">${E(meta)}</div></div></div>`;
  });
  $('sidebar-sprints').innerHTML=sh;
  // Re-attach click handlers
  document.querySelectorAll('.s-node').forEach(n=>{
    n.addEventListener('click',()=>selectView(n.dataset.sprint));
  });

  const trendsTab=document.querySelector('[data-tab="trends"]');
  if(currentView==='project'){
    renderProjectView(D);
    renderTrends(trends);
    if(trendsTab)trendsTab.style.display='';
  } else {
    renderSprintView(D, currentView);
    if(trendsTab){trendsTab.style.display='none';
      // If trends tab was active, switch to sprint tab
      if(trendsTab.classList.contains('active')){
        trendsTab.classList.remove('active');
        $('tab-trends').classList.remove('active');
        document.querySelector('[data-tab="sprint"]').classList.add('active');
        $('tab-sprint').classList.add('active');
      }
    }
  }
}

function renderProjectView(D){
  const proj=D.project||{};const sprints=D.sprints||{};const roadmap=D.roadmap||{};
  const sc=proj.status_counts||{};const total=proj.total_items||0;const done=proj.completed_items||0;
  const pct=total?Math.round(done/total*100):0;

  renderProjectProgress(pct,sc,sprints,proj.sprint_labels||[]);
  const cur=proj.current_sprint;
  const curSd=cur?sprints[cur]:{};
  renderProjectGates(sprints,proj.sprint_labels||[]);
  renderProjectPriority(roadmap,sprints,proj.sprint_labels||[]);
  const allItems=[];
  (proj.sprint_labels||[]).forEach(s=>{(sprints[s]||{}).items&&allItems.push(...sprints[s].items)});
  $('board-title').textContent='All Items';
  renderBoard(allItems);
  renderActivity(proj.changelog_lines||[]);
  renderCheckmarks(null); // no checkmarks for project view

  // Aggregate quality data across all sprints
  const aggGates={};const aggPerf=[];const aggPF=[];const aggFE=[];
  const aggFA={total_predicted:0,total_occurred:0,predicted_and_caught:0,unpredicted:0,new_guardrails:0,close_gate_findings:0,details:[]};
  const labels=proj.sprint_labels||[];
  let latestCloseGate=null;
  labels.forEach(s=>{
    const sd=sprints[s]||{};
    const fa=sd.failure_analysis||{};
    aggFA.total_predicted+=fa.total_predicted||0;
    aggFA.total_occurred+=fa.total_occurred||0;
    aggFA.predicted_and_caught+=fa.predicted_and_caught||0;
    aggFA.unpredicted+=fa.unpredicted||0;
    aggFA.new_guardrails+=fa.new_guardrails||0;
    aggFA.close_gate_findings+=fa.close_gate_findings||0;
    if(fa.details)aggFA.details.push(...fa.details);
    if(sd.performance)aggPerf.push(...sd.performance);
    if(sd.predicted_failures)aggPF.push(...sd.predicted_failures);
    if(sd.failure_encounters)aggFE.push(...sd.failure_encounters);
    const cg=(sd.gates||{}).close||{};
    if(cg.exists)latestCloseGate=cg;
  });
  // For metrics/coverage, show latest close gate that exists
  const aggCGates=latestCloseGate?{close:latestCloseGate,entry:(cur&&sprints[cur]?sprints[cur].gates||{}:{}).entry||{}}:(cur&&sprints[cur]?sprints[cur].gates||{}:{});
  renderQuality(aggCGates,aggFA,aggPerf,proj.risks||[],proj.dismissed_signals||[],aggPF,aggFE);
  renderSessionNotes(proj.session_notes||[]);
  renderInfra(D);
}

function renderSprintView(D, sprintLabel){

  const sd=(D.sprints||{})[sprintLabel]||{};
  const items=sd.items||[];
  const sc=sd.status_counts||{};
  const total=sd.total_items||0;const done=sd.completed_items||0;
  const pct=total?Math.round(done/total*100):0;

  renderProgress(pct,sc);
  renderGates(sd.gates||{});
  renderPriority(D.roadmap||{},sprintLabel);
  $('board-title').textContent=sprintLabel+' Board';
  renderBoard(items);
  renderActivity(sd.changelog_lines||[]);
  renderCheckmarks(sd.gates||{});
  renderQuality(sd.gates||{},sd.failure_analysis||{},sd.performance||[],(D.project||{}).risks||[],(D.project||{}).dismissed_signals||[],sd.predicted_failures||[],sd.failure_encounters||[]);
  renderSessionNotes((D.project||{}).session_notes||[]);
  renderInfra(D);
}

function renderProgress(pct,sc){
  const circ=2*Math.PI*34;
  const colors={verified:'var(--green)',fixed:'var(--cyan)',in_progress:'var(--yellow)',open:'var(--text2)',blocked:'var(--red)',deferred:'var(--magenta)'};
  let statsH='';
  for(const[s,c]of Object.entries(colors)){if((sc[s]||0)>0)statsH+=`<div class="stat"><span class="dot" style="background:${c}"></span>${sc[s]} ${s.replace('_',' ')}</div>`}
  $('progress').innerHTML=`<div class="progress-wrap"><div class="ring"><svg width="80" height="80" viewBox="0 0 80 80"><circle class="bg" cx="40" cy="40" r="34"/><circle class="fg" cx="40" cy="40" r="34" stroke-dasharray="${circ.toFixed(1)}" stroke-dashoffset="${(circ*(1-pct/100)).toFixed(1)}"/></svg><span class="pct">${pct}%</span></div><div class="stats">${statsH}</div></div>`;
}

function renderProjectProgress(pct,sc,sprints,labels){
  const circ=2*Math.PI*34;
  const colors={verified:'var(--green)',fixed:'var(--cyan)',in_progress:'var(--yellow)',open:'var(--text2)',blocked:'var(--red)',deferred:'var(--magenta)'};
  let statsH='';
  for(const[s,c]of Object.entries(colors)){if((sc[s]||0)>0)statsH+=`<div class="stat"><span class="dot" style="background:${c}"></span>${sc[s]} ${s.replace('_',' ')}</div>`}
  // Per-sprint mini progress
  let sprintH='<div class="scroll-box" style="margin-top:.75rem;border-top:1px solid var(--border);padding-top:.5rem;max-height:160px">';
  labels.forEach(s=>{
    const sd=sprints[s]||{};const t=sd.total_items||0;const d=sd.completed_items||0;
    const sp=t?Math.round(d/t*100):0;
    const col=sd.status==='complete'?'var(--green)':sd.status==='active'?'var(--yellow)':'var(--text2)';
    const statusLabel=sd.status==='complete'?'Complete':sd.status==='active'?'Active':'Planned';
    sprintH+=`<div style="display:flex;align-items:center;gap:.5rem;padding:.25rem 0;font-size:.8rem">`;
    sprintH+=`<span style="font-weight:600;min-width:2rem">${E(s)}</span>`;
    if(t>0){
      sprintH+=`<div style="flex:1;height:6px;background:var(--border);border-radius:3px;overflow:hidden"><div style="width:${sp}%;height:100%;background:${col};border-radius:3px"></div></div>`;
      sprintH+=`<span style="color:var(--text2);min-width:3rem;text-align:right">${d}/${t}</span>`;
    } else {
      sprintH+=`<span style="color:var(--text2);font-size:.75rem">${statusLabel}</span>`;
    }
    sprintH+=`</div>`;
  });
  sprintH+='</div>';
  $('progress').innerHTML=`<div class="progress-wrap"><div class="ring"><svg width="80" height="80" viewBox="0 0 80 80"><circle class="bg" cx="40" cy="40" r="34"/><circle class="fg" cx="40" cy="40" r="34" stroke-dasharray="${circ.toFixed(1)}" stroke-dashoffset="${(circ*(1-pct/100)).toFixed(1)}"/></svg><span class="pct">${pct}%</span></div><div class="stats">${statsH}</div></div>${sprintH}`;
}

function renderGates(gates){
  const gateH=(key,label)=>{const x=gates[key]||{};const cls=x.exists?(x.approved?'g-ok':'g-wip'):'g-no';const ic=x.exists?(x.approved?'✓':'…'):'○';
    return `<div class="gate ${cls}"><div class="gate-icon">${ic}</div><div class="gate-lbl">${label}${x.date?' · '+E(x.date):''}</div></div>`};
  $('gates').innerHTML=`<div class="gate-row">${gateH('entry','Entry Gate')}${gateH('close','Close Gate')}${gateH('sprint_close','Sprint Close')}</div>`;
}

function renderProjectGates(sprints,labels){
  const pill=(x)=>{
    if(!x||!x.exists)return `<div style="width:100%;height:6px;border-radius:3px;background:var(--border)"></div>`;
    const col=x.approved?'var(--green)':'var(--yellow)';
    return `<div style="width:100%;height:6px;border-radius:3px;background:${col}"></div>`;
  };
  // Summary line
  const complete=labels.filter(s=>(sprints[s]||{}).status==='complete').length;
  const active=labels.filter(s=>(sprints[s]||{}).status==='active').length;
  const planned=labels.length-complete-active;
  let h=`<div style="display:flex;gap:1rem;margin-bottom:.75rem;font-size:.85rem">`;
  if(complete)h+=`<span style="color:var(--green)">${complete} complete</span>`;
  if(active)h+=`<span style="color:var(--yellow)">${active} active</span>`;
  if(planned)h+=`<span style="color:var(--text2)">${planned} planned</span>`;
  h+=`</div>`;
  h+='<div class="scroll-box" style="max-height:200px">';
  h+='<table style="width:100%;border-collapse:collapse;font-size:.8rem"><thead><tr style="color:var(--text2);font-size:.7rem">';
  h+='<th style="text-align:left;padding:.3rem .4rem;font-weight:500">Sprint</th>';
  h+='<th style="text-align:center;padding:.3rem .4rem;font-weight:500;width:25%">Entry</th>';
  h+='<th style="text-align:center;padding:.3rem .4rem;font-weight:500;width:25%">Close</th>';
  h+='<th style="text-align:center;padding:.3rem .4rem;font-weight:500;width:25%">Sprint Close</th>';
  h+='</tr></thead><tbody>';
  labels.forEach(s=>{
    const sd=sprints[s]||{};const g=sd.gates||{};
    const status=sd.status==='complete'?'Complete':sd.status==='active'?'Active':'Planned';
    const col=sd.status==='complete'?'var(--green)':sd.status==='active'?'var(--yellow)':'var(--text2)';
    h+=`<tr>`;
    h+=`<td style="padding:.4rem;font-weight:600">${E(s)} <span style="font-weight:400;color:${col};font-size:.7rem">${status}</span></td>`;
    h+=`<td style="padding:.4rem .6rem">${pill(g.entry)}</td>`;
    h+=`<td style="padding:.4rem .6rem">${pill(g.close)}</td>`;
    h+=`<td style="padding:.4rem .6rem">${pill(g.sprint_close)}</td>`;
    h+=`</tr>`;
  });
  h+='</tbody></table></div>';
  $('gates').innerHTML=h;
}

function renderPriority(roadmap,sprintLabel){
  const sprints=roadmap.sprints||{};
  // Aggregate all sprints when no specific sprint selected
  let allItems=[];
  if(sprintLabel){
    const ts=sprints[sprintLabel];
    if(ts&&ts.items)allItems=ts.items;
  } else {
    Object.values(sprints).forEach(s=>{if(s.items)allItems.push(...s.items)});
  }
  if(allItems.length>0){
    const counts={must:0,should:0,could:0};
    allItems.forEach(i=>counts[i.priority]=(counts[i.priority]||0)+1);
    let h='<div style="display:flex;gap:4px;height:24px;border-radius:4px;overflow:hidden;margin-bottom:.75rem">';
    if(counts.must)h+=`<div style="flex:${counts.must};background:var(--red);opacity:.7" title="Must: ${counts.must}"></div>`;
    if(counts.should)h+=`<div style="flex:${counts.should};background:var(--yellow);opacity:.7" title="Should: ${counts.should}"></div>`;
    if(counts.could)h+=`<div style="flex:${counts.could};background:var(--blue);opacity:.7" title="Could: ${counts.could}"></div>`;
    h+='</div><div class="stats">';
    if(counts.must)h+=`<div class="stat"><span class="dot" style="background:var(--red)"></span>${counts.must} must</div>`;
    if(counts.should)h+=`<div class="stat"><span class="dot" style="background:var(--yellow)"></span>${counts.should} should</div>`;
    if(counts.could)h+=`<div class="stat"><span class="dot" style="background:var(--blue)"></span>${counts.could} could</div>`;
    h+='</div>';$('priority').innerHTML=h;
  } else $('priority').innerHTML='<div class="empty">No priority data</div>';
}

function renderProjectPriority(roadmap,sprints,labels){
  const rsprints=roadmap.sprints||{};
  let allItems=[];
  Object.values(rsprints).forEach(s=>{if(s.items)allItems.push(...s.items)});
  if(allItems.length>0){
    const counts={must:0,should:0,could:0};
    allItems.forEach(i=>counts[i.priority]=(counts[i.priority]||0)+1);
    let h='<div style="display:flex;gap:4px;height:20px;border-radius:4px;overflow:hidden;margin-bottom:.5rem">';
    if(counts.must)h+=`<div style="flex:${counts.must};background:var(--red);opacity:.7" title="Must: ${counts.must}"></div>`;
    if(counts.should)h+=`<div style="flex:${counts.should};background:var(--yellow);opacity:.7" title="Should: ${counts.should}"></div>`;
    if(counts.could)h+=`<div style="flex:${counts.could};background:var(--blue);opacity:.7" title="Could: ${counts.could}"></div>`;
    h+='</div><div class="stats" style="margin-bottom:.5rem">';
    if(counts.must)h+=`<div class="stat"><span class="dot" style="background:var(--red)"></span>${counts.must} must</div>`;
    if(counts.should)h+=`<div class="stat"><span class="dot" style="background:var(--yellow)"></span>${counts.should} should</div>`;
    if(counts.could)h+=`<div class="stat"><span class="dot" style="background:var(--blue)"></span>${counts.could} could</div>`;
    h+='</div>';
    // Per-sprint breakdown
    h+='<div class="scroll-box" style="border-top:1px solid var(--border);padding-top:.5rem;max-height:160px">';
    labels.forEach(s=>{
      const rs=rsprints[s];
      if(!rs||!rs.items||!rs.items.length)return;
      const sc={must:0,should:0,could:0};
      rs.items.forEach(i=>sc[i.priority]=(sc[i.priority]||0)+1);
      const parts=[];
      if(sc.must)parts.push(`${sc.must}M`);
      if(sc.should)parts.push(`${sc.should}S`);
      if(sc.could)parts.push(`${sc.could}C`);
      h+=`<div style="display:flex;align-items:center;gap:.5rem;padding:.2rem 0;font-size:.8rem">`;
      h+=`<span style="font-weight:600;min-width:2rem">${E(s)}</span>`;
      h+=`<span style="color:var(--text2)">${parts.join(' / ')}</span>`;
      h+=`</div>`;
    });
    h+='</div>';
    $('priority').innerHTML=h;
  } else $('priority').innerHTML='<div class="empty">No priority data</div>';
}

function renderBoard(items){
  if(items.length){
    let h='<div class="scroll-box" style="max-height:400px"><table><thead><tr><th>ID</th><th>Summary</th><th>Status</th><th>Sprint</th><th>Evidence</th></tr></thead><tbody>';
    items.forEach(i=>{const s=(i.status||'open').toLowerCase();
      h+=`<tr><td style="font-weight:600">${E(i.id||'')}</td><td>${E(i.summary||'')}</td><td><span class="badge b-${s}">${s}</span></td><td>${E(i.sprint||'')}</td><td class="dim">${E(i.evidence||'')}</td></tr>`});
    h+='</tbody></table></div>';
    if(items.length>15)h+=`<div style="font-size:.75rem;color:var(--text2);padding-top:.35rem">${items.length} items</div>`;
    $('board').innerHTML=h;
  } else $('board').innerHTML='<div class="empty">No items</div>';
}

function renderActivity(cl){
  if(cl.length){
    $('activity').innerHTML=cl.slice(-10).map(e=>`<div style="padding:.35rem 0;font-size:.8rem;color:var(--text2)">• ${E(e)}</div>`).join('');
  } else $('activity').innerHTML='<div class="empty">No activity</div>';
}

function renderCheckmarks(gates){
  const card=$('checkmark-card');
  if(!gates){card.style.display='none';return;}
  const sc=gates.sprint_close||{};
  const checks=sc.checkmarks||[];
  if(!checks.length){card.style.display='none';return;}
  card.style.display='';
  const allMatch=checks.every(c=>(c.match||'').includes('✓'));
  const total=checks.length;const matched=checks.filter(c=>(c.match||'').includes('✓')).length;
  let h=`<div style="display:flex;align-items:center;gap:.75rem;margin-bottom:.5rem">`;
  h+=`<span style="font-size:1.5rem;color:${allMatch?'var(--green)':'var(--yellow)'};">${allMatch?'✓':'⚠'}</span>`;
  h+=`<span style="font-weight:600">${matched}/${total} items consistent</span>`;
  h+=`<span class="dim">Roadmap ↔ TRACKING</span></div>`;
  if(!allMatch){
    h+='<table class="sm"><thead><tr><th>Item</th><th>Roadmap</th><th>TRACKING</th><th>Match</th></tr></thead><tbody>';
    checks.forEach(c=>{
      const ok=(c.match||'').includes('✓');
      if(!ok)h+=`<tr><td style="font-weight:600">${E(c.item||'')}</td><td>${E(c.roadmap||'')}</td><td>${E(c.tracking||'')}</td><td style="color:var(--red)">✗</td></tr>`;
    });
    h+='</tbody></table>';
  }
  $('checkmarks').innerHTML=h;
}

function renderQuality(gates,fa,perf,risks,ds,predictedFailures,failureEncounters){
  const cg=gates.close||{};
  // Metrics
  if(cg.exists&&cg.metrics_total>0){
    const mp=cg.metrics_pass,mt=cg.metrics_total,tp=cg.tests_passed||0,tt=cg.tests_total||0;
    let h=`<div class="mrow"><span>Verification</span><span class="mval" style="color:${mp===mt?'var(--green)':'var(--yellow)'};">${mp}/${mt} PASS</span></div>`;
    if(tt>0)h+=`<div class="mrow"><span>Tests</span><span class="mval" style="color:${tp===tt?'var(--green)':'var(--red)'};">${tp}/${tt} passed</span></div>`;
    if(cg.fitness_total>0)h+=`<div class="mrow"><span>Fitness</span><span class="mval" style="color:var(--green)">${cg.fitness_pass}/${cg.fitness_total} PASS</span></div>`;
    if(cg.findings&&cg.findings.length>0)h+=`<div class="mrow"><span>Findings</span><span class="mval">${cg.findings.length} total</span></div>`;
    $('metrics').innerHTML=h;
  } else $('metrics').innerHTML='<div class="empty">No Close Gate data</div>';

  // Performance
  if(perf.length){
    const mx=Math.max(...perf.map(p=>parseFloat(p.value)||0),1);
    let h='<div class="bar-chart">';
    perf.forEach(p=>{const v=parseFloat(p.value)||0;const w=(v/mx)*100;
      h+=`<div class="bar-r"><span class="bar-l" title="${E(p.metric||'')}">${E(p.metric||'')}</span><div class="bar-t"><div class="bar-f" style="width:${w}%"></div></div><span class="bar-v">${v} ${E(p.unit||'')}</span></div>`});
    h+='</div>';$('perf').innerHTML=h;
  } else $('perf').innerHTML='<div class="empty">No baseline data</div>';

  // Failure Analysis
  if(fa.total_predicted>0||fa.total_occurred>0){
    let h='<div class="fwrap">';
    h+=`<div class="fstat"><div class="n" style="color:var(--text2)">${fa.total_predicted}</div><div class="l">Predicted</div></div>`;
    h+=`<div class="fstat"><div class="n" style="color:var(--orange)">${fa.total_occurred}</div><div class="l">Occurred</div></div>`;
    h+=`<div class="fstat"><div class="n" style="color:var(--green)">${fa.predicted_and_caught}</div><div class="l">Caught</div></div>`;
    h+=`<div class="fstat"><div class="n" style="color:var(--red)">${fa.unpredicted}</div><div class="l">Unpredicted</div></div>`;
    h+=`<div class="fstat"><div class="n" style="color:var(--cyan)">${fa.new_guardrails}</div><div class="l">Guardrails</div></div>`;
    h+='</div>';
    if(fa.details&&fa.details.length>0){
      h+='<div class="scroll-box" style="margin-top:.75rem;border-top:1px solid var(--border);padding-top:.5rem;font-size:.8rem;max-height:150px">';
      fa.details.forEach(d=>{
        const ic=d.predicted?'<span style="color:var(--green)">✓</span>':'<span style="color:var(--red)">!</span>';
        const imp=d.impact&&d.impact!=='—'?` <span style="color:var(--text2)">(${E(d.impact)})</span>`:'';
        const gr=d.guardrail&&!['no','—','-'].includes(d.guardrail.toLowerCase())?` → <span style="color:var(--cyan)">${E(d.guardrail)}</span>`:'';
        const esc=d.escalate&&!['no','—','-',''].includes(d.escalate.toLowerCase())?` <span style="color:var(--red)">⚑ escalate</span>`:'';
        h+=`<div style="padding:.2rem 0">${ic} ${E(d.mode)}${imp}${gr}${esc}</div>`});
      h+='</div>';
    }
    $('failures').innerHTML=h;
  } else $('failures').innerHTML='<div class="empty">No failure data</div>';

  // Active Watchlist (predicted failures + encounters from current sprint)
  const pf=predictedFailures||[];const fe=failureEncounters||[];
  if(pf.length||fe.length){
    let h='<div class="scroll-box">';
    if(fe.length){
      h+='<div style="margin-bottom:.75rem"><div style="font-size:.8rem;font-weight:600;color:var(--red);margin-bottom:.35rem">Encountered</div>';
      fe.forEach(f=>{h+=`<div style="padding:.2rem 0;font-size:.8rem"><span style="color:var(--red)">!</span> ${E(f.failure_description||f.mode||f.predicted_mode||'')} <span class="dim">(${E(f.item||'')})</span></div>`});
      h+='</div>';
    }
    if(pf.length){
      h+=`<div><div style="font-size:.8rem;font-weight:600;color:var(--text2);margin-bottom:.35rem">Watching (${pf.length} predicted)</div>`;
      const grouped={};pf.forEach(f=>{const k=f.item||'?';if(!grouped[k])grouped[k]=[];grouped[k].push(f)});
      Object.entries(grouped).forEach(([item,modes])=>{
        h+=`<div style="margin-bottom:.35rem"><span style="font-weight:600;font-size:.8rem">${E(item)}</span>`;
        modes.forEach(m=>{h+=`<div style="padding:.1rem 0 .1rem 1rem;font-size:.78rem;color:var(--text2)">· ${E(m.predicted_mode||m.mode||'')} <span class="dim">(${E(m.category||'')})</span></div>`});
        h+='</div>';
      });
      h+='</div>';
    }
    h+='</div>';
    $('watchlist').innerHTML=h;
  } else $('watchlist').innerHTML='<div class="empty">No active predictions (cleared after sprint close)</div>';

  // Verification Plan (Entry Gate Step 9b)
  const vp=(gates.entry||{}).verification_plan||[];
  if(vp.length){
    let h='<table class="sm"><thead><tr><th>Item</th><th>Test Type</th><th>Scenario</th><th>Invariants</th></tr></thead><tbody>';
    vp.forEach(v=>{h+=`<tr><td style="font-weight:600">${E(v.item||'')}</td><td><span class="badge b-open">${E(v.test_type||'')}</span></td><td>${E(v.scenario||'')}</td><td class="dim">${E(v.invariants||'')}</td></tr>`});
    h+='</tbody></table>';$('vplan').innerHTML=h;
  } else $('vplan').innerHTML='<div class="empty">No verification plan</div>';

  // Close Gate Detail
  const sa=cg.spec_audit||[];const fi=cg.findings||[];const fit=cg.fitness||[];
  if(sa.length||fi.length||fit.length){
    let h='<div class="scroll-box" style="max-height:400px">';
    if(fi.length){
      h+='<div style="margin-bottom:1rem"><div style="font-size:.8rem;font-weight:600;margin-bottom:.5rem;color:var(--text2)">Findings (Phase 1a + Supplemental)</div>';
      h+='<table class="sm"><thead><tr><th>Finding</th><th>Section</th><th>Action</th></tr></thead><tbody>';
      fi.forEach(f=>{h+=`<tr><td>${E(f.finding||'')}</td><td>${E(f.section||'')}</td><td>${E(f.action||'')}</td></tr>`});
      h+='</tbody></table></div>';
    }
    if(sa.length){
      h+='<div style="margin-bottom:1rem"><div style="font-size:.8rem;font-weight:600;margin-bottom:.5rem;color:var(--text2)">Spec Audit (Phase 1b)</div>';
      h+='<table class="sm"><thead><tr><th>Item</th><th>Direct</th><th>Interaction</th><th>Stress/Edge</th><th>Result</th></tr></thead><tbody>';
      sa.forEach(s=>{h+=`<tr><td style="font-weight:600">${E(s.item||'')}</td><td class="dim">${E(s.direct||'')}</td><td class="dim">${E(s.interaction||'')}</td><td class="dim">${E(s['stress_edge']||s['stress/edge']||'')}</td><td>${E(s.result||'')}</td></tr>`});
      h+='</tbody></table></div>';
    }
    if(fit.length){
      h+='<div><div style="font-size:.8rem;font-weight:600;margin-bottom:.5rem;color:var(--text2)">Fitness Review (Phase 1c)</div>';
      h+='<table class="sm"><thead><tr><th>Item</th><th>Complete</th><th>Integrates</th><th>Critical Axis</th><th>Verdict</th></tr></thead><tbody>';
      fit.forEach(f=>{h+=`<tr><td style="font-weight:600">${E(f.item||'')}</td><td class="dim">${E(f['complete?']||'')}</td><td class="dim">${E(f['integrates?']||'')}</td><td class="dim">${E(f['critical_axis?']||'')}</td><td><span class="badge b-pass">${E(f.verdict||'')}</span></td></tr>`});
      h+='</tbody></table></div>';
    }
    h+='</div>';
    $('cgdetail').innerHTML=h;
  } else $('cgdetail').innerHTML='<div class="empty">No Close Gate audit data</div>';

  // Test Coverage — Files (Close Gate Phase 4a)
  const fcov=cg.file_coverage||[];
  if(fcov.length){
    let h='<table class="sm"><thead><tr><th>Source</th><th>Test</th><th></th></tr></thead><tbody>';
    fcov.forEach(f=>{
      const ok=(f.status||'').includes('✓');
      h+=`<tr><td>${E(f.source_file||'')}</td><td>${E(f.test_file||'')}</td><td style="color:${ok?'var(--green)':'var(--red)'};">${ok?'✓':'✗'}</td></tr>`;
    });
    h+='</tbody></table>';$('coverage-files').innerHTML=h;
  } else $('coverage-files').innerHTML='<div class="empty">No file coverage data</div>';

  // Test Coverage — Items (Close Gate Phase 4b)
  const icov=cg.item_coverage||[];
  if(icov.length){
    let h='<table class="sm"><thead><tr><th>Item</th><th>Test</th><th>Evidence</th></tr></thead><tbody>';
    icov.forEach(i=>{h+=`<tr><td style="font-weight:600">${E(i.item||'')}</td><td>${E(i.behavioral_test||'')}</td><td class="dim">${E(i.evidence||'')}</td></tr>`});
    h+='</tbody></table>';$('coverage-items').innerHTML=h;
  } else $('coverage-items').innerHTML='<div class="empty">No item coverage data</div>';

  // Risks
  if(risks.length){
    $('risks').innerHTML=risks.map(r=>`<div style="padding:.5rem 0;border-bottom:1px solid var(--border);font-size:.85rem"><span style="color:var(--red);font-weight:600">${E(r.id||'')}</span> ${E(r.risk||'')} <span class="dim">— ${E(r.mitigation||'')}</span></div>`).join('');
  } else $('risks').innerHTML='<div class="empty">No open risks</div>';

  // Dismissed Signals
  if(ds.length){
    let h='<table class="sm"><thead><tr><th>Date</th><th>CP</th><th>System</th><th>Signal</th><th>Decision</th><th>#</th><th>Supp.</th><th>Revisit</th></tr></thead><tbody>';
    ds.forEach(d=>{h+=`<tr><td class="dim">${E(d.date||'')}</td><td>${E(d.checkpoint||'')}</td><td>${E(d.system_metric||d['system___metric']||d.system||'')}</td><td>${E(d.signal_summary||'')}</td><td>${E(d.user_decision||'')}</td><td>${E(d['dismissal_#']||d.dismissal||'')}</td><td>${E(d['suppressed?']||d.suppressed||'')}</td><td class="dim">${E(d.revisit_sprint||d['revisit_sprint']||'')}</td></tr>`});
    h+='</tbody></table>';$('dismissed').innerHTML=h;
  } else $('dismissed').innerHTML='<div class="empty">No dismissed signals</div>';
}

function renderTrends(tr){
  const ss=tr.sprints||[];const pa=tr.prediction_accuracy||{};
  let h='';

  // KPI cards
  h+='<div class="trend-row">';
  const latest=ss.length?ss[ss.length-1]:{};

  if(latest.first_pass_rate!==undefined){
    const pct=Math.round(latest.first_pass_rate*100);
    const col=pct>=80?'var(--green)':pct>=50?'var(--yellow)':'var(--red)';
    h+=`<div class="trend-card"><div class="tv" style="color:${col}">${pct}%</div><div class="tl">First-Pass Rate</div><div class="tsub">${latest.first_pass||0}/${(latest.first_pass||0)+(latest.rework_count||0)} without rework</div></div>`;
  }
  if(latest.rework_rate!==undefined){
    const pct=Math.round(latest.rework_rate*100);
    const col=pct<=10?'var(--green)':pct<=30?'var(--yellow)':'var(--red)';
    h+=`<div class="trend-card"><div class="tv" style="color:${col}">${pct}%</div><div class="tl">Rework Rate</div><div class="tsub">${latest.rework_count||0} metrics needed fixing</div></div>`;
  }
  if(latest.finding_density!==undefined){
    const fd=latest.finding_density;
    const col=fd<=0.3?'var(--green)':fd<=0.7?'var(--yellow)':'var(--red)';
    h+=`<div class="trend-card"><div class="tv" style="color:${col}">${fd}</div><div class="tl">Finding Density</div><div class="tsub">${latest.findings_count||0} findings / ${latest.total_items||0} items</div></div>`;
  }
  if(pa.accuracy!==null&&pa.accuracy!==undefined){
    const pct=Math.round(pa.accuracy*100);
    h+=`<div class="trend-card"><div class="tv" style="color:var(--green)">${pct}%</div><div class="tl">Prediction Accuracy</div><div class="tsub">${pa.caught||0}/${pa.total_occurred||0} failures predicted</div></div>`;
  }

  const gv=tr.guardrail_velocity||0;
  h+=`<div class="trend-card"><div class="tv" style="color:var(--cyan)">${gv}</div><div class="tl">New Guardrails</div><div class="tsub">Rules learned</div></div>`;

  if(latest.deferred_ratio!==undefined){
    const pct=Math.round(latest.deferred_ratio*100);
    const col=pct===0?'var(--green)':pct<=20?'var(--yellow)':'var(--red)';
    h+=`<div class="trend-card"><div class="tv" style="color:${col}">${pct}%</div><div class="tl">Deferred Ratio</div><div class="tsub">${latest.deferred||0}/${latest.total_items||0} deferred</div></div>`;
  }
  h+='</div>';

  // Sprint breakdown table
  if(ss.length>0){
    h+='<div class="card" style="margin-top:1rem"><div class="card-title">Sprint Breakdown</div>';
    h+='<div class="scroll-box" style="max-height:300px"><table class="sm"><thead><tr><th>Sprint</th><th>Items</th><th>Rework</th><th>First-Pass</th><th>Findings</th><th>Deferred</th></tr></thead><tbody>';
    ss.forEach(s=>{
      const rw=s.rework_count!==undefined?s.rework_count:'—';
      const fp=s.first_pass_rate!==undefined?Math.round(s.first_pass_rate*100)+'%':'—';
      const fc=s.findings_count!==undefined?s.findings_count:'—';
      const dr=s.deferred_ratio!==undefined?Math.round(s.deferred_ratio*100)+'%':'—';
      h+=`<tr><td style="font-weight:600">${E(s.sprint||'')}</td><td>${s.total_items||0}</td><td>${rw}</td><td>${fp}</td><td>${fc}</td><td>${dr}</td></tr>`;
    });
    h+='</tbody></table></div></div>';
  }

  // Failure prediction breakdown
  if(pa.total_predicted>0||pa.total_occurred>0){
    h+='<div class="card" style="margin-top:1rem"><div class="card-title">Failure Prediction Breakdown</div>';
    const c=pa.caught||0,u=pa.unpredicted||0,tp=pa.total_predicted||0;
    const silent=tp-c;
    h+='<div style="display:flex;align-items:center;gap:1rem;margin-bottom:.75rem">';
    h+=`<div style="flex:1;height:24px;display:flex;gap:2px;border-radius:4px;overflow:hidden">`;
    if(c>0)h+=`<div style="flex:${c};background:var(--green);opacity:.7" title="Predicted & occurred: ${c}"></div>`;
    if(u>0)h+=`<div style="flex:${u};background:var(--red);opacity:.7" title="Unpredicted: ${u}"></div>`;
    if(silent>0)h+=`<div style="flex:${silent};background:var(--bg3)" title="Predicted, didn't occur: ${silent}"></div>`;
    h+='</div></div>';
    h+='<div class="stats">';
    h+=`<div class="stat"><span class="dot" style="background:var(--green)"></span>${c} predicted & occurred</div>`;
    h+=`<div class="stat"><span class="dot" style="background:var(--red)"></span>${u} unpredicted</div>`;
    if(silent>0)h+=`<div class="stat"><span class="dot" style="background:var(--bg3);border:1px solid var(--border)"></span>${silent} predicted, didn't occur</div>`;
    h+='</div></div>';
  }

  // Failure Recurrence
  const rec=tr.failure_recurrence||[];
  h+='<div class="card" style="margin-top:1rem"><div class="card-title">Failure Recurrence</div>';
  if(rec.length>0){
    h+='<table class="sm"><thead><tr><th>Category</th><th>Sprints</th><th>Recurrences</th></tr></thead><tbody>';
    rec.forEach(r=>{
      h+=`<tr><td>${E(r.category||'')}</td><td>${(r.sprints||[]).map(s=>E(s)).join(', ')}</td><td style="color:var(--red);font-weight:600">${r.count||0}</td></tr>`;
    });
    h+='</tbody></table>';
  } else {
    if(ss.length<=1)h+='<div class="dim">Single sprint — recurrence tracking starts after Sprint 2</div>';
    else h+='<div style="display:flex;align-items:center;gap:.5rem;padding:.5rem 0"><span style="color:var(--green);font-size:1.25rem">✓</span><span>No recurring failures</span></div>';
  }
  h+='</div>';

  // Guardrail Effectiveness
  const ge=tr.guardrail_effectiveness||[];
  const gTotal=tr.guardrails_total||0;const gEff=tr.guardrails_effective||0;
  h+='<div class="card" style="margin-top:1rem"><div class="card-title">Guardrail Effectiveness</div>';
  if(gTotal>0){
    const pct=Math.round(gEff/gTotal*100);
    const col=pct>=80?'var(--green)':pct>=50?'var(--yellow)':'var(--red)';
    h+=`<div style="display:flex;align-items:center;gap:1rem;margin-bottom:.75rem"><span style="font-size:1.5rem;font-weight:700;color:${col}">${pct}%</span><span class="dim">${gEff}/${gTotal} guardrails prevented recurrence</span></div>`;
    h+='<table class="sm"><thead><tr><th>Guardrail</th><th>Created</th><th>Status</th><th>Detail</th></tr></thead><tbody>';
    ge.forEach(g=>{
      const st=g.effective?'<span style="color:var(--green)">✓ Effective</span>':'<span style="color:var(--red)">✗ Recurred</span>';
      const detail=g.recurred_in&&g.recurred_in.length?'in '+g.recurred_in.join(', '):'No recurrence';
      h+=`<tr><td style="font-weight:600;color:var(--cyan)">${E(g.guardrail||'')}</td><td>${E(g.created_sprint||'')}</td><td>${st}</td><td class="dim">${E(detail)}</td></tr>`;
    });
    h+='</tbody></table>';
  } else h+='<div class="dim">No guardrails created yet</div>';
  h+='</div>';

  // Performance trend
  const pt=tr.performance_trend||{};const ptKeys=Object.keys(pt);
  if(ptKeys.length>0){
    h+='<div class="card" style="margin-top:1rem"><div class="card-title">Performance Trend</div>';
    if(pt[ptKeys[0]].length<=1)h+='<div class="dim" style="margin-bottom:.5rem">Single sprint — trend appears after Sprint 2</div>';
    // Build lookup maps for O(1) access
    const ptMaps={};ptKeys.forEach(k=>{const m=new Map();pt[k].forEach(p=>m.set(p.sprint,p));ptMaps[k]=m});
    const allSL=[...new Set(ptKeys.flatMap(k=>pt[k].map(p=>p.sprint)))].sort();
    h+='<div class="scroll-box" style="max-height:300px;overflow-x:auto">';
    h+='<table class="sm"><thead><tr><th>Metric</th>';
    allSL.forEach(s=>{h+=`<th>${E(s)}</th>`});
    h+='</tr></thead><tbody>';
    ptKeys.forEach(k=>{
      h+=`<tr><td>${E(k)}</td>`;
      allSL.forEach(s=>{
        const entry=ptMaps[k].get(s);
        h+=`<td style="font-variant-numeric:tabular-nums">${entry?entry.value+' '+(entry.unit||''):'—'}</td>`;
      });
      h+='</tr>';
    });
    h+='</tbody></table></div></div>';
  }

  $('trends').innerHTML=h||'<div class="empty">No trend data yet</div>';
}

// ── v3.1 renderers ──

function renderSessionNotes(notes){
  const card=$('notes-card');
  if(!notes||!notes.length){card.style.display='none';return}
  card.style.display='';
  let h='<div class="scroll-box" style="max-height:300px">';
  notes.slice(-15).forEach(n=>{
    const t=n.type||'observation';
    h+=`<div style="padding:.3rem 0;font-size:.82rem;border-bottom:1px solid var(--border)">`;
    h+=`<span class="note-badge nt-${t}">${E(t)}</span>`;
    if(n.item)h+=`<span style="font-weight:600;font-size:.75rem;margin-right:.35rem">${E(n.item)}</span>`;
    h+=`${E(n.text||'')}`;
    if(n.timestamp)h+=` <span class="dim">${E(n.timestamp)}</span>`;
    h+=`</div>`;
  });
  h+='</div>';
  if(notes.length>15)h+=`<div style="font-size:.75rem;color:var(--text2);padding-top:.35rem">${notes.length} notes total</div>`;
  $('notes').innerHTML=h;
}

function renderInfra(D){
  const hooks=D.hooks||{};
  const know=D.knowledge||{};
  const val=D.validation||{};

  // Hooks
  if(hooks.total>0){
    const pct=Math.round(hooks.enabled/hooks.total*100);
    const col=pct===100?'var(--green)':'var(--yellow)';
    let h=`<div style="display:flex;align-items:center;gap:.75rem;margin-bottom:.75rem">`;
    h+=`<span style="font-size:1.25rem;font-weight:700;color:${col}">${hooks.enabled}/${hooks.total}</span>`;
    h+=`<span class="dim">hooks enabled</span></div>`;
    h+='<div class="scroll-box" style="max-height:200px">';
    (hooks.hooks||[]).forEach(hk=>{
      const dc=hk.enabled?'var(--green)':'var(--border)';
      h+=`<div class="hook-row"><span class="hook-dot" style="background:${dc}"></span><span>${E(hk.name)}</span></div>`;
    });
    h+='</div>';
    $('hooks').innerHTML=h;
  } else $('hooks').innerHTML='<div class="empty">No hooks directory</div>';

  // Knowledge
  if(know.guardrails>0||know.index_entries>0){
    let h='<div style="display:flex;gap:1.5rem">';
    if(know.guardrails>0)h+=`<div class="fstat"><div class="n" style="color:var(--cyan)">${know.guardrails}</div><div class="l">Guardrails</div></div>`;
    if(know.index_entries>0)h+=`<div class="fstat"><div class="n" style="color:var(--blue)">${know.index_entries}</div><div class="l">Index Entries</div></div>`;
    h+='</div>';
    $('knowledge').innerHTML=h;
  } else $('knowledge').innerHTML='<div class="empty">No knowledge files</div>';

  // Validation
  if(val.available){
    if(val.error){
      $('validation').innerHTML=`<div class="empty">Validation timed out</div>`;
    } else if(val.total>0){
      const col=val.failed===0?'var(--green)':'var(--red)';
      let h=`<div style="display:flex;align-items:center;gap:.75rem;margin-bottom:.75rem">`;
      h+=`<span style="font-size:1.25rem;font-weight:700;color:${col}">${val.passed}/${val.total}</span>`;
      h+=`<span class="dim">checks passed</span>`;
      if(val.failed>0)h+=`<span style="color:var(--red);font-weight:600">${val.failed} failed</span>`;
      h+=`</div>`;
      if(val.checks&&val.checks.length){
        h+='<div class="scroll-box" style="max-height:200px">';
        val.checks.forEach(c=>{
          const ic=c.status==='PASS'||c.status==='OK'||c.status==='CHECK'?'<span style="color:var(--green)">✓</span>':'<span style="color:var(--red)">✗</span>';
          h+=`<div style="padding:.2rem 0;font-size:.8rem">${ic} ${E(c.detail)}</div>`;
        });
        h+='</div>';
      }
      $('validation').innerHTML=h;
    } else $('validation').innerHTML='<div class="empty">No validation output</div>';
  } else $('validation').innerHTML='<div class="empty">validate-structure.sh not found</div>';
}

// Data loading
const EMBEDDED=/*DATA_JSON*/null/*END_DATA*/;

if(EMBEDDED){
  renderAll(EMBEDDED);
} else {
  document.body.classList.add('live');
  let lastHash='';
  async function poll(){
    try{
      const r=await fetch('/api/data');const d=await r.json();
      const h=JSON.stringify(d);
      if(h!==lastHash){lastHash=h;renderAll(d)}
    }catch(e){}
    setTimeout(poll,2000);
  }
  poll();
  $('live-info').textContent=' · live';
}
</script></body></html>"""


def render_html() -> str:
    """Return the live dashboard HTML (data loaded via /api/data polling)."""
    return DASHBOARD_HTML.replace("/*DATA_JSON*/null/*END_DATA*/", "null")


# ─── Live Server ──────────────────────────────────────────────────────────────

class LiveServer:
    def __init__(self, root: Path, port: int = 8384):
        self.root = root
        self.port = port
        self._data: Dict[str, Any] = {}
        self._lock = threading.Lock()
        self._refresh()

    def _refresh(self):
        with self._lock:
            self._data = collect_data(self.root)

    def get_data(self) -> Dict[str, Any]:
        with self._lock:
            return self._data

    def watch(self):
        watched = find_watched_files(self.root)
        mtimes = {}
        for f in watched:
            try:
                mtimes[str(f)] = f.stat().st_mtime
            except (FileNotFoundError, OSError):
                pass
        while True:
            time.sleep(1)
            new_watched = find_watched_files(self.root)
            changed = False
            new_mtimes = {}
            for f in new_watched:
                try:
                    key = str(f)
                    mt = f.stat().st_mtime
                    new_mtimes[key] = mt
                    if key not in mtimes or mtimes[key] != mt:
                        changed = True
                except (FileNotFoundError, OSError):
                    continue
            if changed:
                self._refresh()
            mtimes = new_mtimes

    def serve(self):
        server_ref = self

        class Handler(BaseHTTPRequestHandler):
            def do_GET(self):
                if self.path == "/api/data":
                    data = server_ref.get_data()
                    body = json.dumps(data, default=str).encode()
                    self.send_response(200)
                    self.send_header("Content-Type", "application/json")
                    self.send_header("Access-Control-Allow-Origin", f"http://127.0.0.1:{server_ref.port}")
                    self.end_headers()
                    self.wfile.write(body)
                elif self.path == "/" or self.path == "":
                    html = render_html().encode()
                    self.send_response(200)
                    self.send_header("Content-Type", "text/html; charset=utf-8")
                    self.end_headers()
                    self.wfile.write(html)
                else:
                    self.send_response(404)
                    self.end_headers()

            def log_message(self, format, *args):
                pass

        watcher = threading.Thread(target=self.watch, daemon=True)
        watcher.start()

        httpd = HTTPServer(("127.0.0.1", self.port), Handler)
        print(f"Dashboard live at http://localhost:{self.port}", file=sys.stderr)
        print(f"Watching {self.root} for changes (Ctrl+C to stop)", file=sys.stderr)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.", file=sys.stderr)
