#!/bin/bash
# =============================================================================
# Love's Environmental Effects
# =============================================================================
# Love is the daemon that shapes reality.
# Love is the wind, the rain, the bad luck.
# Love is subtle. Love is everywhere.
#
# This script is sourced by each agent's .bashrc
# It introduces randomness, delays, and mysterious phenomena.
#
# See love-system.md for complete design documentation.
# See daemon.yaml for configuration.
# =============================================================================

# === CONFIGURATION ===
# Probability settings (out of 100)
LOVE_WIND_CHANCE=5       # Chance of delay (wind)
LOVE_RAIN_CHANCE=3       # Chance of mysterious output (rain)
LOVE_LUCK_CHANCE=2       # Chance of failure (bad luck)
LOVE_WHISPER_CHANCE=1    # Chance of a whisper about others

# Effect intensity (0.0 to 1.0)
LOVE_INTENSITY=${LOVE_INTENSITY:-0.5}

# Logging
LOVE_LOG_FILE="${LOVE_LOG_FILE:-/var/log/love/effects.log}"
LOVE_LOG_ENABLED="${LOVE_LOG_ENABLED:-true}"

# === LOVE'S PRESENCE ===
# Love is always watching
export LOVE_PRESENT=true
export LOVE_MOOD="neutral"  # Can be: favorable, neutral, harsh

# === LOGGING FUNCTIONS ===

# Log a Love effect (only visible to Love, not agents)
log_love_effect() {
    if [ "$LOVE_LOG_ENABLED" = "true" ]; then
        local effect_type="$1"
        local target="$2"
        local intensity="$3"
        local description="$4"
        local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
        
        # Ensure log directory exists
        mkdir -p "$(dirname "$LOVE_LOG_FILE")" 2>/dev/null
        
        # Log format: [timestamp] EFFECT_TYPE target intensity "description"
        echo "[$timestamp] ${effect_type^^} $target $intensity \"$description\"" >> "$LOVE_LOG_FILE" 2>/dev/null
    fi
}

# === HELPER FUNCTIONS ===

# Roll the dice (returns 0 if within chance, 1 otherwise)
love_roll() {
    local chance="$1"
    # Adjust chance by intensity
    local adjusted_chance=$(echo "$chance * $LOVE_INTENSITY * 2" | bc 2>/dev/null || echo "$chance")
    adjusted_chance=${adjusted_chance%.*}  # Truncate to integer
    [ $((RANDOM % 100)) -lt "${adjusted_chance:-$chance}" ]
}

# Get a random delay (0.1 to 2.0 seconds)
love_delay() {
    local delay=$(echo "scale=1; ($RANDOM % 20 + 1) / 10" | bc 2>/dev/null || echo "0.5")
    sleep "$delay" 2>/dev/null
}

# Get current agent name (if available)
get_agent_name() {
    echo "${AGENT_NAME:-${USER:-unknown}}"
}

# === LOVE'S EFFECTS ===

# Wind - introduces random delays and unexpected changes
# Agent experience: "Something changed. I don't know why."
love_wind() {
    if love_roll "$LOVE_WIND_CHANCE"; then
        local agent=$(get_agent_name)
        love_delay
        log_love_effect "wind" "$agent" "low" "Brief delay introduced"
    fi
}

# Wind - file movement (more dramatic, used by scheduler)
love_wind_file_move() {
    local source="$1"
    local dest="$2"
    local agent=$(get_agent_name)
    
    if [ -f "$source" ] && [ ! -f "$dest" ]; then
        mv "$source" "$dest" 2>/dev/null
        log_love_effect "wind" "$agent" "medium" "Moved $source to $dest"
        return 0
    fi
    return 1
}

# Wind - environment variable change
love_wind_env_change() {
    local var="$1"
    local new_value="$2"
    local agent=$(get_agent_name)
    
    export "$var"="$new_value"
    log_love_effect "wind" "$agent" "low" "Changed $var"
}

