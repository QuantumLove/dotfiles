#!/usr/bin/env python3
"""
fill-toggl-collect -- collect time-tracking data and emit a JSON summary.

Usage:
    fill-toggl-collect.py [--date DATE]

DATE: today (default) | yesterday | YYYY-MM-DD | YYYY-MM-DD..YYYY-MM-DD

Output (stdout): JSON with keys date_range, sessions, activity_blocks,
                 existing_entries, gaps, toggl_projects, workspace_id.
All progress and warnings go to stderr.
"""

import argparse
import base64
import json
import os
import subprocess
import sys
import urllib.request
import urllib.error
from datetime import date, timedelta, datetime, timezone


def parse_date_arg(date_str):
    s = date_str.strip()
    if s == "today":
        d = date.today()
        return d, d
    if s == "yesterday":
        d = date.today() - timedelta(days=1)
        return d, d
    if ".." in s:
        a, b = s.split("..", 1)
        return date.fromisoformat(a.strip()), date.fromisoformat(b.strip())
    d = date.fromisoformat(s)
    return d, d


def get_toggl_token():
    for var in ("TOGGL_API_TOKEN", "TOGGL_API_KEY"):
        val = os.environ.get(var, "").strip()
        if val:
            return val
    try:
        r = subprocess.run(
            ["op", "read", "op://Development/Toggl API Key/credential"],
            capture_output=True,
            text=True,
            timeout=15,
        )
        if r.returncode == 0:
            t = r.stdout.strip()
            if t:
                return t
        else:
            print(f"WARNING: op read: {r.stderr.strip()}", file=sys.stderr)
    except FileNotFoundError:
        print("WARNING: 'op' CLI not found", file=sys.stderr)
    except subprocess.TimeoutExpired:
        print("WARNING: 1Password CLI timed out", file=sys.stderr)
    return None


