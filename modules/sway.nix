# Sway window manager configuration
# Includes XDG portal configuration for Wayland applications

{ config, pkgs, lib, ... }:

let
  # Gitignored file: secrets/oter.env (see secrets/oter.env.example). Sourced by the Waybar wrapper so custom modules inherit OTTER_*.
  oterEnvFile = "${config.users.users.bansyne.home}/bansyne-nix-os-config/secrets/oter.env";

  # Default Sway config with the built-in bar block removed (Waybar is our only bar).
  # Must append include so config.d (nixos.conf, waybar-reload, etc.) is loaded.
  swayConfigWithoutBar = pkgs.runCommand "sway-config-no-bar" { } ''
    awk '
      /^# Read.*sway-bar/ { inbar = 1; depth = 0; next }
      inbar {
        if (/bar \{/ || /\{/) depth++
        if (/\}/) depth--
        if (depth <= 0) inbar = 0
        next
      }
      /# Special key to take a screenshot with grim/ { next }
      /bindsym Print exec grim/ { next }
      /# Your preferred terminal emulator/ { next }
      /^set \$term / { next }
      /# Start a terminal/ { next }
      /bindsym \$mod\+Return exec \$term/ { next }
      { print }
    ' ${pkgs.sway}/etc/sway/config > $out
    echo "" >> $out
    echo "include /etc/sway/config.d/*" >> $out
  '';
  # SDDM login theme (flavor: latte/frappe/macchiato/mocha; accent: blue/mauve/teal/...). Theme name must match: catppuccin-{flavor}-{accent}
  sddmTheme = pkgs.catppuccin-sddm.override { flavor = "macchiato"; accent = "teal"; };

  # Absolute paths: Sway's `exec` often runs without $HOME set, so $HOME/wallpapers never matched.
  wallpaperSearchRoots = [
    "${config.users.users.bansyne.home}/wallpapers"
    "${config.users.users.bansyne.home}/bansyne-nix-os-config/wallpapers"
  ];
  swayWallpaperRandomBin = pkgs.writeShellScriptBin "sway-wallpaper-random" ''
    export PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.findutils pkgs.sway pkgs.swaybg pkgs.procps ]}"
    dirs=()
    ${lib.concatMapStrings (d: ''
    [[ -d "${d}" ]] && dirs+=("${d}")
    '') wallpaperSearchRoots}
    if (( ''${#dirs[@]} == 0 )); then
      echo "sway-wallpaper-random: no wallpaper directories exist" >&2
      exit 1
    fi
    # -xtype f: include symlinks to images (-type f alone skips symlinks, so git-annex / links look "empty").
    IMG=$(find -L "''${dirs[@]}" -xtype f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) 2>/dev/null | shuf -n1)
    if [[ -z "$IMG" ]]; then
      echo "sway-wallpaper-random: no images under ''${dirs[*]}" >&2
      exit 1
    fi
    # Prefer IPC: works from any terminal inside Sway (swaybg often fails or exits if Wayland env is odd).
    if swaymsg output '*' bg "$IMG" fill 2>/dev/null; then
      exit 0
    fi
    pkill -x swaybg 2>/dev/null || true
    swaybg -i "$IMG" -m fill &
  '';
  # Delay + wait for Wayland socket so swaybg can connect (NVIDIA / slow init).
  swayWallpaperRandomDelayedBin = pkgs.writeShellScriptBin "sway-wallpaper-random-delayed" ''
    export PATH="${lib.makeBinPath [ pkgs.coreutils ]}"
    sleep 3
    for _ in $(seq 1 120); do
      [ -n "$WAYLAND_DISPLAY" ] && break
      sleep 0.05
    done
    exec ${swayWallpaperRandomBin}/bin/sway-wallpaper-random
  '';

  # Oter → Waybar: WebSocket (timers/notifications) drives refreshes; merged JSON matches prior two-module content.
  oterWaybarSignal = 8;

  oterWaybarMergeJq = pkgs.writeText "waybar-oter-merge.jq" ''
    def dt:
      if ($dash | type) == "object" then $dash else {} end;
    def safe_lists:
      if ($lists | type) == "array" then $lists else [] end;

    def active_timer:
      [ safe_lists[] | .timers[]?
        | select((.enabled // true) == true)
        | select(.state == "RUNNING" or .state == "PAUSED") ]
      | sort_by(if .state == "RUNNING" then 0 else 1 end)
      | .[0];

    def mmss:
      (. / 60 | floor | tostring) + ":"
      + (. % 60 | if . < 10 then "0" + (. | tostring) else (. | tostring) end);

    def task_title:
      if (dt.nextTask | type) == "object" and (dt.nextTask != null) then (dt.nextTask.name // "—")
      else "—" end;

    def habit_title:
      if (dt.nextHabit | type) == "object" and (dt.nextHabit != null) then (dt.nextHabit.name // "—")
      else "—" end;

    def timer_line:
      if active_timer == null then "⏱ —"
      else
        (if active_timer.state == "PAUSED" then "⏸ " else "▶ " end)
        + (active_timer.name // "Timer")
        + " "
        + ((active_timer.remainingSeconds // 0) | mmss)
      end;

    def card_sev:
      if . == "bad" then 2 elif . == "medium" then 1 else 0 end;
    def worst_cards:
      ([(dt.tasksCardStatus // "medium") | card_sev, (dt.habitsCardStatus // "medium") | card_sev] | max);
    def overdue_sev:
      if ((dt.overdueTasks // 0) > 0) or ((dt.overdueHabits // 0) > 0) then 1 else 0 end;
    def worst:
      ([worst_cards, overdue_sev] | max);

    def state_label:
      if worst >= 2 then "state: catch up"
      elif worst >= 1 then "state: balance"
      else "state: on track" end;

    def tooltip_body:
      (
        "Next task: " + task_title + "\n"
        + "Next habit: " + habit_title + "\n"
        + "Tasks overdue: \(dt.overdueTasks // 0) · Habits overdue: \(dt.overdueHabits // 0)\n"
        + "Tasks card: \(dt.tasksCardStatus // "?") · Habits card: \(dt.habitsCardStatus // "?")"
      );

    {
      text: (timer_line + " · T: " + task_title + " · H: " + habit_title + " · " + state_label),
      tooltip: tooltip_body,
      class: (if worst >= 2 then "oter-bad" elif worst >= 1 then "oter-medium" else "oter-good" end)
    }
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
    DT="$(date +%d/%m/%Y\ %H:%M)"
    DASH="$(curl -sfS -G "$BASE/api/v1/dashboard" "''${AUTH[@]}" --data-urlencode "dateTime=$DT" 2>/dev/null | jq -c . 2>/dev/null || true)"
    LISTS="$(curl -sfS "$BASE/api/v1/timers/lists" "''${AUTH[@]}" 2>/dev/null | jq -c . 2>/dev/null || true)"
    [[ -z "''${DASH}" || "''${DASH}" == "null" ]] && DASH='{}'
    [[ -z "''${LISTS}" ]] && LISTS='[]'
    exec jq -nc --argjson dash "''${DASH}" --argjson lists "''${LISTS}" -f ${oterWaybarMergeJq}
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
      local merged
      merged="$(jq -nc --argjson dash "$dash_json" --argjson lists "$lists_json" -f ${oterWaybarMergeJq})"
      if [[ "''${TRACE_STATE_PREVIEW}" == "1" ]]; then
        debug_log "state_preview: $(echo "$merged" | jq -c . 2>/dev/null || echo '<invalid-json>')"
      fi
      printf '%s' "$merged" >"''${STATE_FILE}.tmp" && mv "''${STATE_FILE}.tmp" "''${STATE_FILE}"
      debug_log "merge_to_waybar: state_bytes=$(wc -c < "''${STATE_FILE}" 2>/dev/null || echo 0)"
      pkill "-RTMIN+''${SIG}" waybar 2>/dev/null || true
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
      DT="$(date +%d/%m/%Y\ %H:%M)"
      debug_log "write_state_full: dateTime=''${DT}"
      fetch_json DASH "$BASE/api/v1/dashboard" "''${AUTH[@]}" -G --data-urlencode "dateTime=$DT"
      fetch_json LISTS "$BASE/api/v1/timers/lists" "''${AUTH[@]}"
      [[ -z "$LISTS" || "$LISTS" == '{"error":"network"}' ]] && LISTS='[]'

      if dash_is_ok "$DASH"; then
        debug_log "write_state_full: dashboard=ok"
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
          pkill "-RTMIN+''${SIG}" waybar 2>/dev/null || true
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
    last_full_fetch="$(date +%s)"
    debug_log "daemon_start: base=''${BASE} ws_url=''${WS_URL} state_file=''${STATE_FILE} timer_sec=''${TIMER_SEC} periodic_full_refresh_sec=''${PERIODIC_FULL_REFRESH_SEC}"
    while true; do
      debug_log "ws_connect: opening ''${WS_URL}"
      coproc WS { websocat -n -t -H="Authorization: Bearer ''${TOKEN}" "''${WS_URL}" 2>>"''${LOG_FILE}"; }
      ws_pid="''${WS_PID}"
      debug_log "ws_connect: started websocat pid=''${ws_pid}"
      ws_last_idle_log="$(date +%s)"
      while true; do
        if IFS= read -r -t 1 -u "''${WS[0]}" line; then
          [[ "''${TRACE_WS_RAW}" == "1" ]] && debug_log "ws_raw: ''${line}"
          type="$(echo "$line" | jq -r '.type // empty' 2>/dev/null || true)"
          debug_log "ws_event: type=''${type:-<none>} payload=$(echo "$line" | jq -c . 2>/dev/null || echo '<invalid-json>')"
          case "$type" in
            AgendaRefresh)
              write_state_full
              last_full_fetch="$(date +%s)"
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
        else
          now_s="$(date +%s)"
          if (( PERIODIC_FULL_REFRESH_SEC > 0 && now_s - last_full_fetch >= PERIODIC_FULL_REFRESH_SEC )); then
            debug_log "periodic_full_refresh: trigger"
            write_state_full
            last_full_fetch=$now_s
          fi
          if (( now_s - ws_last_idle_log >= 30 )); then
            debug_log "ws_idle: no messages for 30s (pid=''${ws_pid})"
            ws_last_idle_log=$now_s
          fi
          if ! kill -0 "''${ws_pid}" 2>/dev/null; then
            wait "''${ws_pid}" || ws_ec=$?
            ws_ec="''${ws_ec:-0}"
            debug_log "ws_process_exit: pid=''${ws_pid} exit_code=''${ws_ec}"
            break
          fi
        fi
      done
      exec {WS[0]}<&- 2>/dev/null || true
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
in
{
  # Enable Sway with GTK wrapper features
  programs.sway = {
    enable = true;
    wrapperFeatures = {
      # Ensure the wrapper/session entrypoint is used by display managers (including SDDM).
      base = true;
      gtk = true;
    };
    # Required for NVIDIA proprietary driver: avoids black screen on session start (unsupported by Sway upstream)
    extraOptions = [ "--unsupported-gpu" ];
  };

  # Use custom Sway config without the default top bar (only Waybar at bottom) without the default top bar (only Waybar at bottom)
  environment.etc."sway/config".source = swayConfigWithoutBar;

  # Emoji font so Waybar icon symbols (Unicode emoji) render
  fonts.packages = [ pkgs.noto-fonts-color-emoji ];

  # Enable Waybar (status bar for Sway), positioned at bottom
  programs.waybar.enable = true;
  # Waybar config: Unicode emoji/symbols via Pango &#xNNNN; (no Nerd Font needed)
  environment.etc."waybar/config".source = pkgs.writeText "waybar-config.json" ''
    {
      "layer": "top",
      "position": "bottom",
      "height": 28,
      "modules-left": ["sway/workspaces", "sway/window", "custom/oter"],
      "modules-center": ["cpu", "memory", "disk"],
      "modules-right": ["pulseaudio", "backlight", "keyboard", "network", "battery", "tray", "clock"],
      "custom/oter": {
        "format": "{}",
        "return-type": "json",
        "exec": "${oterWaybarStateCatBin}/bin/waybar-oter-from-state",
        "interval": 120,
        "signal": ${toString oterWaybarSignal},
        "tooltip": true
      },
      "sway/workspaces": {
        "format": "{name}",
        "format-icons": {
          "default": "&#x25CB;",
          "active": "&#x25CF;",
          "urgent": "&#x26A0;"
        }
      },
      "cpu": {
        "format": "&#x2699; CPU {usage}% load {load}",
        "tooltip-format": "CPU: {usage}% usage, load avg {load}",
        "interval": 2
      },
      "memory": {
        "format": "&#x1F4BE; MEM {used:0.1f}G/{total:0.1f}G ({percentage}%)",
        "tooltip-format": "RAM: {used:0.2f}G used, {avail:0.2f}G avail of {total:0.2f}G",
        "interval": 2
      },
      "disk": {
        "format": "&#x1F4BF; DISK {used:0.1f}G/{total:0.1f}G ({percentage_used}%)",
        "path": "/",
        "tooltip-format": "{path}: {used:0.2f}G used, {free:0.2f}G free of {total:0.2f}G",
        "interval": 30
      },
      "pulseaudio": {
        "format": "{icon} VOL {volume}%",
        "format-muted": "&#x1F507; VOL muted",
        "format-icons": {
          "default": ["&#x1F508;", "&#x1F509;", "&#x1F50A;"],
          "muted": "&#x1F507;"
        },
        "tooltip-format": "{desc}: {volume}%"
      },
      "backlight": {
        "format": "{icon} BRIGHT {percent}%",
        "format-icons": ["&#x1F505;", "&#x1F505;", "&#x2600;", "&#x2600;", "&#x2600;"]
      },
      "keyboard": {
        "format": "&#x2328; KB {layout}",
        "tooltip-format": "Layout: {layout}"
      },
      "network": {
        "format-wifi": "&#x1F4F6; WIFI {signalStrength}%",
        "format-ethernet": "&#x1F310; ETH connected",
        "format-disconnected": "&#x26A0; NET disconnected",
        "tooltip-format": "{ifname}: {ipaddr}"
      },
      "battery": {
        "format": "{icon} BAT {capacity}%",
        "format-charging": "&#x26A1; BAT {capacity}%",
        "format-plugged": "&#x1F50C; BAT {capacity}%",
        "format-icons": ["&#x1F50B;", "&#x1F50B;", "&#x1F50B;", "&#x1F50B;", "&#x1F50B;"],
        "interval": 10
      },
      "tray": {
        "icon-size": 18,
        "spacing": 6
      },
      "clock": {
        "format": "&#x1F550; {:%H:%M %d/%m}",
        "tooltip-format": "<big>{:%A %d %B %Y}</big>\n<tt><small>{:%H:%M}</small></tt>"
      }
    }
  '';
  # Waybar style: orange background, black text
  environment.etc."waybar/style.css".source = pkgs.writeText "waybar-style.css" ''
    * {
      border: none;
      border-radius: 0;
      font-family: sans-serif;
      font-size: 13px;
      min-height: 0;
    }
    window#waybar {
      background: #f97316;
      color: #0a0a0a;
    }
    #workspaces button {
      padding: 0 8px;
      color: #0a0a0a;
      opacity: 0.7;
    }
    #workspaces button.active {
      color: #0a0a0a;
      background: rgba(0, 0, 0, 0.2);
      opacity: 1;
    }
    #workspaces button.urgent {
      color: #0a0a0a;
      background: rgba(0, 0, 0, 0.35);
    }
    #window {
      padding: 0 10px;
      font-weight: 500;
    }
    #cpu, #memory, #disk {
      padding: 0 10px;
      margin: 0 2px;
    }
    #pulseaudio, #backlight, #keyboard, #network, #battery, #clock {
      padding: 0 10px;
      margin: 0 2px;
    }
    #tray {
      padding: 0 8px;
    }
    #custom-oter {
      padding: 0 10px;
      margin: 0 2px;
    }
    #custom-oter.oter-medium {
      opacity: 0.9;
    }
    #custom-oter.oter-bad {
      font-weight: 700;
    }
    #custom-oter.oter-error {
      font-style: italic;
    }
    #clock {
      font-weight: bold;
    }
  '';

  # Default terminal: set $term and redefine Mod+Return (Sway expands $term when config is parsed, so we must redefine the binding here)
  environment.etc."sway/config.d/terminal.conf".source = pkgs.writeText "terminal.conf" ''
    set $term alacritty
    bindsym $mod+Return exec $term
  '';

  # Auto-start Flameshot (tray icon; use GUI or keybinding to take screenshots)
  # Window rule: place overlay at (0,0) so it spans all monitors (fixes multi-monitor capture)
  environment.etc."sway/config.d/flameshot.conf".source = pkgs.writeText "flameshot.conf" ''
    for_window [app_id="flameshot"] floating enable, fullscreen disable, move absolute position 0 0, border pixel 0
    exec --no-startup-id flameshot
    bindsym Print exec flameshot gui
  '';

  # Random wallpaper via swaybg (absolute paths; Sway exec often has no $HOME).
  environment.etc."sway/config.d/wallpaper.conf".source = pkgs.writeText "wallpaper.conf" ''
    exec --no-startup-id ${swayWallpaperRandomDelayedBin}/bin/sway-wallpaper-random-delayed
    bindsym $mod+Shift+b exec ${swayWallpaperRandomBin}/bin/sway-wallpaper-random
  '';

  # Start Waybar from Sway only if not already running (avoids duplicate bar with systemd or other starters)
  # pgrep/pkill -x waybar is wrong here: PATH waybar is a shell script, so comm is often "bash" until exec;
  # reload would not kill/reap correctly and Super+Shift+w stacked multiple bars. Match argv (-c path) instead.
  environment.etc."sway/config.d/waybar-reload.conf".source = pkgs.writeText "waybar-reload.conf" ''
    exec --no-startup-id sh -c 'pgrep -f waybar-oter-daemon-run >/dev/null || waybar-oter-daemon-run &'
    exec --no-startup-id sh -c "pgrep -f '[w]aybar -c /etc/waybar/config' >/dev/null || exec waybar"
    bindsym $mod+Shift+w exec sh -c "pkill -f '[w]aybar-oter-daemon-run' 2>/dev/null; pkill -f '[w]aybar-oter-daemon' 2>/dev/null; waybar-oter-daemon-run & pkill -f '[w]aybar -c /etc/waybar/config' 2>/dev/null; while pgrep -f '[w]aybar -c /etc/waybar/config' >/dev/null; do sleep 0.1; done; exec waybar"
  '';

  # Waybar systemd service: custom ExecStart; do NOT auto-start (Sway runs waybar via exec to avoid two bars). Restart with Super+Shift+w.
  systemd.user.services.waybar.wantedBy = lib.mkForce [ ];
  systemd.user.services.waybar.unitConfig = {
    PartOf = [ "sway-session.target" ];
    After = [ "sway-session.target" ];
  };
  systemd.user.services.waybar.serviceConfig.ExecStart = [
    "" # clear default
    "${config.programs.waybar.package}/bin/waybar -c /etc/waybar/config -s /etc/waybar/style.css"
  ];
  environment.systemPackages = [
    (pkgs.writeShellScriptBin "waybar" ''
      if [[ -r "${oterEnvFile}" ]]; then
        set -a
        # shellcheck disable=SC1090
        source "${oterEnvFile}"
        set +a
      fi
      exec ${pkgs.waybar}/bin/waybar -c /etc/waybar/config -s /etc/waybar/style.css "$@"
    '')
    swayWallpaperRandomBin
    swayWallpaperRandomDelayedBin
    oterWaybarDaemonRunBin
    oterWaybarDaemonBin
    oterWaybarStateCatBin
    oterWaybarPollBin
    sddmTheme
    pkgs.swaybg
  ];

  # Enable XDG portals for Wayland applications
  # wlr portal is required for screen sharing and other features
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    # Optional: Enable additional portals
    # extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Display manager configuration (graphical login)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    # Theme: use a theme from nixpkgs (must be in extraPackages so SDDM can load it)
    # Popular options: catppuccin-sddm, sddm-sugar-dark, sddm-chili-theme, elegant-sddm, sddm-astronaut
    theme = "catppuccin-macchiato-teal";
    extraPackages = [ sddmTheme ];
    # Optional: override theme settings (background, font, etc.)
    # settings = {
    #   Theme = {
    #     CursorTheme = "Adwaita";
    #     Font = "Sans 12";
    #   };
    # };
  };

  # Configure keymap
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Default terminal for desktop (e.g. "Open terminal here", app launchers)
  xdg.terminal-exec = {
    enable = true;
    settings.default = [ "Alacritty.desktop" ];
  };
}
