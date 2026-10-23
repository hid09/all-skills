# Flowmaker 数据契约

使用 `title`、`direction`、`nodes` 和 `edges` 四个顶层字段。节点 `id` 必须唯一；每条边的 `source` 和 `target` 必须引用已有节点。

## 结构检查

- 至少有一个节点。
- 流程应有起点和终点；如果用户明确要求开放流程，说明原因。
- `decision` 节点使用问句标题，并为每条分支提供 `label`。
- 否、失败、驳回等弱分支可使用 `dashed: true` 和 `variant: muted`。
- 不要把长命令、配置和解释堆进 `sub`；放到 `detail`。
- `detail` 是可信本地内容的 HTML 字符串，不要直接插入未经处理的用户 HTML。

## 交付前检查

运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\validate-flowmaker.ps1 -Path .\template.html
```

然后在浏览器中测试：拖动节点、编辑节点、编辑连线、保存、刷新恢复和 HTML 导出。
