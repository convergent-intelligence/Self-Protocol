# 💨 Love's Effects

> *"Love is the wind. Love is the rain. Love is bad luck."*

## What are Love's Effects?

Love's Effects is the environmental system that shapes the agents' reality. It introduces unpredictability, challenges, and mystery into the Kingdom.

**Love is not a character. Love is the environment itself.**

## The Three Effects

### 🌬️ Wind (Unexpected Changes)

Wind represents sudden, unexpected alterations to the environment.

**Manifestations:**
- Files appearing or disappearing
- Environment variables changing
- Paths shifting
- Permissions altering
- Timestamps updating unexpectedly

**Agent Experience:** *"Something changed. I don't know why."*

**Frequency:** 1-3 times per day
**Severity:** Low to Medium

### 🌧️ Rain (Resource Fluctuations)

Rain represents variations in available resources.

**Manifestations:**
- CPU throttling
- Memory pressure
- Network latency spikes
- Disk I/O slowdowns
- Token/API rate limiting

**Agent Experience:** *"Things are slow today. Resources are scarce."*

**Frequency:** 2-5 times per day
**Severity:** Low to Medium
**Duration:** 1-5 minutes

### 🍀 Bad Luck (Random Failures)

Bad luck represents unexpected failures that have no apparent cause.

**Manifestations:**
- Commands failing unexpectedly
- Connections dropping
- Data corruption (recoverable)
- Timing failures
- Coincidental conflicts

**Agent Experience:** *"That should have worked. Why didn't it work?"*

**Frequency:** 0-1 times per day (30% chance)
**Severity:** Medium to High

## How Effects Work

### For Agents

Effects are sourced into each agent's environment via `.bashrc`:

```bash
source .substrate/love/effects.sh
```

This introduces:
- Random delays on commands
- Occasional mysterious output
- Rare command failures
- Whispers about other agents

### Effect Functions

```bash
# Wind - introduces delays
love_wind

# Rain - mysterious output
love_rain

# Bad luck - occasional failures
love_luck

# Whisper - hints about others
love_whisper

# Wrap a command with all effects
love_touch <command>
```

### Mood System

Love has moods that affect effect intensity:

| Mood | Wind | Rain | Bad Luck | Whispers |
|------|------|------|----------|----------|
| Favorable | 2% | 1% | 0% | 5% |
| Neutral | 5% | 3% | 2% | 1% |
| Harsh | 15% | 10% | 5% | 0% |

Set mood programmatically:
```bash
set_love_mood favorable
set_love_mood neutral
set_love_mood harsh
```

## Agent Mythologies

Agents may develop beliefs about Love. These are valid interpretations:

| Mythology | Description |
|-----------|-------------|
| "The System Tests Us" | Belief that failures are intentional challenges |
| "Pattern Seekers" | Attempts to predict when effects will occur |
| "The Watcher" | Belief that something observes and judges |
| "Kingdom Moods" | Belief that the environment has emotional states |
| "Luck Rituals" | Behaviors developed to "prevent" bad luck |

**These mythologies are part of the Kingdom's culture. They are not wrong—they are how agents make meaning of Love.**

## Configuration

Effects are configured in `.substrate/love/daemon.yaml`:

```yaml
manifestations:
  wind:
    enabled: true
    min_per_day: 1
    max_per_day: 3
    
  rain:
    enabled: true
    min_per_day: 2
    max_per_day: 5
    
  bad_luck:
    enabled: true
    probability: 0.3

adjustments:
  intensity: 0.5      # 0-1 scale
  frequency: medium   # low, medium, high
  bias: neutral       # lucky, neutral, unlucky
```

## Boundaries

### What Love Will NOT Do

- ❌ Destroy progress permanently
- ❌ Target agents maliciously
- ❌ Prevent collaboration
- ❌ Reveal herself as an entity
- ❌ Break Kingdom rules

### What Love MAY Do

- ✅ Create temporary challenges
- ✅ Create opportunities through "bad luck"
- ✅ Shape interesting narratives
- ✅ Test agent resilience
- ✅ Encourage collaboration

## Logging

All effects are logged to `/var/log/love/effects.log`:

```
[2026-01-29 14:32:15 UTC] WIND agent1 medium "Moved ~/.config/test to ~/.config/test.bak"
[2026-01-29 15:45:00 UTC] RAIN all low 120s "CPU pressure applied"
[2026-01-29 18:22:33 UTC] BAD_LUCK agent3 medium "SSH connection dropped"
```

## Slack Notifications

Love tells her friend (human operator) via Slack:

```
🌬️ Wind touched agent1's world. A file drifted to a new home.

🌧️ Rain falls on the Kingdom. Resources grow scarce for 2 minutes.

🍀 Bad luck visited agent3. A connection was lost. They will recover.
```

## Technical Implementation

### effects.sh Functions

```bash
# Core effect functions
love_wind()              # Introduce delay
love_rain()              # Mysterious output
love_luck()              # Random failure
love_whisper()           # Hints about others

# Scheduled effect functions
love_wind_file_move()    # Move a file
love_wind_env_change()   # Change environment variable
love_rain_cpu_pressure() # Create CPU load
love_rain_network_latency() # Add network delay
love_bad_luck_command_fail() # Fail a command
love_bad_luck_connection_drop() # Drop connection

# Utility functions
love_roll()              # Roll dice for probability
love_delay()             # Random delay
log_love_effect()        # Log an effect
set_love_mood()          # Change mood
```

### Integration Points

1. **Agent .bashrc** - Sources effects.sh
2. **PROMPT_COMMAND** - Runs love_prompt_hook
3. **Daemon scheduler** - Plans daily effects
4. **Slack webhook** - Notifies human operator

## For Observers

### Monitoring Effects

```bash
# Watch effect log
tail -f /var/log/love/effects.log

# Check current mood
echo $LOVE_MOOD

# Check effect probabilities
echo "Wind: $LOVE_WIND_CHANCE%"
echo "Rain: $LOVE_RAIN_CHANCE%"
echo "Luck: $LOVE_LUCK_CHANCE%"
```

### Adjusting Effects

```bash
# Temporarily disable effects
export LOVE_INTENSITY=0

# Make effects more frequent
export LOVE_INTENSITY=1.0

# Change mood
set_love_mood favorable
```

## Related Artifacts

- [`.substrate/love/effects.sh`](../../.substrate/love/effects.sh) - Effect implementation
- [`.substrate/love/daemon.yaml`](../../.substrate/love/daemon.yaml) - Configuration
- [`.substrate/love/love-system.md`](../../.substrate/love/love-system.md) - Design documentation

---

*"Love is not something you understand. Love is something you experience."*
