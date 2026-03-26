# Oter → Waybar: gitignored secrets/oter.env, wrapped Waybar, WebSocket daemon, jq merge/slice, Sway autostart helpers.
{ config, pkgs, lib, ... }:

let
  # Gitignored file: secrets/oter.env (see secrets/oter.env.example). Sourced by the Waybar wrapper so custom modules inherit OTTER_*.
  oterEnvFile = "${config.users.users.bansyne.home}/bansyne-nix-os-config/secrets/oter.env";

  # Same wrapper must be used from Sway bindsym (non-login env) and from a normal shell so OTTER_* / paths match.
  waybarOterWrappedBin = pkgs.writeShellScriptBin "waybar" ''
    if [[ -r "${oterEnvFile}" ]]; then
      set -a
      # shellcheck disable=SC1090
      source "${oterEnvFile}"
      set +a
    fi
    exec ${pkgs.waybar}/bin/waybar -c /etc/waybar/config -s /etc/waybar/style.css "$@"
  '';
  # Oter → Waybar: WebSocket (timers/notifications) drives refreshes; merged JSON matches prior two-module content.
  oterWaybarSignal = 8;
  oterWaybarDaemonVersion = "2026-03-24-dashboard-datetime-seconds-v1";

  # Dashboard nextTask/nextHabit: tries common field names for expected vs deadline; countdown uses jq now vs deadline epoch.
  oterWaybarMergeJq = pkgs.writeText "waybar-oter-merge.jq" ''
    def dt:
      if ($dash | type) == "object" then $dash else {} end;
    def safe_lists:
      if ($lists | type) == "array" then $lists
      elif ($lists | type) == "object" and (($lists.lists | type) == "array") then $lists.lists
      elif ($lists | type) == "object" and (($lists.data | type) == "array") then $lists.data
      elif ($lists | type) == "object" and (($lists.items | type) == "array") then $lists.items
      else [] end;

    # Lists payload varies: array of list-objects, or wrapper object; timers may be array or object map.
    def timers_flat:
      safe_lists[]
      | select(type == "object")
      | .timers
      | if . == null then empty
        elif type == "array" then .[]
        elif type == "object" then .[]
        else empty end
      | select(type == "object");

    def truthy_enabled:
      . as $e | (($e.enabled // true) == true or $e.enabled == "true" or $e.enabled == 1);

    def active_timer:
      [ timers_flat
        | select(truthy_enabled)
        | select(.state == "RUNNING" or .state == "PAUSED" or .state == "running" or .state == "paused") ]
      | sort_by(if (.state == "RUNNING" or .state == "running") then 0 else 1 end)
      | .[0];

    def as_int:
      if type == "number" then (. | floor)
      elif type == "string" then ((try tonumber catch 0) | floor)
      else 0 end;

    def mmss:
      (. | as_int) as $sec |
      ($sec / 60 | floor | tostring) + ":"
      + ($sec % 60 | if . < 10 then "0" + (. | tostring) else (. | tostring) end);

    def task_item: (dt.nextTask // null);
    def habit_item: (dt.nextHabit // null);

    def task_title:
      if (task_item | type) == "object" and task_item != null then (task_item.name // "—")
      else "—" end;

    def habit_title:
      if (habit_item | type) == "object" and habit_item != null then (habit_item.name // "—")
      else "—" end;

    # Use null when nothing matches — never `// empty` here (empty would abort the whole merge object).
    def first_time(o; keys):
      if (o | type) != "object" then null
      else keys | map(o[.]) | [.[] | select(. != null and (. != ""))] | first
      end;

    def exp_of(o):
      first_time(o; ["expectedDateTime","scheduledDateTime","scheduledAt","startDateTime","planDateTime","expectedAt","plannedDateTime","startDate","date","scheduledDate"]);
    def dl_of(o):
      first_time(o; ["deadline","dueDateTime","dueDate","endDateTime","endsAt","expiresAt","endDate","dueAt","completeBy"]);

    def rough_hm(v):
      if v == null or v == "" then "—"
      elif (v | type) == "number" then (
          (if v > 1000000000000 then v / 1000 else v end) as $sec | ($sec | strftime("%H:%M"))
        )
      elif (v | type) == "string" then (
          if (v | test("^[0-2][0-9]:[0-5][0-9]''$")) then v
          else ((try (v | capture("T(?<hm>[0-2][0-9]:[0-5][0-9])") | .hm) catch null) // "—") end
        )
      else "—" end;

    def to_epoch_sec(v):
      if v == null or v == "" then null
      elif (v | type) == "number" then (if v > 1000000000000 then v / 1000 else v end | floor)
      elif (v | type) == "string" then (
          try (
            if (v | test("Z''$|[+-][0-9]{2}:[0-9]{2}''$")) then (v | fromdateiso8601)
            elif (v | test("T[0-9]{2}:[0-9]{2}")) then (v + "Z" | fromdateiso8601)
            else (v + "T12:00:00Z" | fromdateiso8601) end
          ) catch null
        )
      else null end;

    def countdown_from_deadline(dl_epoch):
      if dl_epoch == null then "—"
      else
        (dl_epoch - now) as $sec |
        if (($sec | if . < 0 then -. else . end) < 90) then (
            if $sec >= 0 then (($sec | floor | tostring) + "s") else ((-$sec | floor | tostring) + "s !") end
          )
        elif (($sec | if . < 0 then -. else . end) < 3600) then (
            if $sec >= 0 then (($sec / 60 | floor | tostring) + "m") else ((-$sec / 60 | floor | tostring) + "m !") end
          )
        elif (($sec | if . < 0 then -. else . end) < 86400) then (
            if $sec >= 0 then (($sec / 3600 | floor | tostring) + "h") else ((-$sec / 3600 | floor | tostring) + "h !") end
          )
        else (
            if $sec >= 0 then (($sec / 86400 | floor | tostring) + "d") else ((-$sec / 86400 | floor | tostring) + "d !") end
          )
        end
      end;

    def short_name(s; max):
      if s == null or s == "" then "—"
      elif (s | length) <= max then s
      else s[0:max - 1] + "…" end;

    def row_task:
      if (task_item | type) != "object" or task_item == null then "—"
      else
        task_item as $t |
        (short_name($t.name; 42)) as $nm |
        (rough_hm(exp_of($t))) as $ex |
        (rough_hm(dl_of($t))) as $dd |
        (to_epoch_sec(dl_of($t))) as $de |
        ($nm + "  ·  exp " + $ex + "  ·  dl " + $dd + "  ·  \u23f1 " + (countdown_from_deadline($de)))
      end;

    def row_habit:
      if (habit_item | type) != "object" or habit_item == null then "—"
      else
        habit_item as $h |
        (short_name($h.name; 42)) as $nm |
        (rough_hm(exp_of($h))) as $ex |
        (rough_hm(dl_of($h))) as $dd |
        (to_epoch_sec(dl_of($h))) as $de |
        ($nm + "  ·  exp " + $ex + "  ·  dl " + $dd + "  ·  \u23f1 " + (countdown_from_deadline($de)))
      end;

    def timer_line:
      if active_timer == null then "⏱ —"
      else
        (if (active_timer.state == "PAUSED" or active_timer.state == "paused") then "⏸ " else "▶ " end)
        + (short_name(active_timer.name; 32))
        + " "
        + ((active_timer.remainingSeconds | as_int) | mmss)
      end;

    def card_sev:
      if . == "bad" then 2 elif . == "medium" then 1 else 0 end;
    def worst_cards:
      ([(dt.tasksCardStatus // "medium") | card_sev, (dt.habitsCardStatus // "medium") | card_sev] | max);
    def overdue_sev:
      if ((dt.overdueTasks // 0 | as_int) > 0) or ((dt.overdueHabits // 0 | as_int) > 0) then 1 else 0 end;
    def worst:
      ([worst_cards, overdue_sev] | max);

    def state_label:
      if worst >= 2 then "catch up"
      elif worst >= 1 then "balance"
      else "on track" end;

    def tooltip_body:
      (
        "── Timer ──\n" + timer_line + "\n\n"
        + "── Next task ──\n" + task_title + "\n"
        + "  expected: " + (if (task_item|type)=="object" then (rough_hm(exp_of(task_item))) else "—" end) + "\n"
        + "  deadline: " + (if (task_item|type)=="object" then (rough_hm(dl_of(task_item))) else "—" end) + "\n"
        + "  countdown: " + (if (task_item|type)=="object" then (countdown_from_deadline(to_epoch_sec(dl_of(task_item)))) else "—" end) + "\n\n"
        + "── Next habit ──\n" + habit_title + "\n"
        + "  expected: " + (if (habit_item|type)=="object" then (rough_hm(exp_of(habit_item))) else "—" end) + "\n"
        + "  deadline: " + (if (habit_item|type)=="object" then (rough_hm(dl_of(habit_item))) else "—" end) + "\n"
        + "  countdown: " + (if (habit_item|type)=="object" then (countdown_from_deadline(to_epoch_sec(dl_of(habit_item)))) else "—" end) + "\n\n"
        + "Overdue  tasks: \(dt.overdueTasks // 0) · habits: \(dt.overdueHabits // 0)\n"
        + "Cards  tasks: \(dt.tasksCardStatus // "?") · habits: \(dt.habitsCardStatus // "?")"
      );

    def clock_suffix:
      if ($clock | length) == 0 then "" else " · " + $clock end;

    def sev_class:
      if worst >= 2 then "oter-bad" elif worst >= 1 then "oter-medium" else "oter-good" end;

    {
      text_timer: (timer_line + clock_suffix),
      text_task: ("✓  " + row_task),
      text_habit: ("◆  " + row_habit),
      text_state: ("\u25C6  " + state_label + clock_suffix),
      text: (timer_line + "  \u2502  " + row_task + "  \u2502  " + row_habit + "  \u2502  " + state_label + clock_suffix),
      tooltip: tooltip_body,
      class: sev_class
    }
  '';

  oterWaybarSliceJq = pkgs.writeText "waybar-oter-slice.jq" ''
    if ''$s == "timer" then { text: (.text_timer // .text // "—"), tooltip: (.tooltip // ""), class: (.class // "oter-good") }
    elif ''$s == "task" then { text: (.text_task // "—"), tooltip: (.tooltip // ""), class: (.class // "oter-good") }
    elif ''$s == "habit" then { text: (.text_habit // "—"), tooltip: (.tooltip // ""), class: (.class // "oter-good") }
    elif ''$s == "state" then { text: (.text_state // "—"), tooltip: (.tooltip // ""), class: (.class // "oter-good") }
    else { text: (.text // "—"), tooltip: (.tooltip // ""), class: (.class // "oter-good") } end
  '';

  # Poll fallback for Waybar if daemon has not written state yet (must match signal number below).
  oterWaybarAuthBash = ''
    BASE="''${OTTER_BASE_URL:-http://127.0.0.1:8080}"
    TOKEN="''${OTTER_API_TOKEN:-}"
    if [[ -z "''${TOKEN}" && -n "''${HOME:-}" && -f "''${HOME}/.config/oter/api_token" ]]; then
      TOKEN="$(tr -d '\n' < "''${HOME}/.config/oter/api_token" || true)"
    fi
    if [[ -z "''${TOKEN}" ]]; then
      jq -nc '{text:"Oter: no token",tooltip:"Set OTTER_API_TOKEN, secrets/oter.env, or ~/.config/oter/api_token",class:"oter-error"}'
      exit 0
    fi
    AUTH=( -H "Authorization: Bearer ''${TOKEN}" -H "X-Platform: DESKTOP" )
  '';

  oterWaybarPollBin = pkgs.writeShellScriptBin "waybar-oter-poll" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [ pkgs.curl pkgs.jq pkgs.coreutils ]}"
    ${oterWaybarAuthBash}
    # API expects dd/MM/yyyy HH:mm (seconds → dashboard_datetime_invalid on many builds).
    if [[ "''${OTTER_DASHBOARD_TIME_WITH_SECONDS:-0}" == "1" ]]; then
      DT="$(date +%d/%m/%Y\ %H:%M:%S)"
    else
      DT="$(date +%d/%m/%Y\ %H:%M)"
    fi
    DASH="$(curl -sfS -G "$BASE/api/v1/dashboard" "''${AUTH[@]}" --data-urlencode "dateTime=$DT" 2>/dev/null | jq -c . 2>/dev/null || true)"
    LISTS="$(curl -sfS "$BASE/api/v1/timers/lists" "''${AUTH[@]}" 2>/dev/null | jq -c . 2>/dev/null || true)"
    [[ -z "''${DASH}" || "''${DASH}" == "null" ]] && DASH='{}'
    [[ -z "''${LISTS}" ]] && LISTS='[]'
    exec jq -nc --argjson dash "''${DASH}" --argjson lists "''${LISTS}" --arg clock "" -f ${oterWaybarMergeJq}
  '';

  oterWaybarStateCatBin = pkgs.writeShellScriptBin "waybar-oter-from-state" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [ pkgs.jq pkgs.coreutils ]}"
    STATE="''${OTTER_WAYBAR_STATE_FILE:-''${XDG_RUNTIME_DIR:-/tmp}/oter-waybar-state.json}"
    if [[ -f "''${STATE}" ]]; then
      exec cat "''${STATE}"
    fi
    exec jq -nc '{text:"Oter: waiting for daemon",tooltip:"waybar-oter-daemon should start from Sway; check logs / token",class:"oter-error"}'
  '';

  # One argument: timer | task | habit | state — reads merged state JSON and emits Waybar JSON for that module.
  # Always prints exactly one JSON line (Waybar hides the module if exec exits non‑zero or prints nothing).
  oterWaybarSliceBin = pkgs.writeShellScriptBin "waybar-oter-slice" ''
    set -u
    export PATH="${lib.makeBinPath [ pkgs.jq pkgs.coreutils ]}"
    SLICE="''${1:-}"
    STATE="''${OTTER_WAYBAR_STATE_FILE:-''${XDG_RUNTIME_DIR:-/tmp}/oter-waybar-state.json}"

    fallback_waiting() {
      jq -nc --arg s "''${SLICE}" '
        if $s == "timer" then
          {text:"⏱ …",tooltip:"No state file yet — waybar-oter-daemon should be running (see OTTER_WAYBAR_LOG_FILE).",class:"oter-error"}
        elif $s == "task" then
          {text:"✓ …",tooltip:"No state file yet — waybar-oter-daemon should be running.",class:"oter-error"}
        elif $s == "habit" then
          {text:"◆ …",tooltip:"No state file yet — waybar-oter-daemon should be running.",class:"oter-error"}
        elif $s == "state" then
          {text:"◆ …",tooltip:"No state file yet — waybar-oter-daemon should be running.",class:"oter-error"}
        else
          {text:"Oter …",tooltip:"waybar-oter-slice: use arg timer|task|habit|state",class:"oter-error"}
        end
      '
    }

    fallback_bad_state() {
      jq -nc --arg s "''${SLICE}" --arg p "''${STATE}" \
        '{text:("Oter: bad state"),tooltip:("jq could not read " + $p + "; see daemon log / OTTER_WAYBAR_DEBUG=1"),class:"oter-error"}'
    }

    if [[ ! -f "''${STATE}" ]]; then
      fallback_waiting
      exit 0
    fi
    out="$(jq --arg s "''${SLICE}" -c -f ${oterWaybarSliceJq} "''${STATE}" 2>/dev/null || true)"
    if [[ -z "''${out}" ]]; then
      fallback_bad_state
      exit 0
    fi
    printf '%s\n' "''${out}"
    exit 0
  '';

  oterWaybarDaemonBin = pkgs.writeShellScriptBin "waybar-oter-daemon" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [ pkgs.curl pkgs.jq pkgs.coreutils pkgs.websocat pkgs.procps ]}"

    if [[ -r "${oterEnvFile}" ]]; then
      set -a
      # shellcheck disable=SC1090
      source "${oterEnvFile}"
      set +a
    fi

    BASE="''${OTTER_BASE_URL:-http://127.0.0.1:8080}"
    TOKEN="''${OTTER_API_TOKEN:-}"
    [[ -z "''${TOKEN}" && -n "''${HOME:-}" && -f "''${HOME}/.config/oter/api_token" ]] \
      && TOKEN="$(tr -d '\n' < "''${HOME}/.config/oter/api_token" || true)"

    if [[ -z "''${TOKEN}" ]]; then
      echo "waybar-oter-daemon: set OTTER_API_TOKEN, ${oterEnvFile}, or ~/.config/oter/api_token" >&2
      exit 1
    fi

    SIG="''${WAYBAR_SIGNAL:-${toString oterWaybarSignal}}"
    STATE_FILE="''${OTTER_WAYBAR_STATE_FILE:-''${XDG_RUNTIME_DIR:-/tmp}/oter-waybar-state.json}"
    DASH_CACHE="''${OTTER_WAYBAR_DASH_CACHE:-''${STATE_FILE%.json}.dashboard.json}"
    TIMER_MS="''${OTTER_WAYBAR_TIMER_REFRESH_MS:-1000}"
    TIMER_SEC=$((TIMER_MS / 1000))
    (( TIMER_SEC < 1 )) && TIMER_SEC=1
    DEBUG="''${OTTER_WAYBAR_DEBUG:-0}"
    LOG_FILE="''${OTTER_WAYBAR_LOG_FILE:-''${XDG_RUNTIME_DIR:-/tmp}/oter-waybar-daemon.log}"
    PERIODIC_FULL_REFRESH_SEC="''${OTTER_WAYBAR_PERIODIC_FULL_REFRESH_SEC:-60}"
    VERBOSE_HTTP="''${OTTER_WAYBAR_VERBOSE_HTTP:-0}"
    TRACE_WS_RAW="''${OTTER_WAYBAR_TRACE_WS_RAW:-0}"
    TRACE_STATE_PREVIEW="''${OTTER_WAYBAR_TRACE_STATE_PREVIEW:-0}"

    debug_log() {
      [[ "''${DEBUG}" == "1" ]] || return 0
      printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "''${LOG_FILE}"
    }

    always_log() {
      printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "''${LOG_FILE}"
    }

    # SIGRTMIN+N must reach the real Waybar PID. Match processes named waybar whose cmdline references /etc/waybar
    # (pgrep -f '/bin/waybar -c /etc/waybar' misses some argv orderings and non-/bin store paths).
    notify_waybar_refresh() {
      local pid n=0 cmd
      always_log "notify_waybar: RTMIN+''${SIG} scanning waybar PIDs"
      while read -r pid; do
        [[ -z "''${pid}" ]] && continue
        [[ -r "/proc/''${pid}/cmdline" ]] || continue
        cmd="$(tr '\0' ' ' <"/proc/''${pid}/cmdline" 2>/dev/null || true)"
        [[ "''${cmd}" == *waybar* ]] || continue
        [[ "''${cmd}" == */etc/waybar* ]] || continue
        if kill "-RTMIN+''${SIG}" "''${pid}" 2>/dev/null; then
          n=$((n + 1))
          always_log "notify_waybar: signaled pid=''${pid} cmd=''${cmd:0:120}…"
        fi
      done < <(pgrep -x waybar 2>/dev/null || true)
      always_log "notify_waybar: RTMIN+''${SIG} signals_delivered=''${n}"
    }

    trap 'ec=$?; debug_log "fatal: exit_code=''${ec} line=''${LINENO} cmd=$(printf %q "$BASH_COMMAND")"' ERR
    trap 'debug_log "daemon_exit: code=$?"' EXIT

    derive_ws_base() {
      local b="$1"
      if [[ "$b" == https://* ]]; then
        echo "wss://''${b#https://}"
      else
        echo "ws://''${b#http://}"
      fi
    }

    WS_BASE="''${OTTER_WS_URL:-$(derive_ws_base "$BASE")}"
    WS_URL="''${WS_BASE%/}/api/v1/timers/notifications"

    AUTH=( -H "Authorization: Bearer ''${TOKEN}" -H "X-Platform: DESKTOP" )

    dash_is_ok() {
      echo "$1" | jq -e 'type == "object" and (.error | type) != "string"' >/dev/null 2>&1
    }

    merge_to_waybar() {
      local dash_json="$1"
      local lists_json="$2"
      local merged clock_arg=""
      [[ "''${OTTER_WAYBAR_BAR_CLOCK:-0}" == "1" ]] && clock_arg="$(date '+%H:%M:%S')"
      merged=""
      jq_err="$(mktemp)"
      if ! merged="$(jq -nc --argjson dash "$dash_json" --argjson lists "$lists_json" --arg clock "$clock_arg" -f ${oterWaybarMergeJq} 2>"''${jq_err}")"; then
        always_log "merge_to_waybar: jq merge exit non-zero; dash_bytes=''${#dash_json} lists_bytes=''${#lists_json}"
        always_log "merge_to_waybar: jq_stderr=$(tr '\n' '|' <"''${jq_err}" | head -c 500)"
      fi
      rm -f "''${jq_err}"
      if [[ -z "''${merged}" ]] || ! printf '%s' "''${merged}" | jq -e . >/dev/null 2>&1; then
        always_log "merge_to_waybar: invalid or empty merged JSON — writing fallback state"
        jq -nc \
          --arg tip "Merge jq failed or produced invalid JSON. Often API sends remainingSeconds/overdue* as strings; check ''${LOG_FILE}" \
          '{text_timer:"⏱ —",text_task:"✓ —",text_habit:"◆ —",text_state:"◆ —",text:"Oter: merge error",tooltip:$tip,class:"oter-error"}' \
          >"''${STATE_FILE}.tmp" && mv "''${STATE_FILE}.tmp" "''${STATE_FILE}"
        notify_waybar_refresh
        return
      fi
      if [[ "''${TRACE_STATE_PREVIEW}" == "1" ]]; then
        debug_log "state_preview: $(echo "''${merged}" | jq -c . 2>/dev/null || echo '<invalid-json>')"
      fi
      printf '%s' "''${merged}" >"''${STATE_FILE}.tmp" && mv "''${STATE_FILE}.tmp" "''${STATE_FILE}"
      debug_log "merge_to_waybar: state_bytes=$(wc -c < "''${STATE_FILE}" 2>/dev/null || echo 0)"
      notify_waybar_refresh
      debug_log "merge_to_waybar: state_file=''${STATE_FILE} signal=''${SIG}"
    }

    fetch_json() {
      # Usage: fetch_json OUT_VAR URL [curl args...]
      local __out_var="$1"; shift
      local __url="$1"; shift
      local __tmp_body __tmp_code __code __body
      __tmp_body="$(mktemp)"
      __tmp_code="$(mktemp)"
      curl -sS -w '%{http_code}' -o "$__tmp_body" "$__url" "$@" >"$__tmp_code" 2>>"''${LOG_FILE}" || true
      __code="$(cat "$__tmp_code" 2>/dev/null || echo "000")"
      __body="$(cat "$__tmp_body" 2>/dev/null || echo "{}")"
      rm -f "$__tmp_body" "$__tmp_code"
      if [[ "''${VERBOSE_HTTP}" == "1" || "''${DEBUG}" == "1" ]]; then
        debug_log "http: url=''${__url} code=''${__code} bytes=''${#__body}"
      fi
      if [[ "$__code" =~ ^2[0-9][0-9]$ ]]; then
        printf -v "$__out_var" '%s' "$__body"
      else
        if [[ "''${VERBOSE_HTTP}" == "1" || "''${DEBUG}" == "1" ]]; then
          debug_log "http_non_2xx: url=''${__url} code=''${__code} body=$(echo "$__body" | jq -c . 2>/dev/null || echo "$__body" | tr '\n' ' ')"
        fi
        printf -v "$__out_var" '%s' '{"error":"network"}'
      fi
    }

    write_state_full() {
      local DT DASH LISTS
      if [[ "''${OTTER_DASHBOARD_TIME_WITH_SECONDS:-0}" == "1" ]]; then
        DT="$(date +%d/%m/%Y\ %H:%M:%S)"
      else
        DT="$(date +%d/%m/%Y\ %H:%M)"
      fi
      debug_log "write_state_full: dateTime=''${DT}"
      fetch_json DASH "$BASE/api/v1/dashboard" "''${AUTH[@]}" -G --data-urlencode "dateTime=$DT"
      fetch_json LISTS "$BASE/api/v1/timers/lists" "''${AUTH[@]}"
      [[ -z "$LISTS" || "$LISTS" == '{"error":"network"}' ]] && LISTS='[]'

      if dash_is_ok "$DASH"; then
        debug_log "write_state_full: dashboard=ok"
        always_log "dashboard_digest: $(echo "$DASH" | jq -c '{
          taskId:(.nextTask.id//null),
          taskName:(.nextTask.name//null),
          habitId:(.nextHabit.id//null),
          habitName:(.nextHabit.name//null),
          overdueT:(.overdueTasks//null),
          overdueH:(.overdueHabits//null),
          tasksCard:(.tasksCardStatus//null),
          habitsCard:(.habitsCardStatus//null)
        }' 2>/dev/null || echo '<no-parse>')"
        printf '%s' "''${DASH}" >"''${DASH_CACHE}.tmp" && mv "''${DASH_CACHE}.tmp" "''${DASH_CACHE}"
        merge_to_waybar "$DASH" "$LISTS"
      else
        debug_log "write_state_full: dashboard=error payload=$(echo "''${DASH}" | jq -c . 2>/dev/null || echo '<invalid-json>')"
        echo "waybar-oter-daemon: dashboard request failed or API error; keeping cache if any" >&2
        if [[ -f "''${DASH_CACHE}" ]]; then
          local CACHED
          CACHED="$(cat "''${DASH_CACHE}")"
          debug_log "write_state_full: using cached dashboard"
          merge_to_waybar "$CACHED" "''${LISTS}"
        else
          jq -nc \
            --arg err "$(echo "''${DASH}" | jq -r '.message // .error // "dashboard error"')" \
            '{text: ("Oter: " + $err), tooltip: $err, class: "oter-error"}' \
            >"''${STATE_FILE}.tmp" && mv "''${STATE_FILE}.tmp" "''${STATE_FILE}"
          notify_waybar_refresh
          debug_log "write_state_full: no cache available; wrote oter-error state"
        fi
      fi
    }

    write_state_lists_only() {
      local LISTS CACHED
      debug_log "write_state_lists_only"
      fetch_json LISTS "$BASE/api/v1/timers/lists" "''${AUTH[@]}"
      [[ -z "$LISTS" || "$LISTS" == '{"error":"network"}' ]] && LISTS='[]'
      if [[ ! -f "''${DASH_CACHE}" ]]; then
        debug_log "write_state_lists_only: missing dashboard cache -> full refresh"
        write_state_full
        return
      fi
      CACHED="$(cat "''${DASH_CACHE}")"
      merge_to_waybar "$CACHED" "''${LISTS}"
    }

    write_state_full

    last_lists_fetch=0
    always_log "daemon_start: version=${oterWaybarDaemonVersion} base=''${BASE} ws_url=''${WS_URL} state_file=''${STATE_FILE} timer_sec=''${TIMER_SEC} periodic_full_refresh_sec=''${PERIODIC_FULL_REFRESH_SEC}"
    debug_log "daemon_start: base=''${BASE} ws_url=''${WS_URL} state_file=''${STATE_FILE} timer_sec=''${TIMER_SEC} periodic_full_refresh_sec=''${PERIODIC_FULL_REFRESH_SEC}"

    periodic_pid=""
    if (( PERIODIC_FULL_REFRESH_SEC > 0 )); then
      (
        while true; do
          sleep "''${PERIODIC_FULL_REFRESH_SEC}"
          debug_log "periodic_full_refresh: trigger"
          write_state_full
        done
      ) &
      periodic_pid="$!"
      debug_log "periodic_full_refresh: started background pid=''${periodic_pid}"
    fi

    cleanup() {
      if [[ -n "''${periodic_pid}" ]]; then
        kill "''${periodic_pid}" 2>/dev/null || true
      fi
    }
    trap cleanup EXIT

    while true; do
      always_log "ws_connect: opening ''${WS_URL}"
      debug_log "ws_connect: opening ''${WS_URL}"
      always_log "ws_command: sleep_inf | websocat -n -t -H Authorization -H X-Platform ''${WS_URL}"
      debug_log "ws_command: sleep_inf | websocat -n -t (Bearer redacted) ''${WS_URL}"
      ws_last_idle_log="$(date +%s)"
      while IFS= read -r line; do
        [[ "''${TRACE_WS_RAW}" == "1" ]] && debug_log "ws_raw: ''${line}"
        type="$(echo "$line" | jq -r '.type // empty' 2>/dev/null || true)"
        debug_log "ws_event: type=''${type:-<none>} payload=$(echo "$line" | jq -c . 2>/dev/null || echo '<invalid-json>')"
        case "$type" in
          AgendaRefresh)
            write_state_full
            ;;
          TimerUpdate|TimerListUpdate|TimerListRefresh)
            now_s="$(date +%s)"
            if (( now_s - last_lists_fetch >= TIMER_SEC )); then
              last_lists_fetch=$now_s
              write_state_lists_only
            else
              debug_log "ws_event: throttled lists-only refresh"
            fi
            ;;
          *)
            debug_log "ws_event: ignored event type='${type:-unknown}'"
            ;;
        esac

        now_s="$(date +%s)"
        if (( now_s - ws_last_idle_log >= 30 )); then
          debug_log "ws_idle: no messages for 30s"
          ws_last_idle_log=$now_s
        fi
      done < <(( sleep infinity || true ) | websocat -n -t \
        -H="Authorization: Bearer ''${TOKEN}" \
        -H="X-Platform: DESKTOP" \
        "''${WS_URL}" 2>>"''${LOG_FILE}")

      ws_ec=$?
      always_log "ws_process_exit: exit_code=''${ws_ec}"
      debug_log "ws_process_exit: exit_code=''${ws_ec}"
      always_log "ws_disconnect: reconnecting in 2s"
      debug_log "ws_disconnect: reconnecting in 2s"
      sleep 2
    done
  '';

  # Keep Oter daemon alive; useful when websocket/auth intermittently drops.
  oterWaybarDaemonRunBin = pkgs.writeShellScriptBin "waybar-oter-daemon-run" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.procps pkgs.bash ]}"

    if [[ -r "${oterEnvFile}" ]]; then
      set -a
      # shellcheck disable=SC1090
      source "${oterEnvFile}"
      set +a
    fi

    LOG_FILE="''${OTTER_WAYBAR_LOG_FILE:-''${XDG_RUNTIME_DIR:-/tmp}/oter-waybar-daemon.log}"
    while true; do
      ${oterWaybarDaemonBin}/bin/waybar-oter-daemon >>"''${LOG_FILE}" 2>&1 || true
      printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "daemon_runner: daemon exited; restarting in 2s" >> "''${LOG_FILE}"
      sleep 2
    done
  '';

  # Restart helper used by Sway keybind (keeps bindsym command simple and reliable).
  waybarRestartAllBin = pkgs.writeShellScriptBin "waybar-restart-all" ''
    set -euo pipefail
    export PATH="${lib.makeBinPath [ pkgs.procps pkgs.coreutils pkgs.bash pkgs.glibc.bin ]}"
    # Sway `bindsym ... exec` often omits login-shell env; align with an interactive terminal.
    : "''${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
    export XDG_RUNTIME_DIR
    if [[ -z "''${HOME:-}" ]]; then
      HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
      export HOME
    fi
    if [[ -r "${oterEnvFile}" ]]; then
      set -a
      # shellcheck disable=SC1090
      source "${oterEnvFile}"
      set +a
    fi
    pkill -f '[w]aybar-oter-daemon-run' 2>/dev/null || true
    pkill -f '[w]aybar-oter-daemon' 2>/dev/null || true
    ${oterWaybarDaemonRunBin}/bin/waybar-oter-daemon-run &
    pkill -f '/bin/waybar -c /etc/waybar' 2>/dev/null || true
    while pgrep -f '/bin/waybar -c /etc/waybar' >/dev/null; do sleep 0.1; done
    exec ${waybarOterWrappedBin}/bin/waybar
  '';

  # Sway `exec sh -c 'pgrep -f /etc/waybar/config ...'` matches its own argv and never starts Waybar. Use a helper whose cmdline does not contain those patterns.
  swayOterWaybarAutostartBin = pkgs.writeShellScriptBin "sway-autostart-oter-waybar" ''
    set -eu
    export PATH="${lib.makeBinPath [ pkgs.procps pkgs.coreutils pkgs.glibc.bin ]}"
    : "''${XDG_RUNTIME_DIR:=/run/user/$(id -u)}"
    export XDG_RUNTIME_DIR
    if [[ -z "''${HOME:-}" ]]; then
      HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"
      export HOME
    fi
    if [[ -r "${oterEnvFile}" ]]; then
      set -a
      # shellcheck disable=SC1090
      source "${oterEnvFile}"
      set +a
    fi
    if ! pgrep -f '/bin/waybar-oter-daemon-run' >/dev/null 2>&1; then
      ${oterWaybarDaemonRunBin}/bin/waybar-oter-daemon-run &
    fi
    if pgrep -f '/bin/waybar -c /etc/waybar' >/dev/null 2>&1; then
      exit 0
    fi
    exec ${waybarOterWrappedBin}/bin/waybar
  '';

in
{
  options.custom.otter.waybar = {
    sliceBin = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.package;
      default = oterWaybarSliceBin;
      description = "Package providing waybar-oter-slice (referenced from sway Waybar JSON).";
    };
    signal = lib.mkOption {
      internal = true;
      readOnly = true;
      type = lib.types.int;
      default = oterWaybarSignal;
      description = "SIGRTMIN+signal used to refresh Oter custom Waybar modules.";
    };
  };

  config = {
    environment.systemPackages = [
      waybarOterWrappedBin
      oterWaybarDaemonRunBin
      oterWaybarDaemonBin
      oterWaybarStateCatBin
      oterWaybarSliceBin
      oterWaybarPollBin
      waybarRestartAllBin
      swayOterWaybarAutostartBin
    ];

    systemd.user.services.waybar.wantedBy = lib.mkForce [ ];
    systemd.user.services.waybar.unitConfig = {
      PartOf = [ "sway-session.target" ];
      After = [ "sway-session.target" ];
    };
    systemd.user.services.waybar.serviceConfig.ExecStart = lib.mkForce [
      "" # clear default
      "${waybarOterWrappedBin}/bin/waybar -c /etc/waybar/config -s /etc/waybar/style.css"
    ];

    environment.etc."sway/config.d/waybar-reload.conf".source = pkgs.writeText "waybar-reload.conf" ''
      exec --no-startup-id ${swayOterWaybarAutostartBin}/bin/sway-autostart-oter-waybar
      bindsym $mod+Shift+w exec ${waybarRestartAllBin}/bin/waybar-restart-all
    '';
  };
}
