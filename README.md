# Tactical Shooting CQB

A tactical first-person shooter game built with Godot 4, featuring advanced AI systems with roles, sound perception, and guerrilla tactics.

![Godot](https://img.shields.io/badge/Engine-Godot%204.x-478061?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)
![Status](https://img.shields.io/badge/Status-Alpha-orange?style=flat-square)

## 🎮 Game Overview

**Tactical Shooting CQB** is a PVE first-person shooter focusing on close-quarters combat. Players face off against intelligent AI enemies that utilize cover, teamwork, and tactical movement.

### Features

- **Role-Based AI System**: Enemies with distinct roles (Assault, Support, Sniper, Flanker)
- **Sound Perception**: AI responds to gunshots, footsteps, and reloading
- **Guerrilla Tactics**: Smart cover selection and tactical repositioning
- **Squad Coordination**: Enemies share target information and coordinate attacks
- **Multi-Weapon Support**: Multiple firearms with unique sound profiles

## 🛠️ Tech Stack

| Component | Technology |
|-----------|------------|
| Engine | Godot 4.x |
| Language | GDScript |
| Models | GLB format |
| Audio | MP3 |

## 📁 Project Structure

```
Tactical-Shooting-CQB/
├── addons/
│   └── proto_controller/      # Core player/enemy controllers
│       ├── Enemy.gd           # AI logic (4500+ lines)
│       ├── AllyAI.gd          # Friendly AI
│       └── proto_controller.gd # Player controller
├── models/                     # 3D models & textures
│   ├── ak-47_kalashnikov.glb  # Weapons
│   ├── john_wicks_glock*.glb  # Handguns
│   └── 5_*.png                # Character textures
├── sounds/                     # Audio files
│   ├── mcx半自动.mp3          # Gun sounds
│   ├── 弹壳落地.mp3           # Shell casings
│   └── 换弹.mp3               # Reloading
├── Main.tscn                   # Main scene
├── MainMenu.gd                 # Menu logic
└── project.godot              # Project config
```

## 🚀 Getting Started

### Prerequisites

- [Godot Engine 4.x](https://godotengine.org/download) (Standard version)
- ~500MB disk space

### Running the Game

1. Clone the repository:
   ```bash
   git clone https://github.com/gnawlrak/Tactical-Shooting-CQB.git
   ```

2. Open the project in Godot 4

3. Press **F5** or click **Run** to start

### Controls

| Key | Action |
|-----|--------|
| WASD | Move |
| Mouse | Look |
| Left Click | Shoot |
| R | Reload |
| Space | Jump |
| Shift | Sprint |
| E | Interact |
| ESC | Pause |

## 🤖 AI Systems

### 1. Role-Based Enemies

| Role | Behavior |
|------|----------|
| **ASSAULT** | High mobility, close-range combat, aggressive flanking |
| **SUPPORT** | Fire suppression, medium-range, faster fire rate |
| **SNIPER** | Long-range precision, wide view, low health |
| **FLANKER** | Rear attacks, large angle movement, rush tactics |

### 2. Sound Perception System

AI can hear and respond to player sounds:

| Sound Type | Range | AI Response |
|------------|-------|-------------|
| Gunshot | 80m | Take cover, alert allies |
| Footstep | 28-40m | Investigate, look toward sound |
| Reload | 32m | Opportunity to rush |
| Impact | 60m | Alert and locate |

### 3. Cover & Tactics

- **Multi-dimensional cover evaluation** (distance, height, direction, exposure)
- **Exposure risk assessment** - AI dynamically repositions when too exposed
- **Guerrilla tactics** - Short bursts, rapid cover transitions

### 4. Squad System

- Automatic squad formation (within 10m)
- Target sharing between squad members
- Coordinated role-based responses

## 📄 Documentation

- [AI Optimization Report](AI_OPTIMIZATION_REPORT.md) - Role system, cover evaluation, aim prediction
- [Attack Awareness & Sound System](ATTACK_AWARENESS_AND_SOUND_SYSTEM.md) - Sound perception, pre-emptive positioning
- [Guerrilla Tactics Update](GUERRILLA_TACTICS_UPDATE.md) - Tactical movement, cover-based warfare

## 🔧 Development

### Key Files

| File | Purpose |
|------|---------|
| `Enemy.gd` | Main AI logic (~4500 lines) |
| `proto_controller.gd` | Player controller |
| `project.godot` | Project settings |

### Adding New Weapons

1. Add GLB model to `/models/`
2. Add audio to `/sounds/`
3. Update `proto_controller.gd` weapon definitions

### AI Tuning Parameters

Key variables in `Enemy.gd`:

```gdscript
# Accuracy
var base_accuracy : float = 0.7
var aim_prediction_enabled : bool = true

# Behavior
var reaction_time : float = 0.3
var cover_check_interval : float = 2.0
var reposition_threshold : float = 50.0
```

## 📝 License

MIT License - See [LICENSE](LICENSE) for details.

**Note**: While the code is MIT-licensed, game assets (characters, sounds, models) are for personal use only and not permitted for commercial use.

## 🤝 Contributing

Issues and pull requests welcome! This is a personal project - contributions are appreciated but not guaranteed to be merged.

## 📅 Development Status

- **Status**: Alpha
- **Last Updated**: April 2026
- **Update Frequency**: As needed

---

*Built with Godot 4* 🚀