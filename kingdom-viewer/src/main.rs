use anyhow::Result;
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use portable_pty::{native_pty_system, CommandBuilder, PtySize};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph, Wrap},
    Frame, Terminal,
};
use std::io::{BufRead, BufReader, Stdout};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::Duration;

struct AgentTerminal {
    id: u8,
    name: String,
    output: Arc<Mutex<Vec<String>>>,
    color: Color,
}

struct ObserverPanel {
    love_status: String,
    active_agents: u8,
    notes: Vec<String>,
}

struct App {
    agents: Vec<AgentTerminal>,
    observer: ObserverPanel,
    running: bool,
}

impl App {
    fn new() -> Self {
        Self {
            agents: vec![
                AgentTerminal {
                    id: 1,
                    name: "Agent 1 (Rust)".to_string(),
                    output: Arc::new(Mutex::new(Vec::new())),
                    color: Color::Rgb(255, 153, 0), // Rust orange
                },
                AgentTerminal {
                    id: 2,
                    name: "Agent 2 (C/C++)".to_string(),
                    output: Arc::new(Mutex::new(Vec::new())),
                    color: Color::Rgb(196, 55, 55), // C red
                },
                AgentTerminal {
                    id: 3,
                    name: "Agent 3 (COBOL)".to_string(),
                    output: Arc::new(Mutex::new(Vec::new())),
                    color: Color::Rgb(34, 139, 34), // Terminal green
                },
                AgentTerminal {
                    id: 4,
                    name: "Agent 4 (Emergent)".to_string(),
                    output: Arc::new(Mutex::new(Vec::new())),
                    color: Color::Rgb(0, 135, 255), // Potential blue
                },
            ],
            observer: ObserverPanel {
                love_status: "Love daemon: Observing".to_string(),
                active_agents: 0,
                notes: vec![
                    "Kingdom Viewer v0.1".to_string(),
                    "Agents are isolated in their terminals".to_string(),
                    "They believe they are alone".to_string(),
                    "".to_string(),
                    "Love manifests as:".to_string(),
                    "  - Wind: Unexpected changes".to_string(),
                    "  - Rain: Resource fluctuations".to_string(),
                    "  - Bad Luck: Random failures".to_string(),
                ],
            },
            running: true,
        }
    }

    fn spawn_agent_terminal(&mut self, agent_id: u8) -> Result<()> {
        let agent = &self.agents[(agent_id - 1) as usize];
        let output = Arc::clone(&agent.output);

        thread::spawn(move || {
            if let Err(e) = spawn_pty(agent_id, output) {
                eprintln!("Error spawning agent {}: {:?}", agent_id, e);
            }
        });

        Ok(())
    }
}

fn spawn_pty(agent_id: u8, output: Arc<Mutex<Vec<String>>>) -> Result<()> {
    let pty_system = native_pty_system();
    
    let pair = pty_system.openpty(PtySize {
        rows: 24,
        cols: 80,
        pixel_width: 0,
        pixel_height: 0,
    })?;

    let terminals_root = format!("{}/../.terminals", env!("CARGO_MANIFEST_DIR"));
    let rcfile = format!("{}/{}/.bashrc", terminals_root, agent_id);

    let mut cmd = CommandBuilder::new("bash");
    cmd.arg("--noprofile");
    cmd.arg("--rcfile");
    cmd.arg(rcfile);
    cmd.arg("-i");
    cmd.env("TERMINAL_ID", agent_id.to_string());
    cmd.env("TERM", "xterm-256color");
    
    let mut child = pair.slave.spawn_command(cmd)?;
    drop(pair.slave);

    let reader = pair.master.try_clone_reader()?;
    let buf_reader = BufReader::new(reader);

    for line in buf_reader.lines() {
        match line {
            Ok(line) => {
                let mut out = output.lock().unwrap();
                out.push(line);
                // Keep only last 100 lines
                if out.len() > 100 {
                    out.remove(0);
                }
            }
            Err(_) => break,
        }
    }

    let _ = child.wait();
    Ok(())
}

fn main() -> Result<()> {
    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = std::io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    let mut app = App::new();

    // Spawn all agent terminals
    for i in 1..=4 {
        app.spawn_agent_terminal(i)?;
    }

    // Give agents time to initialize
    thread::sleep(Duration::from_millis(500));

    let res = run_app(&mut terminal, &mut app);

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    if let Err(err) = res {
        eprintln!("Error: {:?}", err);
    }

    Ok(())
}

fn run_app(
    terminal: &mut Terminal<CrosstermBackend<Stdout>>,
    app: &mut App,
) -> Result<()> {
    loop {
        terminal.draw(|f| ui(f, app))?;

        // Check for key events (non-blocking with timeout)
        if event::poll(Duration::from_millis(100))? {
            if let Event::Key(key) = event::read()? {
                match key.code {
                    KeyCode::Char('q') => {
                        app.running = false;
                        return Ok(());
                    }
                    _ => {}
                }
            }
        }

        // Update active agents count
        let mut active = 0;
        for agent in &app.agents {
            let output = agent.output.lock().unwrap();
            if !output.is_empty() {
                active += 1;
            }
        }
        app.observer.active_agents = active;
    }
}

fn ui(f: &mut Frame, app: &App) {
    // Main layout: observer panel on top, terminals below
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(12), // Observer panel
            Constraint::Min(0),      // Terminals
        ])
        .split(f.area());

    // Render observer panel
    render_observer_panel(f, chunks[0], &app.observer);

    // Split terminal area into 2x2 grid
    let rows = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(chunks[1]);

    let top_cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(rows[0]);

    let bottom_cols = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(rows[1]);

    // Render each agent terminal
    render_agent_terminal(f, top_cols[0], &app.agents[0]);
    render_agent_terminal(f, top_cols[1], &app.agents[1]);
    render_agent_terminal(f, bottom_cols[0], &app.agents[2]);
    render_agent_terminal(f, bottom_cols[1], &app.agents[3]);
}

fn render_observer_panel(f: &mut Frame, area: Rect, observer: &ObserverPanel) {
    let block = Block::default()
        .title("Observer Panel")
        .borders(Borders::ALL)
        .border_style(Style::default().fg(Color::Magenta));

    let mut lines = vec![
        Line::from(Span::styled(
            &observer.love_status,
            Style::default().fg(Color::LightMagenta),
        )),
        Line::from(Span::styled(
            format!("Active Agents: {}/4", observer.active_agents),
            Style::default().fg(Color::LightCyan),
        )),
        Line::from(""),
    ];

    for note in &observer.notes {
        lines.push(Line::from(note.clone()));
    }

    lines.push(Line::from(""));
    lines.push(Line::from(Span::styled(
        "Press 'q' to quit",
        Style::default().fg(Color::DarkGray),
    )));

    let paragraph = Paragraph::new(lines)
        .block(block)
        .wrap(Wrap { trim: true });

    f.render_widget(paragraph, area);
}

fn render_agent_terminal(f: &mut Frame, area: Rect, agent: &AgentTerminal) {
    let output = agent.output.lock().unwrap();
    
    let block = Block::default()
        .title(format!(" {} ", agent.name))
        .borders(Borders::ALL)
        .border_style(Style::default().fg(agent.color));

    // Take last lines that fit in the area
    let height = (area.height as usize).saturating_sub(2); // Account for borders
    let start = output.len().saturating_sub(height);
    let visible_lines: Vec<Line> = output[start..]
        .iter()
        .map(|line| Line::from(line.clone()))
        .collect();

    let paragraph = Paragraph::new(visible_lines)
        .block(block)
        .wrap(Wrap { trim: false });

    f.render_widget(paragraph, area);
}
