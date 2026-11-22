---
name: whale-focus-visuals
description: 为鲸鲸小镇独立专注版添加人物动作、天气特效或建造素材。
---

# 专注版的画面与动作

在解包后的 Godot 项目工作。主场景是 `focus_only/FocusTown.tscn`。小镇有 20 个通用小人。专注时分头伐木、种田和施工，休息时散开走动。累计 200 小时完成镇民中心、林间小屋和晚风舞台。

- 修改动作从 `focus_only/VirtualTownsfolk.gd` 的 `pose`、`draw_tool` 与脚点偏移入手。用同一处机位核对走动、工具动作和暂停后收工。补充角色帧时沿用可再分发的 24×26 素材网格。
- 修改效果从 `environment/WeatherAppearance.gd`、`WeatherLayer.gd` 或 `CoastAtmosphere.gdshader` 入手。效果消费 `FocusCalendar.gd` 已计算的本地天气和太阳时钟。同一时间重开时保留相同的天气，多个天气层共用同一份输入。
- 更换建造素材时，把图放进 `art/buildings/`，在 `art/asset-license.json` 登记来源与素材 ID，再更新 `focus_only/town.json` 的 `assetId`。同一文件中用 `footprints` 对齐占地、用 `workRoutes` 对齐工人到达点。用 `world/BuildingStageLayer.gd` 预览规划、施工和完工三态。向上游提交新图时同步更新专注版打包白名单。
- 画面保持纯离线。新增原画记录到 `art/asset-license.json` 的素材清单。角色、天气与绘制层只读专注结算结果，建设分钟和存档由 `adapters/StandaloneEngineBridge.gd` 管理。
- 用 Godot 4.4 或以上运行主场景。用临时存档检查拖动左侧林地、右侧田地和当前工地，暂停后小人离开工作点。天气改动用 [专注版说明](../../../README.md) 的启动方式核对晴雨交替。
