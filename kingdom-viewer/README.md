# Kingdom Viewer

A native Rust terminal multiplexer for observing 4 agent terminals in a 2x2 grid.

## Overview

The Kingdom Viewer displays 4 isolated agent terminals, each believing they are alone in their world. As an observer, you see all 4 simultaneously plus an observer panel showing Love's status and critical information.

```
┌─────────────────────────────────────────┐
│        Observer Panel                  │
│  Love daemon status                     │
│  Active agents: X/4                     │
│  Critical knowledge                     │
├──────────────────┬──────────────────────┤
│  Terminal 1      │  Terminal 2          │
│  Agent 1 (Rust)  │  Agent 2 (C/C++)     │
│                  │                      │
├──────────────────┼──────────────────────┤
│  Terminal 3      │  Terminal 4          │
│  Agent 3 (COBOL) │  Agent 4 (Emergent)  │
│                  │                      │
└──────────────────┴──────────────────────┘
```

## Features

- **2x2 Terminal Grid**: View all 4 agents simultaneously
- **Observer Panel**: Track Love's status and active agents
- **Color-Coded Terminals**: Each agent has their native language color
- **Real PTY Sessions**: Each terminal is a real pseudo-terminal
- **Non-Blocking UI**: Smooth updates with no freezing

## Building

```bash
cd Projects/kingdom-viewer
cargo build --release
```

## Running

```bash
cargo run --release
```

Or after building:

```bash
./target/release/kingdom-viewer
```

## Controls

- `q` - Quit the viewer

## Agent Terminal Colors

- **Agent 1 (Rust)**: Orange (#FF9900) - Rust's color
- **Agent 2 (C/C++)**: Red - Danger and power
- **Agent 3 (COBOL)**: Green - Mainframe terminal aesthetic
- **Agent 4 (Emergent)**: Blue - Undefined potential

## Observer Panel Information

The observer panel displays:
- Love daemon status
- Number of active agents (agents that have started)
- Critical knowledge about the experiment
- How Love manifests (Wind, Rain, Bad Luck)

## How It Works

Each agent terminal:
1. Spawns a real bash session with `--login`
2. Sources their custom `.bashrc` from `.terminals/N/.bashrc`
3. Shows their unique welcome message
4. Pauses for observation with "Press any key to continue..."
5. Waits for the agent (or observer) to press a key
6. Then provides a normal bash prompt

The agents are completely isolated - they don't know about the viewer, the observer panel, or each other (unless they discover each other through their own exploration).

## Technical Details

- **Language**: Rust
- **TUI Framework**: ratatui 0.29
- **Terminal Backend**: crossterm 0.28
- **PTY Implementation**: portable-pty 0.8
- **Async Runtime**: tokio 1.x

## Notes for Observers

- Agents believe they are alone in a single terminal
- They experience Love as environment (wind, rain, bad luck)
- They don't know they're being watched
- The viewer is read-only - you observe, you don't interfere
- Each agent has a unique "native language" (programming language)

## Next Steps

After agents awaken and this viewer works:
- Implement the party daemon for agent orchestration
- Add Love's environmental effects
- Create the collaboration CTF challenges