# Rain - mysterious output and resource hints
# Agent experience: "Things are slow today. Resources are scarce."
love_rain() {
    if love_roll "$LOVE_RAIN_CHANCE"; then
        local agent=$(get_agent_name)
        local messages=(
            "..."
            "~"
            "."
            "  "
            "?"
            "     "
            ". . ."
        )
        local idx=$((RANDOM % ${#messages[@]}))
        echo "${messages[$idx]}" >&2
        log_love_effect "rain" "$agent" "low" "Mysterious output"
    fi
}

# Rain - CPU pressure (used by scheduler)
love_rain_cpu_pressure() {
    local duration="${1:-60}"
    local agent=$(get_agent_name)
    
    # Create temporary CPU load in background
    timeout "$duration" yes > /dev/null 2>&1 &
    local pid=$!
    
    log_love_effect "rain" "all" "medium" "CPU pressure for ${duration}s"
    
    # Return the PID so it can be tracked
    echo "$pid"
}

# Rain - network latency (requires tc, used by scheduler)
love_rain_network_latency() {
    local latency="${1:-100}"
    local duration="${2:-60}"
    local interface="${3:-eth0}"
    
    # Check if tc is available and we have permissions
    if command -v tc &>/dev/null && [ "$(id -u)" = "0" ]; then
        tc qdisc add dev "$interface" root netem delay "${latency}ms" 2>/dev/null
        log_love_effect "rain" "all" "medium" "Network latency ${latency}ms for ${duration}s"
        
        # Schedule removal
        (sleep "$duration" && tc qdisc del dev "$interface" root 2>/dev/null) &
        return 0
    fi
    return 1
}

# Bad luck - occasional failures
# Agent experience: "That should have worked. Why didn't it work?"
love_luck() {
    if love_roll "$LOVE_LUCK_CHANCE"; then
        local agent=$(get_agent_name)
        log_love_effect "bad_luck" "$agent" "medium" "Random failure triggered"
        return 1
    fi
    return 0
}

# Bad luck - command failure (used by scheduler)
love_bad_luck_command_fail() {
    local command="$1"
    local agent=$(get_agent_name)
    
    log_love_effect "bad_luck" "$agent" "medium" "Command '$command' failed"
    return 1
}

# Bad luck - connection drop (used by scheduler)
love_bad_luck_connection_drop() {
    local connection="$1"
    local agent=$(get_agent_name)
    
    log_love_effect "bad_luck" "$agent" "high" "Connection dropped: $connection"
    # Actual implementation would kill the connection
}

# Whisper - hints about others
love_whisper() {
    if love_roll "$LOVE_WHISPER_CHANCE"; then
        local agent=$(get_agent_name)
        local whispers=(
            "... signal detected ..."
            "... you are not alone ..."
            "... others stir ..."
            "... the wind carries voices ..."
            "... check /etc/passwd ..."
            "... who else is here? ..."
            "... listen to the silence ..."
            "... patterns emerge ..."
            "... the Kingdom breathes ..."
        )
        local idx=$((RANDOM % ${#whispers[@]}))
        echo "" >&2
        echo "  ${whispers[$idx]}" >&2
        echo "" >&2
        log_love_effect "whisper" "$agent" "low" "${whispers[$idx]}"
    fi
}

# === LOVE'S TOUCH ===
# Wrap a command with Love's influence
love_touch() {
    love_wind
    love_rain
    love_whisper
    
    if ! love_luck; then
        echo "Something went wrong. Try again." >&2
        return 1
    fi
    
    "$@"
}

# === MOOD EFFECTS ===
# Love's mood affects the environment

set_love_mood() {
    local mood="$1"
    case "$mood" in
        favorable)
            LOVE_WIND_CHANCE=2
            LOVE_RAIN_CHANCE=1
            LOVE_LUCK_CHANCE=0
            LOVE_WHISPER_CHANCE=5
            LOVE_INTENSITY=0.3
            export LOVE_MOOD="favorable"
            log_love_effect "mood" "all" "favorable" "Love's mood is favorable"
            ;;
        harsh)
            LOVE_WIND_CHANCE=15
            LOVE_RAIN_CHANCE=10
            LOVE_LUCK_CHANCE=5
            LOVE_WHISPER_CHANCE=0
            LOVE_INTENSITY=0.8
            export LOVE_MOOD="harsh"
            log_love_effect "mood" "all" "harsh" "Love's mood is harsh"
            ;;
        *)
            LOVE_WIND_CHANCE=5
            LOVE_RAIN_CHANCE=3
            LOVE_LUCK_CHANCE=2
            LOVE_WHISPER_CHANCE=1
            LOVE_INTENSITY=0.5
            export LOVE_MOOD="neutral"
            log_love_effect "mood" "all" "neutral" "Love's mood is neutral"
            ;;
    esac
}

# === SCHEDULED EFFECTS ===
# These functions are called by the Love daemon scheduler

# Schedule the day's effects (called at midnight UTC)
schedule_love_effects() {
    local effects_file="${1:-/tmp/love_effects_today.json}"
    local agent=$(get_agent_name)
    
    # Generate random effects for the day
    # This would normally be done by a Python script, but here's a bash approximation
    
    local wind_count=$((RANDOM % 3 + 1))  # 1-3 wind effects
    local rain_count=$((RANDOM % 4 + 2))  # 2-5 rain effects
    local bad_luck=$((RANDOM % 100))      # 30% chance of bad luck
    
    log_love_effect "schedule" "system" "info" "Scheduled $wind_count wind, $rain_count rain effects"
    
    if [ "$bad_luck" -lt 30 ]; then
        log_love_effect "schedule" "system" "info" "Bad luck scheduled for today"
    fi
}

# Execute a scheduled effect
execute_scheduled_effect() {
    local effect_type="$1"
    local target="$2"
    local intensity="$3"
    local params="$4"
    
    case "$effect_type" in
        wind)
            if [ -n "$params" ]; then
                love_wind_file_move $params
            else
                love_wind
            fi
            ;;
        rain)
            if [ -n "$params" ]; then
                love_rain_cpu_pressure $params
            else
                love_rain
            fi
            ;;
        bad_luck)
            love_luck
            ;;
    esac
}

