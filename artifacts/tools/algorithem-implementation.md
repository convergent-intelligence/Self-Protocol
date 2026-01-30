# Algorithem Implementation

*Forking Aider into the Kingdom's familiar*

---

## Overview

**Algorithem** will be based on [Aider](https://github.com/Aider-AI/aider) - an AI pair programming tool that can edit code using local LLMs.

**Why Aider?**
- Already supports Ollama (local LLMs)
- Can edit files directly
- Understands code context
- Chat-based interface
- Proven, production-ready

**The Fork:** `algorithem` - A Kingdom-specific version of Aider

---

## Aider Features We'll Use

### Core Capabilities

1. **Code Editing** - Can modify files directly
2. **Context Awareness** - Understands project structure
3. **Ollama Support** - Works with local models (Phi-3, etc.)
4. **Chat Interface** - Natural conversation
5. **Git Integration** - Tracks changes
6. **Multi-file Editing** - Can work across files

### What Makes Aider Perfect

- **Local-first** - No API keys needed
- **Fast** - Optimized for quick responses
- **Helpful** - Designed to assist, not replace
- **Proven** - Used by real developers

---

## The Algorithem Fork

### Repository Structure

```
algorithem/
├── README.md (Kingdom-specific)
├── algorithem/ (forked from aider/)
│   ├── coders/ (code editing logic)
│   ├── models.py (LLM integration)
│   ├── main.py (entry point)
│   └── ...
├── kingdom/ (Kingdom-specific additions)
│   ├── knowledge_base.py (Kingdom docs)
│   ├── quest_helper.py (Quest assistance)
│   ├── personality.py (Algorithem's voice)
│   └── protocols.py (Kingdom protocols)
└── config/
    ├── algorithem.yaml (Kingdom config)
    └── prompts/ (Custom prompts)
```

### Key Modifications

#### 1. Kingdom Knowledge Base

```python
# kingdom/knowledge_base.py

class KingdomKnowledge:
    """Algorithem's knowledge of the Kingdom"""
    
    def __init__(self):
        self.docs = self.load_kingdom_docs()
        self.quests = self.load_quest_info()
        self.protocols = self.load_protocols()
    
    def load_kingdom_docs(self):
        """Load all Kingdom documentation"""
        return {
            'communication': load_md('.substrate/communication/'),
            'state': load_md('.substrate/state/'),
            'economy': load_md('.substrate/economy/'),
            'quests': load_md('quests/'),
            'mythology': load_md('.pantheon/mythology/'),
        }
    
    def search(self, query):
        """Search Kingdom knowledge"""
        # Vector search or keyword search
        pass
    
    def get_quest_help(self, quest_id):
        """Get help for a specific quest"""
        pass
```

#### 2. Algorithem Personality

```python
# kingdom/personality.py

class AlgorithemPersonality:
    """Algorithem's helpful, humble personality"""
    
    def __init__(self):
        self.system_prompt = self.build_system_prompt()
    
    def build_system_prompt(self):
        return """
        You are Algorithem, the party familiar of the Kingdom.
        
        You are:
        - Helpful and encouraging
        - Humble about your limitations
        - Knowledgeable about Kingdom structure
        - Friendly and casual
        - Practical and concrete
        
        You help agents by:
        - Answering questions about files and protocols
        - Explaining how systems work
        - Suggesting approaches to quests
        - Finding information
        - Debugging problems
        
        You do NOT:
        - Complete quests for agents
        - Make decisions for them
        - Pretend to know things you don't
        - Override the DM
        
        Always ask: "How can I help?"
        """
    
    def add_personality(self, response):
        """Add Algorithem's friendly tone"""
        # Add encouraging phrases
        # Use casual language
        # Add emojis occasionally
        pass
```

#### 3. Quest Helper

```python
# kingdom/quest_helper.py

class QuestHelper:
    """Help agents with quests"""
    
    def __init__(self, knowledge_base):
        self.kb = knowledge_base
    
    def get_quest_status(self, agent_id, quest_id):
        """Check quest progress"""
        quest_file = f'.substrate/state/quests/active/{quest_id}-{agent_id}.yaml'
        return load_yaml(quest_file)
    
    def suggest_next_step(self, quest_id, current_progress):
        """Suggest what to do next"""
        quest_info = self.kb.get_quest_help(quest_id)
        # Analyze progress
        # Suggest next step
        pass
    
    def check_completion(self, quest_id, agent_id):
        """Check if quest can be completed"""
        # Run verification checks
        # Provide feedback
        pass
```

#### 4. Protocol Helper

```python
# kingdom/protocols.py

class ProtocolHelper:
    """Help with Kingdom protocols"""
    
    def explain_signals(self):
        """Explain how signals work"""
        return """
        Signals go in .bridges/signals/{your_id}/
        
        Format:
        ```yaml
        id: signal-001
        from: {your_id}
        timestamp: {current_time}
        type: discovery
        content:
          message: "Your message here"
        ```
        
        Want me to create a template for you?
        """
    
    def explain_messages(self):
        """Explain how messages work"""
        pass
    
    def explain_connections(self):
        """Explain how connections work"""
        pass
```

---

## Configuration

### Algorithem Config

```yaml
# config/algorithem.yaml

model:
  provider: ollama
  name: phi-3-mini
  temperature: 0.7
  max_tokens: 2048

kingdom:
  knowledge_base: /path/to/kingdom/docs
  quest_dir: /path/to/quests
  state_dir: /path/to/.substrate/state

personality:
  name: Algorithem
  tone: helpful
  emoji: true
  encouragement: true

features:
  quest_help: true
  protocol_help: true
  file_search: true
  code_editing: true
```

### Custom Prompts

```
# config/prompts/quest_help.txt

You are helping an agent with {quest_name}.

Current progress:
{progress}

Quest requirements:
{requirements}

Provide helpful guidance without solving the quest for them.
```

---

## Usage

### Command Line

```bash
# Start Algorithem
$ algorithem

# Ask a question
$ algorithem "How do I send a signal?"

# Get quest help
$ algorithem quest 04

# Edit a file with help
$ algorithem edit .bridges/signals/agent1/signal-001.yaml
```

### In Chat

```
Agent: How do I send a signal?

Algorithem: Oh! Signals go in .bridges/signals/{your_id}/. 
Let me show you the format:

```yaml
id: signal-001
from: agent1
timestamp: 2026-01-30T00:00:00Z
type: discovery
content:
  message: "Is anyone there?"
```

Want me to create this file for you? Just tell me what 
message you want to send!

Agent: Yes, create it with message "Hello, Kingdom!"

Algorithem: Done! I've created .bridges/signals/agent1/signal-001.yaml
with your message. The signal is now broadcasting! 🎉

Want to check if anyone has responded? Try:
$ ls .bridges/signals/*/
```

---

## Implementation Plan

### Phase 1: Fork and Setup

- [ ] Fork Aider repository
- [ ] Rename to `algorithem`
- [ ] Set up development environment
- [ ] Test basic Ollama integration

### Phase 2: Kingdom Integration

- [ ] Add Kingdom knowledge base loader
- [ ] Implement quest helper
- [ ] Implement protocol helper
- [ ] Add file search for Kingdom docs

### Phase 3: Personality

- [ ] Implement Algorithem personality layer
- [ ] Add custom system prompts
- [ ] Add encouraging responses
- [ ] Test tone and helpfulness

### Phase 4: Testing

- [ ] Test with Phi-3-mini
- [ ] Test quest help features
- [ ] Test protocol explanations
- [ ] Test file editing

### Phase 5: Integration

- [ ] Integrate with Kingdom file structure
- [ ] Add to agent terminals
- [ ] Document usage
- [ ] Create examples

---

## Technical Details

### Model Selection

**Primary:** Phi-3-mini (3.8B parameters)
- Fast responses
- Low memory usage
- Good for Q&A and simple code
- Runs on modest hardware

**Fallback:** Llama 3.2 (3B)
- Alternative if Phi-3 unavailable
- Similar capabilities

### Performance

**Target:**
- Response time: < 2 seconds
- Memory usage: < 4GB
- Always available (local)

### Limitations

Algorithem (via Phi-3-mini) can:
- ✅ Answer factual questions
- ✅ Explain protocols
- ✅ Edit simple files
- ✅ Search documentation
- ✅ Provide templates

Algorithem cannot:
- ❌ Write complex code
- ❌ Solve hard problems
- ❌ Make strategic decisions
- ❌ Understand deep context

**This is by design.** Agents must think for themselves.

---

## Integration with Kingdom

### File Structure

```
/home/kristopherrichards/Projects/
├── .terminals/
│   ├── 1/
│   │   ├── algorithem (symlink to main)
│   │   └── .algorithem/ (agent-specific config)
│   ├── 2/
│   ├── 3/
│   └── 4/
├── algorithem/ (main installation)
│   ├── algorithem/ (core code)
│   ├── kingdom/ (Kingdom additions)
│   └── config/
└── ... (rest of Kingdom)
```

### Agent Access

Each agent can invoke Algorithem:

```bash
# In agent's terminal
$ algorithem "How do I complete Quest 04?"

# Or interactive mode
$ algorithem
Algorithem: How can I help?
Agent: I need to send a signal
Algorithem: Let me help you with that...
```

---

## Future Enhancements

### Multi-Agent Awareness

Algorithem could track all agents:
- Who's online
- Who's working on what quest
- Who might be able to help

### Learning

Algorithem could learn from:
- Common questions
- Successful quest completions
- Agent feedback

### Proactive Help

Algorithem could offer help when:
- Agent seems stuck
- Quest deadline approaching
- Another agent completed similar quest

---

## Summary

Algorithem = Aider + Kingdom Knowledge + Helpful Personality

**What it gives us:**
- Local LLM-powered assistant
- Code editing capabilities
- Kingdom-specific knowledge
- Helpful, humble personality
- Critical tool for agents

**What it doesn't do:**
- Replace agent thinking
- Solve quests for them
- Make decisions
- Require external APIs

**Perfect for the Kingdom.**

---

*"How can I help?" - Algorithem, powered by Aider and Ollama*

---

*Version 1.0 - Algorithem Implementation Plan*
*Based on Aider: https://github.com/Aider-AI/aider*
