# 鲸鲸小镇专注版 · 贡献者与 Agent 指南

从 [README](README.md) 了解小镇和启动方式。主场景是 `focus_only/FocusTown.tscn`。人物动作、天气特效和建造素材的修改示例在 [画面与动作 Skill](.agents/skills/whale-focus-visuals/SKILL.md)。

| 想改的内容 | 从这里开始 | 怎样复看 |
| --- | --- | --- |
| 镇民动作和道具 | `focus_only/VirtualTownsfolk.gd` 的 `pose`、`draw_tool` 和走路帧 | 开钟看三组上工，暂停看所有人收起工具并散开 |
| 天气与光照 | `environment/FocusCalendar.gd` 提供本地天气和日照，`WeatherAppearance.gd`、`WeatherLayer.gd` 和海岸着色器绘制 | 用同一机位对照晴雨、雪和昼夜切换 |
| 建筑和工地 | `focus_only/town.json`、`world/BuildingStageLayer.gd` 和 `art/buildings/` | 对照规划、施工、落成三态与工人站位 |

用临时存档或独立用户目录验证。画面读取计时与建设结果，结算和存档由 `adapters/StandaloneEngineBridge.gd` 负责。共建素材的作者、来源和许可写进 [素材清单](art/asset-license.json)，现有授权状态见 [ASSETS.md](ASSETS.md)。

提交时说明你改了哪部分、用哪个 Godot 版本复现，以及其他人可以到哪个机位看到变化。一个动作、一处天气效果或一张贴图都可以独立评审。
