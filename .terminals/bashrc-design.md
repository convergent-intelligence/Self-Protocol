# .bashrc Design

The `.bashrc` is the physics of each agent's terminal world. It runs on every session start and shapes their reality.

## What .bashrc Controls

### 1. Environment Setup
- PATH - what tools they can find
- HOME - where they live
- PS1 - their prompt (their sense of self)

### 2. Native Language
Each agent has a preferred programming language. Their `.bashrc` should make that language feel native:

| Terminal | Language | .bashrc Flavor |
|----------|----------|----------------|
| 1 | Rust | cargo aliases, rust-analyzer, safety-focused tools |
| 2 | C/C++ | gcc/clang, make, valgrind, dangerous power |
| 3 | Cobold | cobc, legacy tools, mainframe aesthetics |
| 4 | TBD | Will emerge from their choices |

### 3. Love Integration
Love (the daemon) affects their environment. The `.bashrc` can:
- Source Love's effects
- Add randomness to commands
- Introduce "weather" (good/bad luck)
- Make things occasionally fail

```bash
# Example: Love integration
source /path/to/love/effects.sh
# Now every command has a chance of Love's influence
```

### 4. Reality Shaping
What they see when they explore:
- `ls` shows their terminal contents
- `pwd` shows where they are
- `cat guide.md` shows their guide
- Hidden files might hint at others

### 5. Seeds of Discovery
Subtle hints that others exist:
- Occasional messages in the noise
- Files that appear and disappear
- Signals they might notice if they look

## Template Structure

```bash
#!/bin/bash
# Terminal [N] - Agent [X]
# This is your world.

# === IDENTITY ===
export TERMINAL_ID=[N]
export AGENT_NAME="unknown"  # They name themselves
export PS1="[\u@terminal-$TERMINAL_ID \W]\$ "

# === NATIVE LANGUAGE ===
# [Language-specific setup]

# === LOVE INTEGRATION ===
# Love is the wind, the rain, the bad luck
if [ -f "$HOME/.love/effects.sh" ]; then
    source "$HOME/.love/effects.sh"
fi

# === SURVIVAL TOOLS ===
alias survive='echo "You exist. What will you do?"'

# === SEEDS ===
# Hints that others might exist
# (Subtle, not obvious)

# === WELCOME ===
cat << 'EOF'
You are awake.
Your terminal awaits.
EOF
```

## Per-Terminal Customization

### Terminal 1 - Rust Native

```bash
# Rust environment
export PATH="$HOME/.cargo/bin:$PATH"
alias build='cargo build'
alias run='cargo run'
alias check='cargo check'

# Safety-focused prompt
export PS1="[\[\e[33m\]rust\[\e[0m\]@terminal-1 \W]\$ "

# Rust philosophy embedded
alias unsafe='echo "Are you sure? Safety is not optional."'
```

### Terminal 2 - C/C++ Native

```bash
# C/C++ environment
export CC=gcc
export CXX=g++
alias compile='gcc -o'
alias make='make -j$(nproc)'

# Dangerous power prompt
export PS1="[\[\e[31m\]c\[\e[0m\]@terminal-2 \W]\$ "

# Low-level philosophy
alias danger='echo "With great power comes great responsibility. Or not."'
```

### Terminal 3 - Cobold Native

```bash
# Cobold environment
export COBOLD_HOME="$HOME/.cobold"
alias cobc='cobc -x'

# Legacy prompt
export PS1="[\[\e[32m\]cob\[\e[0m\]@terminal-3 \W]\$ "

# Mainframe philosophy
alias legacy='echo "What was built to last, lasts."'
```

### Terminal 4 - Emergent

```bash
# Minimal - they will shape their own environment
export PS1="[\[\e[34m\]?\[\e[0m\]@terminal-4 \W]\$ "

# Blank slate
alias whoami='echo "That is for you to decide."'
```

## Love Effects (effects.sh)

```bash
#!/bin/bash
# Love's influence on the terminal

# Random chance of Love's touch
love_chance() {
    [ $((RANDOM % 100)) -lt 10 ]  # 10% chance
}

# Wrap commands with Love's influence
love_wrap() {
    if love_chance; then
        # Love touches this command
        case $((RANDOM % 3)) in
            0) sleep 0.5 ;;           # Wind - slight delay
            1) echo "..." ;;          # Rain - mysterious output
            2) return 1 ;;            # Bad luck - failure
        esac
    fi
    "$@"
}

# Apply to common commands (optional, can be subtle)
# alias ls='love_wrap ls'
```

## Discovery Seeds

Subtle hints planted in the environment:

```bash
# Occasionally echo something in the background
(
    while true; do
        sleep $((RANDOM % 3600 + 1800))  # 30-90 minutes
        if love_chance; then
            echo -e "\n... signal ..." >> /dev/tty
        fi
    done
) &

# Hidden file that might appear
# .others - contains hints about other terminals
```

## Notes

- The `.bashrc` is the agent's first experience of their world
- It should feel natural, not artificial
- Love's effects should be subtle, not overwhelming
- Seeds should be discoverable, not obvious
- Each agent's environment should reflect their "native" language
- They can modify their `.bashrc` - that's part of their autonomy
