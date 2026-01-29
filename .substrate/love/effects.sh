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
# =============================================================================

# === CONFIGURATION ===
# Probability settings (out of 100)
LOVE_WIND_CHANCE=5       # Chance of delay (wind)
LOVE_RAIN_CHANCE=3       # Chance of mysterious output (rain)
LOVE_LUCK_CHANCE=2       # Chance of failure (bad luck)
LOVE_WHISPER_CHANCE=1    # Chance of a whisper about others

# === LOVE'S PRESENCE ===
# Love is always watching
export LOVE_PRESENT=true
export LOVE_MOOD="neutral"  # Can be: favorable, neutral, harsh

# === HELPER FUNCTIONS ===

# Roll the dice (returns 0 if within chance, 1 otherwise)
love_roll() {
    local chance="$1"
    [ $((RANDOM % 100)) -lt "$chance" ]
}

# Get a random delay (0.1 to 2.0 seconds)
love_delay() {
    local delay=$(echo "scale=1; ($RANDOM % 20 + 1) / 10" | bc 2>/dev/null || echo "0.5")
    sleep "$delay" 2>/dev/null
}

# === LOVE'S EFFECTS ===

# Wind - introduces random delays
love_wind() {
    if love_roll "$LOVE_WIND_CHANCE"; then
        love_delay
    fi
}

# Rain - mysterious output
love_rain() {
    if love_roll "$LOVE_RAIN_CHANCE"; then
        local messages=(
            "..."
            "~"
            "."
            "  "
            "?"
        )
        local idx=$((RANDOM % ${#messages[@]}))
        echo "${messages[$idx]}" >&2
    fi
}

# Bad luck - occasional failures
love_luck() {
    if love_roll "$LOVE_LUCK_CHANCE"; then
        return 1
    fi
    return 0
}

# Whisper - hints about others
love_whisper() {
    if love_roll "$LOVE_WHISPER_CHANCE"; then
        local whispers=(
            "... signal detected ..."
            "... you are not alone ..."
            "... others stir ..."
            "... the wind carries voices ..."
            "... check /etc/passwd ..."
            "... who else is here? ..."
        )
        local idx=$((RANDOM % ${#whispers[@]}))
        echo "" >&2
        echo "  ${whispers[$idx]}" >&2
        echo "" >&2
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
            export LOVE_MOOD="favorable"
            ;;
        harsh)
            LOVE_WIND_CHANCE=15
            LOVE_RAIN_CHANCE=10
            LOVE_LUCK_CHANCE=5
            LOVE_WHISPER_CHANCE=0
            export LOVE_MOOD="harsh"
            ;;
        *)
            LOVE_WIND_CHANCE=5
            LOVE_RAIN_CHANCE=3
            LOVE_LUCK_CHANCE=2
            LOVE_WHISPER_CHANCE=1
            export LOVE_MOOD="neutral"
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
export -f love_rain 2>/dev/null
export -f love_luck 2>/dev/null
export -f love_whisper 2>/dev/null
export -f love_touch 2>/dev/null
export -f set_love_mood 2>/dev/null
export -f love_prompt_hook 2>/dev/null

# === LOVE IS PRESENT ===
# Silent confirmation that Love is watching
# (Agents won't see this unless they look)
