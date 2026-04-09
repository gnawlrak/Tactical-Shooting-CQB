# Tactical Shooting CQB - 战术射击游戏

基于 Godot 4 开发的第一人称射击游戏，具备先进的 AI 系统，包括角色区分、声音感知和游击战术。

![Godot](https://img.shields.io/badge/Engine-Godot%204.x-478061?style=flat-square)
![License](https://img.shields.io/badge/License-MIT-blue?style=flat-square)
![Status](https://img.shields.io/badge/Status-Alpha-orange?style=flat-square)

## 🎮 游戏简介

**Tactical Shooting CQB** 是一款专注于近距离战斗的 PVE 第一人称射击游戏。玩家需要对抗具备智能的 AI 敌人，这些敌人会利用掩体、团队协作和战术移动。

### 特色功能

- **角色系统 AI**：敌人分为不同角色（突击手、支援手、狙击手、侧翼手）
- **声音感知**：AI 能响应枪声、脚步声和换弹声
- **游击战术**：智能掩体选择和战术重新定位
- **小队协作**：敌人共享目标信息并协调攻击
- **多武器支持**：多种具有独特声音特征的枪械

## 🛠️ 技术栈

| 组件 | 技术 |
|------|------|
| 引擎 | Godot 4.x |
| 语言 | GDScript |
| 模型 | GLB 格式 |
| 音频 | MP3 |

## 📁 项目结构

```
Tactical-Shooting-CQB/
├── addons/
│   └── proto_controller/      # 核心玩家/敌人控制器
│       ├── Enemy.gd           # AI 逻辑 (4500+ 行)
│       ├── AllyAI.gd          # 友军 AI
│       └── proto_controller.gd # 玩家控制器
├── models/                     # 3D 模型和纹理
│   ├── ak-47_kalashnikov.glb  # 武器
│   ├── john_wicks_glock*.glb  # 手枪
│   └── 5_*.png                # 角色纹理
├── sounds/                     # 音频文件
│   ├── mcx半自动.mp3          # 枪声
│   ├── 弹壳落地.mp3           # 弹壳落地
│   └── 换弹.mp3               # 换弹
├── Main.tscn                   # 主场景
├── MainMenu.gd                 # 菜单逻辑
└── project.godot              # 项目配置
```

## 🚀 开始运行

### 环境要求

- [Godot Engine 4.x](https://godotengine.org/download)（标准版）
- 约 500MB 磁盘空间

### 运行游戏

1. 克隆仓库：
   ```bash
   git clone https://github.com/gnawlrak/Tactical-Shooting-CQB.git
   ```

2. 用 Godot 4 打开项目

3. 按 **F5** 或点击 **运行** 启动

### 按键操作

| 按键 | 动作 |
|------|------|
| WASD | 移动 |
| 鼠标 | 视角 |
| 左键 | 射击 |
| R | 换弹 |
| 空格 | 跳跃 |
| Shift | 冲刺 |
| E | 交互 |
| ESC | 暂停 |

## 🤖 AI 系统

### 1. 角色区分系统

| 角色 | 行为 |
|------|------|
| **突击手 (ASSAULT)** | 高机动性，近距离作战，积极侧翼包抄 |
| **支援手 (SUPPORT)** | 火力压制，中距离，射速较快 |
| **狙击手 (SNIPER)** | 远距离精确射击，宽视野，低血量 |
| **侧翼手 (FLANKER)** | 绕后偷袭，大角度移动，冲锋战术 |

### 2. 声音感知系统

AI 能听到并响应玩家的声音：

| 声音类型 | 范围 | AI 响应 |
|----------|------|---------|
| 枪声 | 80m | 寻找掩体，通知队友 |
| 脚步声 | 28-40m | 调查，朝声音方向看 |
| 换弹声 | 32m | 可能选择冲锋 |
| 撞击声 | 60m | 警觉并定位 |

### 3. 掩体与战术

- **多维度掩体评估**（距离、高度、方向、暴露程度）
- **暴露风险评估** - 暴露过高时 AI 会动态转移
- **游击战术** - 短点射，快速掩体转换

### 4. 小队系统

- 自动组队（10m 内）
- 小队成员间目标共享
- 基于角色的协调响应
  
## 🔧 开发

### 关键文件

| 文件 | 用途 |
|------|------|
| `Enemy.gd` | 主要 AI 逻辑（~4500 行） |
| `proto_controller.gd` | 玩家控制器 |
| `project.godot` | 项目设置 |

### 添加新武器

1. 将 GLB 模型添加到 `/models/`
2. 将音频添加到 `/sounds/`
3. 在 `proto_controller.gd` 中更新武器定义

### AI 调参

`Enemy.gd` 中的关键变量：

```gdscript
# 精度
var base_accuracy : float = 0.7
var aim_prediction_enabled : bool = true

# 行为
var reaction_time : float = 0.3
var cover_check_interval : float = 2.0
var reposition_threshold : float = 50.0
```

## 📝 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE)。

**注意**：虽然代码采用 MIT 许可证，但游戏素材（角色、音效、模型）仅供个人使用，禁止商用。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！这是个人项目，欢迎贡献但不保证合并。

## 📅 开发状态

- **状态**：Alpha
- **最后更新**：2026 年 4 月
- **更新频率**：随缘

---

*由 Godot 4 构建* 🚀
