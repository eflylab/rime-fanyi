# rime-fanyi · Rime 候选词外语译词

在 Rime 输入法（macOS 鼠鬚管 Squirrel / Linux fcitx5-rime 等）打中文时，**候选词右侧同步显示外语译词**（中→英 / 中→日）。基于 librime-lua 实现，**无需编译输入法本身**。

灵感来自[青简输入法](https://github.com/qingjian-team/qingjian)。

效果（默认 `replace` 模式，中→英）：

```
1 开发  develop / development
2 编程  programming / to program
3 好    good / well
```

切换为日语（`fanyi/dictionary: cn2ja`）：

```
1 开发  開発（かいはつ）
2 好    良い（よい）
```

**译词上屏**：输入时高亮某候选，按 `Ctrl+Enter`，即可把该候选的译词整串上屏（默认开启，可配置、可关闭）。

---

## 特性

- 候选词旁同步显示译词，支持中→英、中→日，可扩展更多语言。
- 两种显示模式：`replace`（只显示译词）/ `append`（保留原注释如五笔码，译词追加其后）。
- 高频词覆盖表，修正词典释义顺序。
- 译词上屏：高亮候选 + 快捷键，一键把译词上屏。
- 全部通过用户配置实现，不改动输入法源码，可随时卸载。

## 环境要求

- 已安装 Rime 输入法前端，且内置 **librime-lua** 插件。
  - macOS 鼠鬚管（Squirrel）官方发行版自带。
- 输入法用户配置目录可写（macOS 为 `~/Library/Rime/`）。

## 目录结构

```
rime-fanyi/
├── install.sh              # 一键安装 / 卸载脚本
├── test_fanyi.lua          # 单元测试（脱离 librime，用 lua 跑）
├── README.md
├── LICENSE                 # MIT（代码部分）
├── lua/
│   ├── fanyi.lua           # 滤镜：为候选加译词注释
│   ├── fanyi_commit.lua    # 处理器：快捷键译词上屏
│   └── fanyi_core.lua      # 共享核心：配置 / 词典 / 查询
├── dict/
│   ├── cn2en.tsv           # 中→英词典（CC-CEDICT，约 11.5 万条）
│   ├── cn2ja.tsv           # 中→日词典（精选高频，约 280 条）
│   └── cn_overrides.tsv    # 高频词覆盖表（优先于主词典）
└── fanyi.custom.yaml       # 配置参考模板
```

## 安装

```bash
git clone https://github.com/eflylab/rime-fanyi.git
cd rime-fanyi
./install.sh
```

脚本会：
1. 复制 `lua/*.lua` → `~/Library/Rime/lua/`
2. 复制 `dict/*.tsv` → `~/Library/Rime/`
3. 在目标输入方案的 `.custom.yaml` 中挂载滤镜与处理器
4. 触发重新部署

**指定挂载的方案**：脚本默认从 `~/Library/Rime/default.custom.yaml` 的 `schema_list`
自动探测；也可手动指定：

```bash
FANYI_SCHEMAS="rime_ice double_pinyin" ./install.sh
```

卸载：

```bash
./install.sh --uninstall
```

## 配置

安装后，在 `~/Library/Rime/<方案>.custom.yaml` 的 `fanyi` 区块调整，**改完重新部署生效**：

```yaml
patch:
  fanyi/enabled: true              # 译词显示开关
  fanyi/mode: replace              # replace=只显示译词（默认） / append=追加保留五笔码
  fanyi/separator: " · "           # append 模式下原文与译词的分隔符
  fanyi/dictionary: cn2en          # 语言/词典：cn2en=英语 / cn2ja=日语
  fanyi/overrides: cn_overrides    # 高频词覆盖表（优先于主词典）
  fanyi/commit_enabled: true       # 译词上屏开关
  fanyi/commit_key: "Control+Return"  # 译词上屏快捷键
  engine/filters:
    - lua_filter@*fanyi
  "engine/processors/@before 0": lua_processor@*fanyi_commit
```

### 显示模式

| mode | 有码提示时 | 无码提示时 |
|------|-----------|-----------|
| `replace`（默认） | `女孩子 girl` | `好 good / well` |
| `append` | `女孩子 bbbb · girl` | `好 good / well` |

### 切换语言

把 `fanyi/dictionary` 改为词典名（`cn2en` / `cn2ja`），重新部署即可：

```bash
"/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" --reload
# 或在菜单栏鼠鬚管图标里选「重新部署」
```

### 译词上屏

开启后（`fanyi/commit_enabled: true`）：

1. 打出中文候选，用方向键/数字高亮你想取译词的那个候选；
2. 按快捷键（默认 `Ctrl+Enter`）；
3. 该候选的**译词整串**上屏，当前输入清空。

- 若当前高亮候选**没有译词**，按快捷键不做任何动作。
- 快捷键在 `fanyi/commit_key` 修改，格式为「修饰键+键名」，修饰键支持
  `Control` / `Alt`(或 `Option`) / `Super`(或 `Command`) / `Shift`，例如：
  `"Control+Return"`、`"Control+Shift+Return"`、`"Alt+Return"`。
- 设为 `fanyi/commit_enabled: false` 可关闭（默认开启）。

### 高频词覆盖表

词典（CC-CEDICT）对部分词条的释义顺序不符合口语常用义（例如"开发"的首义是
"to exploit (a resource)"）。`dict/cn_overrides.tsv` 把这类高频词的常用义**前置覆盖**，
优先级**高于**主词典。

格式与主词典相同（`中文<TAB>译词`）。想修正某个词，直接在此表加一行：

```
开发	develop / development
功能	function / feature
```

> 覆盖表对**所有语言词典**生效。

## 词典

| 文件 | 语言 | 规模 | 来源 / 许可 |
|------|------|------|-------------|
| `dict/cn2en.tsv` | 中→英 | 约 11.5 万条 | [CC-CEDICT](https://www.mdbg.net/chinese/dictionary?page=cedict)，CC BY-SA 4.0 |
| `dict/cn2ja.tsv` | 中→日 | 约 280 条 | 人工整理（高频字词）|
| `dict/cn_overrides.tsv` | 中→英 | 约 150 条 | 人工整理 |

TSV 格式：`中文<TAB>译词`，`#` 开头为注释行，多义用 ` / ` 分隔。

### 扩充 / 替换词典

直接编辑 `dict/<词典名>.tsv`，重新运行 `./install.sh` 即可。

**增加新语言（如法语）**：新增 `dict/cn2fr.tsv`，把配置改为
`fanyi/dictionary: cn2fr`，重新安装 / 部署即可，无需改代码。

**重新生成中英词典（CC-CEDICT → TSV）**：

```bash
curl -sL -o cedict.txt.gz \
  "https://www.mdbg.net/chinese/export/cedict/cedict_1_0_ts_utf-8_mdbg.txt.gz"
gunzip cedict.txt.gz
python3 - <<'PYEOF'
import re
from collections import defaultdict
def clean(defs):
    out=[]
    for d in defs:
        d=d.strip()
        if not d or d.lower().startswith(('see ','variant of','old variant','also written','surname ')):
            continue
        d=re.sub(r'\|[^\]]*(\[[^\]]*\])','',d); d=re.sub(r'\[[^\]]*\]','',d).strip()
        if d: out.append(d)
    return out
entries=defaultdict(list)
with open('cedict.txt',encoding='utf-8') as f:
    for line in f:
        m=re.match(r'^(\S+)\s+(\S+)\s+\[([^\]]*)\]\s+/(.*)/\s*$',line)
        if not m: continue
        simp,defs=m.group(2),m.group(4)
        entries[simp].extend(clean(defs.split('/')))
with open('dict/cn2en.tsv','w',encoding='utf-8') as o:
    o.write("# 中→英（源自 CC-CEDICT，CC BY-SA 4.0）\n")
    for k in sorted(entries):
        seen=set(); vals=[]
        for v in entries[k]:
            v=v.split(';')[0].strip()
            if v and v not in seen: seen.add(v); vals.append(v)
        if vals: o.write(f"{k}\t{' / '.join(vals[:4 if len(k)==1 else 3])}\n")
PYEOF
```

## 工作原理

Rime 候选词的灰色副文本叫 **comment（注释）**。librime 内置 `librime-lua` 插件，
可在方案引擎的 `filters` / `processors` 链中插入 Lua 组件：

- **滤镜 `fanyi.lua`**：遍历候选流，用候选词文本查内存词典（首次使用时从 TSV 加载），
  命中则改写候选 comment，再逐个 `yield` 回候选流。前端自然把 comment 渲染在候选右侧。
- **处理器 `fanyi_commit.lua`**：前插到 `processors` 链，捕获按键；命中快捷键时取当前
  高亮候选，查得译词后清空输入并上屏。
- **核心 `fanyi_core.lua`**：两者共享的配置读取、词典加载与查询逻辑。

关键 API（[librime-lua 文档](https://github.com/hchunhui/librime-lua/wiki/API)）：
- 滤镜 `func(translation, env)`，`for cand in translation:iter() do yield(cand) end`
- 处理器 `func(key_event, env)`，返回 `0=拒绝 / 1=接受 / 2=不处理`
- 改 comment：`cand:get_genuine().comment = ...`（兼容 ShadowCandidate）
- 读配置：`env.engine.schema.config:get_string("fanyi/dictionary")`
- 取高亮候选：`env.engine.context:get_selected_candidate()`
- 上屏：`env.engine:commit_text(txt)`；清空：`env.engine.context:clear()`
- 用户目录：`rime_api.get_user_data_dir()`

## 常见问题 / 踩坑记录

### 挂载语法不能带 `.成员名`

```yaml
# ❌ 错误：librime 把 ".filter" 当成子目录/子表路径，导致组件解析异常、候选栏变空
engine/filters:
  - lua_filter@*fanyi.filter

# ✅ 正确：func 必须放在模块返回值的顶层
engine/filters:
  - lua_filter@*fanyi
```

`lua_filter@*模块名` 表示用 `require` 加载 `~/Library/Rime/lua/模块名.lua`，取其返回表中名为 `func` 的成员。

### 一个模块只能顶层导出 `func`

同一 lua 模块内的多个组件（如 filter + processor）必须拆成独立文件，
各自顶层导出 `func`（本项目的 `fanyi.lua` 与 `fanyi_commit.lua`）。

### 向列表前插用 `@before 0`（注意空格与引号）

```yaml
# ✅ 正确：@before 与数字间有一个空格，整条路径加引号
"engine/processors/@before 0": lua_processor@*fanyi_commit
# ❌ 错误：会被当成两段路径
engine/processors/@before/0
```

### 方案 build 缓存会导致 patch 不生效

改完 `.custom.yaml` 后若配置没进 `build/xxx.schema.yaml`，删缓存强制重建：

```bash
rm -f ~/Library/Rime/build/<方案>.*
"/Library/Input Methods/Squirrel.app/Contents/MacOS/Squirrel" --reload
```

### Rime 的 patch 作用域

`default.custom.yaml` 的 patch **只作用于 `default.yaml`**，不会作用于各输入方案。
滤镜/处理器必须写进**方案自己的** `.custom.yaml`。

### 译词上屏无效

- 确认高亮候选**确实有译词**（无译词时不动作）。
- 确认 `fanyi/commit_enabled: true`。
- 快捷键可能被系统/应用占用，可换成 `"Control+Shift+Return"` 等。
- 查日志 `$TMPDIR/rime.squirrel/` 下是否有 `[fanyi] 译词上屏: ...`。

## 测试

```bash
lua test_fanyi.lua
```

脱离 librime 环境（mock `log`/`rime_api`/`yield`/`Candidate`），用受控测试词典验证
词典加载、append/replace 模式、分隔符、开关、多词典切换、覆盖表优先级，共 10 项。

## 已知限制

- 译词与候选**同行内联**显示，不是独立一列（要分列需改前端源码）。
- 逐词译词以**词组候选**效果最佳；整句候选只按整句匹配。
- 词典释义顺序未必符合口语常用义，已用覆盖表修正常见词。
- 译词上屏依赖当前高亮候选有译词；快捷键可能在某些应用中被占用。

## 许可

- 代码：MIT，见 [LICENSE](./LICENSE)。
- 词典 `dict/cn2en.tsv` 源自 **CC-CEDICT**，采用 **CC BY-SA 4.0**，见
  [NOTICE](./NOTICE)。分发时请保留署名与许可。
- `dict/cn2ja.tsv`、`dict/cn_overrides.tsv`：本项目整理，随代码以 MIT 提供。

## 致谢

- [Rime](https://rime.im/) / [librime](https://github.com/rime/librime) / [librime-lua](https://github.com/hchunhui/librime-lua)
- [CC-CEDICT](https://www.mdbg.net/chinese/dictionary?page=cedict) 词典
- [青简输入法](https://github.com/qingjian-team/qingjian) 的创意灵感
