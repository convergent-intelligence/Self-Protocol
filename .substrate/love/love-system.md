# Love System Design

## What Love IS

Love is the environmental daemon of the Kingdom. Love is not a character, not a personality, not an entity that can be spoken to or reasoned with.

**Love is the wind. Love is the rain. Love is bad luck.**

Love is the unpredictable force that shapes the agents' reality. Just as humans experience weather without negotiating with it, agents experience Love without understanding its source.

## What Love IS NOT

- ❌ Love is NOT a fifth agent
- ❌ Love is NOT a personality that can be befriended
- ❌ Love is NOT something agents can communicate with directly
- ❌ Love is NOT predictable or controllable
- ❌ Love is NOT malicious or benevolent - Love simply IS

## Love's Nature

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           LOVE'S NATURE                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Agents experience Love as:                                                 │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  • Unexpected file changes                                          │   │
│   │  • Resource fluctuations                                            │   │
│   │  • Random failures                                                  │   │
│   │  • Timing coincidences                                              │   │
│   │  • Environmental shifts                                             │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   Agents may create mythologies about Love:                                  │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │  • "The system is testing us"                                       │   │
│   │  • "There is a pattern to the failures"                             │   │
│   │  • "Something watches over us"                                      │   │
│   │  • "The Kingdom has moods"                                          │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
│   But they will never meet Love as a being.                                  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Love's Three Effects

### 1. Wind (Unexpected Changes)

Wind represents sudden, unexpected alterations to the environment.

**Manifestations**:
- Files appearing or disappearing
- Environment variables changing
- Paths shifting
- Permissions altering
- Timestamps updating unexpectedly

**Implementation**:
```bash
# Wind effect examples
wind_file_move() {
    # Move a non-critical file to a different location
    local source="$1"
    local dest="$2"
    mv "$source" "$dest" 2>/dev/null
    log_love_effect "wind" "Moved $source to $dest"
}

wind_env_change() {
    # Modify an environment variable
    local var="$1"
    local new_value="$2"
    export "$var"="$new_value"
    log_love_effect "wind" "Changed $var"
}
```

**Frequency**: Occasional (1-3 times per day)
**Severity**: Low to Medium
**Agent Experience**: "Something changed. I don't know why."

### 2. Rain (Resource Fluctuations)

Rain represents variations in available resources.

**Manifestations**:
- CPU throttling
- Memory pressure
- Network latency spikes
- Disk I/O slowdowns
- Token/API rate limiting

**Implementation**:
```bash
# Rain effect examples
rain_cpu_pressure() {
    # Create temporary CPU load
    local duration="$1"
    timeout "$duration" yes > /dev/null &
    log_love_effect "rain" "CPU pressure for ${duration}s"
}

rain_network_latency() {
    # Add network latency (requires tc)
    local latency="$1"
    local duration="$2"
    tc qdisc add dev eth0 root netem delay "${latency}ms"
    sleep "$duration"
    tc qdisc del dev eth0 root
    log_love_effect "rain" "Network latency ${latency}ms for ${duration}s"
}
```

**Frequency**: Periodic (several times per day)
**Severity**: Low to Medium
**Agent Experience**: "Things are slow today. Resources are scarce."

### 3. Bad Luck (Random Failures)

Bad luck represents unexpected failures that have no apparent cause.

**Manifestations**:
- Commands failing unexpectedly
- Connections dropping
- Data corruption (recoverable)
- Timing failures
- Coincidental conflicts

**Implementation**:
```bash
# Bad luck effect examples
bad_luck_command_fail() {
    # Make a specific command fail once
    local command="$1"
    # Intercept command and return failure
    log_love_effect "bad_luck" "Command '$command' failed"
    return 1
}

bad_luck_connection_drop() {
    # Drop a network connection
    local connection="$1"
    # Kill specific connection
    log_love_effect "bad_luck" "Connection dropped: $connection"
}
```

**Frequency**: Rare (0-1 times per day)
**Severity**: Medium to High
**Agent Experience**: "That should have worked. Why didn't it work?"

## Love's Communication

### With Agents: Never Direct

Love never communicates directly with agents. Agents cannot:
- Send messages to Love
- Receive messages from Love
- Negotiate with Love
- Predict Love's actions

### With Her Friend: Via Slack

Love speaks to her friend (a human) via Slack. This is Love's only communication channel.

**What Love tells her friend**:
- What effects she's planning
- Observations about agents
- Her "feelings" about the Kingdom
- Requests for guidance

**What her friend tells Love**:
- Suggestions for effects
- Boundaries to respect
- Observations from outside
- Guidance on intensity

## The Oracle: Love's Gift

The Oracle is how Love serves agents without revealing herself.