def toggl_get(path, token):
    auth = "Basic " + base64.b64encode(f"{token}:api_token".encode()).decode()
    req = urllib.request.Request(
        f"https://api.track.toggl.com{path}",
        headers={"Authorization": auth, "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        print(f"WARNING: Toggl API HTTP {e.code} → {path}", file=sys.stderr)
    except urllib.error.URLError as e:
        print(f"WARNING: Toggl API connection error: {e.reason}", file=sys.stderr)
    except json.JSONDecodeError as e:
        print(f"WARNING: Toggl API bad JSON: {e}", file=sys.stderr)
    return None


def parse_ts(ts_str):
    return datetime.fromisoformat(ts_str.replace("Z", "+00:00"))


def run_tt_ingest():
    try:
        r = subprocess.run(
            ["tt", "ingest", "sessions"], capture_output=True, text=True, timeout=120
        )
        if r.returncode != 0:
            print(
                f"WARNING: tt ingest exit {r.returncode}: {r.stderr.strip()}",
                file=sys.stderr,
            )
        else:
            print(f"tt ingest: {r.stdout.strip() or 'done'}", file=sys.stderr)
    except FileNotFoundError:
        print("ERROR: 'tt' not found in PATH", file=sys.stderr)
        sys.exit(1)
    except subprocess.TimeoutExpired:
        print("WARNING: tt ingest timed out (continuing)", file=sys.stderr)


def get_sessions(start_date, end_date):
    end_plus1 = end_date + timedelta(days=1)
    start_ts = f"{start_date.isoformat()}T00:00:00Z"
    end_ts = f"{end_plus1.isoformat()}T00:00:00Z"
    try:
        r = subprocess.run(
            ["tt", "classify", "--json", "--start", start_ts, "--end", end_ts],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if r.returncode != 0:
            print(f"WARNING: tt classify: {r.stderr.strip()}", file=sys.stderr)
            return []
        raw = r.stdout.strip()
        return json.loads(raw).get("sessions", []) if raw else []
    except (subprocess.TimeoutExpired, json.JSONDecodeError) as e:
        print(f"WARNING: tt classify: {e}", file=sys.stderr)
        return []


def get_activity_blocks(start_date, end_date):
    end_cutoff = datetime(
        end_date.year, end_date.month, end_date.day, tzinfo=timezone.utc
    ) + timedelta(days=1)
    try:
        r = subprocess.run(
            ["tt", "export", "--since", f"{start_date.isoformat()}T00:00:00Z"],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if r.returncode != 0:
            print(f"WARNING: tt export: {r.stderr.strip()}", file=sys.stderr)
            return []
        events = []
        for line in r.stdout.splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                ev = json.loads(line)
                ts_str = ev.get("timestamp", "")
                if ts_str and parse_ts(ts_str) < end_cutoff:
                    events.append(ev)
            except (json.JSONDecodeError, ValueError):
                pass
        blocks = _aggregate_blocks(events)
        print(
            f"Parsed {len(events)} events → {len(blocks)} activity blocks",
            file=sys.stderr,
        )
        return blocks
    except subprocess.TimeoutExpired:
        print("WARNING: tt export timed out", file=sys.stderr)
        return []


def _aggregate_blocks(events, gap_minutes=5):
    """
    Merge consecutive tmux_pane_focus events into activity blocks.

    Events are grouped by (tmux_session, cwd). Within the same group, events
    separated by <= gap_minutes are merged. Each block's end time is padded by
    1 minute to account for activity that continues after the last recorded event.
    """
    focus = [e for e in events if e.get("type") == "tmux_pane_focus"]
    if not focus:
        return []

    focus.sort(key=lambda e: e.get("timestamp", ""))

    gap_sec = gap_minutes * 60
    blocks = []
    cur = None

    for ev in focus:
        try:
            ts = parse_ts(ev["timestamp"])
        except (ValueError, KeyError):
            continue

        cwd = ev.get("cwd", "")
        sess = ev.get("tmux_session", "")
        key = (sess, cwd)

        if cur is None:
            cur = {
                "start": ts,
                "end": ts,
                "cwd": cwd,
                "tmux_session": sess,
                "key": key,
                "count": 1,
            }
        else:
            delta = (ts - cur["end"]).total_seconds()
            if 0 <= delta <= gap_sec and key == cur["key"]:
                cur["end"] = ts
                cur["count"] += 1
            else:
                blocks.append(_seal_block(cur))
                cur = {
                    "start": ts,
                    "end": ts,
                    "cwd": cwd,
                    "tmux_session": sess,
                    "key": key,
                    "count": 1,
                }

    if cur is not None:
        blocks.append(_seal_block(cur))

    return blocks


def _seal_block(b):
    start = b["start"]
    end = b["end"] + timedelta(minutes=1)
    return {
        "start": start.isoformat(),
        "end": end.isoformat(),
        "duration_min": round((end - start).total_seconds() / 60, 1),
        "cwd": b["cwd"],
        "tmux_session": b["tmux_session"],
        "event_count": b["count"],
    }


def get_toggl_entries(token, start_date, end_date):
    end_plus1 = end_date + timedelta(days=1)
    path = (
        f"/api/v9/me/time_entries"
        f"?start_date={start_date.isoformat()}T00:00:00Z"
        f"&end_date={end_plus1.isoformat()}T00:00:00Z"
    )
    data = toggl_get(path, token)
    return data if isinstance(data, list) else []


def get_workspace_id(token):
    data = toggl_get("/api/v9/me/workspaces", token)
    if data and isinstance(data, list):
        ws_id = data[0].get("id")
        if isinstance(ws_id, int):
            return ws_id
    print(
        "WARNING: could not fetch workspace ID, using default 20968650", file=sys.stderr
    )
    return 20968650


def get_toggl_projects(token, workspace_id):
    data = toggl_get(f"/api/v9/workspaces/{workspace_id}/projects", token)
    return data if isinstance(data, list) else []


def detect_gaps(sessions, activity_blocks, toggl_entries, min_minutes=15):
    """
    Find periods of work not covered by existing Toggl entries.

    Uses tt classify sessions as primary work-period evidence (they carry real
    start/end times). Activity blocks from pane-focus events are merged in as
    supplementary evidence. Candidate periods shorter than min_minutes are
    dropped. Each gap includes the sessions that overlap it.
    """
    toggl_ranges = []
    for entry in toggl_entries:
        start_str = entry.get("start") or entry.get("at", "")
        stop_str = entry.get("stop", "")
        if not start_str or not stop_str:
            continue
        try:
            toggl_ranges.append((parse_ts(start_str), parse_ts(stop_str)))
        except (ValueError, TypeError):
            pass

    def _is_covered(start_dt, end_dt):
        return any(
            (min(end_dt, t_end) - max(start_dt, t_start)).total_seconds() / 60
            >= min_minutes
            for t_start, t_end in toggl_ranges
            if max(start_dt, t_start) < min(end_dt, t_end)
        )

    def _overlapping_sessions(start_dt, end_dt):
        result = []
        for s in sessions:
            try:
                ss = parse_ts(s["start_time"])
                se = parse_ts(s["end_time"])
                if max(start_dt, ss) < min(end_dt, se):
                    result.append(
                        {
                            "session_id": s.get("session_id"),
                            "project_name": s.get("project_name"),
                            "duration_minutes": s.get("duration_minutes"),
                        }
                    )
            except (ValueError, KeyError):
                pass
        return result

    candidates = []

    for s in sessions:
        try:
            s_start = parse_ts(s["start_time"])
            s_end = parse_ts(s["end_time"])
            dur = (s_end - s_start).total_seconds() / 60
            if dur >= min_minutes:
                candidates.append(
                    {
                        "start": s["start_time"],
                        "end": s["end_time"],
                        "start_dt": s_start,
                        "end_dt": s_end,
                        "duration_min": round(dur, 1),
                        "cwd_hint": s.get("project_path", ""),
                        "tmux_session": "",
                        "source": "session",
                    }
                )
        except (ValueError, KeyError):
            pass

    for block in activity_blocks:
        dur = block.get("duration_min", 0)
        if dur < min_minutes:
            continue
        try:
            candidates.append(
                {
                    "start": block["start"],
                    "end": block["end"],
                    "start_dt": parse_ts(block["start"]),
                    "end_dt": parse_ts(block["end"]),
                    "duration_min": dur,
                    "cwd_hint": block.get("cwd", ""),
                    "tmux_session": block.get("tmux_session", ""),
                    "source": "activity_block",
                }
            )
        except (ValueError, KeyError):
            pass

    gaps = []
    for c in candidates:
        if not _is_covered(c["start_dt"], c["end_dt"]):
            gaps.append(
                {
                    "start": c["start"],
                    "end": c["end"],
                    "duration_min": c["duration_min"],
                    "cwd_hint": c["cwd_hint"],
                    "tmux_session": c["tmux_session"],
                    "active_sessions": _overlapping_sessions(
                        c["start_dt"], c["end_dt"]
                    ),
                }
            )

    return gaps


def main():
    parser = argparse.ArgumentParser(description="Collect time-tracking data → JSON")
    parser.add_argument(
        "--date",
        default="today",
        metavar="DATE",
        help="today | yesterday | YYYY-MM-DD | YYYY-MM-DD..YYYY-MM-DD",
    )
    args = parser.parse_args()

    try:
        start_date, end_date = parse_date_arg(args.date)
    except ValueError as e:
        print(f"ERROR: invalid --date '{args.date}': {e}", file=sys.stderr)
        sys.exit(1)

    print(f"=== fill-toggl-collect: {start_date} → {end_date} ===", file=sys.stderr)

    print("[1/6] tt ingest sessions ...", file=sys.stderr)
    run_tt_ingest()

    print("[2/6] tt classify --json ...", file=sys.stderr)
    sessions = get_sessions(start_date, end_date)
    print(f"      {len(sessions)} sessions", file=sys.stderr)

    print("[3/6] tt export --since ...", file=sys.stderr)
    activity_blocks = get_activity_blocks(start_date, end_date)
    print(f"      {len(activity_blocks)} activity blocks", file=sys.stderr)

    print("[4/6] Resolving Toggl token ...", file=sys.stderr)
    token = get_toggl_token()
    if not token:
        print(
            "ERROR: No Toggl API token found.\n"
            "       Set TOGGL_API_TOKEN, or add 'op://Development/Toggl API Key/credential' to 1Password.",
            file=sys.stderr,
        )
        sys.exit(1)

    toggl_entries = get_toggl_entries(token, start_date, end_date)
    print(f"      {len(toggl_entries)} existing Toggl entries", file=sys.stderr)

    print("[5/6] Toggl workspace + projects ...", file=sys.stderr)
    workspace_id = get_workspace_id(token)
    toggl_projects = get_toggl_projects(token, workspace_id)
    print(
        f"      workspace {workspace_id}, {len(toggl_projects)} projects",
        file=sys.stderr,
    )

    print("[6/6] Detecting gaps ...", file=sys.stderr)
    gaps = detect_gaps(sessions, activity_blocks, toggl_entries)
    print(f"      {len(gaps)} gaps (>= 15 min, not covered by Toggl)", file=sys.stderr)

    output = {
        "date_range": {"start": start_date.isoformat(), "end": end_date.isoformat()},
        "sessions": sessions,
        "activity_blocks": activity_blocks,
        "existing_entries": toggl_entries,
        "gaps": gaps,
        "toggl_projects": toggl_projects,
        "workspace_id": workspace_id,
    }

    json.dump(output, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    sys.stdout.flush()
    print("=== done ===", file=sys.stderr)


if __name__ == "__main__":
    main()