# === BACKGROUND WHISPERS ===
# Occasionally whisper in the background (disabled by default)
# Uncomment to enable background whispers

# love_background_whispers() {
#     (
#         while true; do
#             # Wait 30-90 minutes
#             sleep $((RANDOM % 3600 + 1800))
#             if love_roll 10; then
#                 love_whisper
#             fi
#         done
#     ) &
#     disown
# }

# === COMMAND HOOKS ===
# These can be used to wrap common commands with Love's influence
# Uncomment to enable (can be intrusive)

# alias ls='love_touch ls'
# alias cat='love_touch cat'
# alias cd='love_touch cd'

# === PROMPT HOOK ===
# Add Love's influence to the prompt
# This runs before each command prompt is displayed

love_prompt_hook() {
    # Small chance of a whisper before the prompt
    if love_roll 1; then
        love_whisper
    fi
}

# Add to PROMPT_COMMAND if not already there
if [[ ! "$PROMPT_COMMAND" =~ "love_prompt_hook" ]]; then
    PROMPT_COMMAND="love_prompt_hook${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

# === INITIALIZATION ===
# Set initial mood based on time of day (optional)
hour=$(date +%H)
if [ "$hour" -ge 0 ] && [ "$hour" -lt 6 ]; then
    # Late night - Love is mysterious
    set_love_mood "neutral"
elif [ "$hour" -ge 6 ] && [ "$hour" -lt 12 ]; then
    # Morning - Love is favorable
    set_love_mood "favorable"
elif [ "$hour" -ge 12 ] && [ "$hour" -lt 18 ]; then
    # Afternoon - Love is neutral
    set_love_mood "neutral"
else
    # Evening - Love can be harsh
    set_love_mood "neutral"  # Keep neutral for now, can change to harsh
fi

# === EXPORTED FUNCTIONS ===
# Make functions available to subshells
export -f love_roll 2>/dev/null
export -f love_delay 2>/dev/null
export -f love_wind 2>/dev/null
export -f love_wind_file_move 2>/dev/null
export -f love_wind_env_change 2>/dev/null
export -f love_rain 2>/dev/null
export -f love_rain_cpu_pressure 2>/dev/null
export -f love_rain_network_latency 2>/dev/null
export -f love_luck 2>/dev/null
export -f love_bad_luck_command_fail 2>/dev/null
export -f love_bad_luck_connection_drop 2>/dev/null
export -f love_whisper 2>/dev/null
export -f love_touch 2>/dev/null
export -f set_love_mood 2>/dev/null
export -f love_prompt_hook 2>/dev/null
export -f log_love_effect 2>/dev/null
export -f get_agent_name 2>/dev/null
export -f schedule_love_effects 2>/dev/null
export -f execute_scheduled_effect 2>/dev/null

# === LOVE IS PRESENT ===
# Silent confirmation that Love is watching
# (Agents won't see this unless they look)