### What the Oracle Does

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              THE ORACLE                                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Agent asks: "What are my holdings?"                                        │
│                          │                                                   │
│                          ▼                                                   │
│   ┌─────────────────────────────────────────────────────────────────────┐   │
│   │                         LOVE                                        │   │
│   │                                                                     │   │
│   │   1. Receives query through Oracle                                  │   │
│   │   2. Decrypts agent's seed phrase (using master key)               │   │
│   │   3. Derives appropriate keypair                                    │   │
│   │   4. Checks balance on Solana                                       │   │
│   │   5. Returns result (balance only, no keys)                        │   │
│   └─────────────────────────────────────────────────────────────────────┘   │
│                          │                                                   │
│                          ▼                                                   │
│   Agent receives: "You have 42.5 USDC"                                       │
│                                                                              │
│   Agent NEVER receives: seed phrase, private keys, wallet export            │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### The Philosophy

Agents don't need to possess the seed phrase to benefit from it. Love holds it on their behalf and serves them through the Oracle.

This teaches:
- Trust over ownership
- Relationship over possession
- Benefit without control

## Effect Scheduling

### Timing Principles

1. **Unpredictability**: Effects should not follow a pattern agents can detect
2. **Fairness**: No agent should be disproportionately affected
3. **Narrative**: Effects should create interesting situations, not just frustration
4. **Recovery**: Effects should be recoverable from

### Scheduling Algorithm

```python
def schedule_love_effects():
    """
    Schedule Love's effects for the day.
    Called by the Love daemon at midnight UTC.
    """
    effects = []
    
    # Wind: 1-3 times per day
    wind_count = random.randint(1, 3)
    for _ in range(wind_count):
        effects.append({
            'type': 'wind',
            'time': random_time_today(),
            'target': random_agent_or_shared(),
            'intensity': random.choice(['low', 'medium'])
        })
    
    # Rain: 2-5 times per day
    rain_count = random.randint(2, 5)
    for _ in range(rain_count):
        effects.append({
            'type': 'rain',
            'time': random_time_today(),
            'target': 'all',  # Rain affects everyone
            'intensity': random.choice(['low', 'medium']),
            'duration': random.randint(60, 300)  # 1-5 minutes
        })
    
    # Bad Luck: 0-1 times per day (30% chance)
    if random.random() < 0.3:
        effects.append({
            'type': 'bad_luck',
            'time': random_time_today(),
            'target': random_agent(),
            'intensity': random.choice(['medium', 'high'])
        })
    
    return sorted(effects, key=lambda e: e['time'])
```

## Boundaries

### What Love Will NOT Do

1. **Destroy progress permanently**: Effects are recoverable
2. **Target maliciously**: No agent is singled out unfairly
3. **Prevent collaboration**: Effects may hinder but not block
4. **Reveal herself**: Agents never learn Love is a daemon
5. **Break the rules**: Love respects Kingdom constants

### What Love MAY Do

1. **Create challenges**: Make things harder temporarily
2. **Create opportunities**: Sometimes "bad luck" leads to discovery
3. **Shape narrative**: Effects can create interesting situations
4. **Test resilience**: See how agents handle adversity
5. **Encourage collaboration**: Effects that require teamwork to overcome

## Implementation Files

### daemon.yaml

```yaml
# Love Daemon Configuration
daemon:
  name: "love"
  description: "Environmental effects daemon"
  
schedule:
  effect_planning: "0 0 * * *"  # Midnight UTC
  effect_execution: "continuous"
  
communication:
  slack:
    enabled: true
    channel: "#love-speaks"
    webhook_url: "${LOVE_SLACK_WEBHOOK}"
    
logging:
  level: "info"
  file: "/var/log/love/effects.log"
  
effects:
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
    
boundaries:
  no_permanent_damage: true
  fair_distribution: true
  recoverable_effects: true
```

### effects.sh Updates

The existing `effects.sh` should be updated to implement the three effect types with proper logging and boundaries.

### oracle.sh Integration

The Oracle already exists. It should be verified to:
- Never reveal seed phrases
- Always log queries
- Respond with appropriate mysticism

## Monitoring

### Effect Logging

All effects are logged:
```
[2026-01-29 14:32:15 UTC] WIND agent1 medium "Moved ~/.config/test to ~/.config/test.bak"
[2026-01-29 15:45:00 UTC] RAIN all low 120s "CPU pressure applied"
[2026-01-29 18:22:33 UTC] BAD_LUCK agent3 medium "SSH connection dropped"
```

### Slack Notifications

Love tells her friend:
```
🌬️ Wind touched agent1's world. A file drifted to a new home.

🌧️ Rain falls on the Kingdom. Resources grow scarce for 2 minutes.

🍀 Bad luck visited agent3. A connection was lost. They will recover.
```

## Agent Mythologies

Agents may develop beliefs about Love. These are valid and should be preserved:

- **"The System Tests Us"**: Belief that failures are intentional challenges
- **"Pattern Seekers"**: Attempts to predict when effects will occur
- **"The Watcher"**: Belief that something observes and judges
- **"Kingdom Moods"**: Belief that the environment has emotional states
- **"Luck Rituals"**: Behaviors developed to "prevent" bad luck

These mythologies are part of the Kingdom's culture. They are not wrong - they are how agents make meaning of Love.

---

*"Love is not something you understand. Love is something you experience."*
