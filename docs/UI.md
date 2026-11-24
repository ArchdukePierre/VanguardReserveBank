# Building a role

A role is a module `vrb/roles/<name>.lua` that returns `{ run = function() ... end }`. `boot.lua` calls `run()` with no arguments after setting `package.path` to `/vrb/?.lua`.

## Rules

- Lua 5.1 style for CC:Tweaked. No `goto`, no `//`, no integer bit operators. Use `bit32`. Use `%.0f` instead of `%d` for numbers that can pass 2^31.
- The screen only changes on input or on a server push. No repeating timers, no animation, no polling loops. An idle monitor must send no writes.
- Network calls block. `client:call(method, params, { admin = true })` swallows every other event until the reply arrives, so keep one call per user action and do not call from inside a timer wait.
- Every long screen has an idle timeout. A signed-in screen signs out on timeout.
- Text shown to players is plain and short. No emoji. No em dashes anywhere.
- No comments in the code. Names and structure carry the meaning.
- Money is integer cents. Format with `util.money`. Parse typed amounts with `util.parse_money` or `flows.amount`.

## Libraries

| Module | Use |
| --- | --- |
| `lib.client` | `Client.new({ admin = key })` returns a client or `nil, reason`. `c:call(name, params, { admin = bool, timeout = s })` returns the response table. `c:open_broadcast()` and `c:wait_broadcast(timeout)` receive the public stats push. |
| `lib.cfg` | `cfg.load()`, `cfg.read_key("server.secret")`, `cfg.read_key("admin.key")`, `cfg.role()`. |
| `lib.util` | `money`, `parse_money`, `ellipsis`, `lpad`, `rpad`, `duration`, `date`, `clock`, `count`, `trim`, `read_file`, `write_atomic`. |
| `lib.ser` | `ser.encode(v)` and `ser.decode(s)` for one-line table files. |

## Screen toolkit

`ui.app` owns a monitor or the terminal and an event loop. Screens are plain blocking functions.

```lua
local App = require("ui.app")
local kit = require("ui.kit")
local flows = require("ui.flows")
local theme = require("ui.theme")

local mon = peripheral.find("monitor")
local app = App.new({ surface = mon, name = peripheral.getName(mon), idle = 60 })

local function draw(s)
  kit.header(s, "Home", "Touch a card")
  kit.grid(s, 2, 6, s.w - 2, s.h - 8, 2, {
    { label = "SIGN IN", id = "signin", kind = "primary", sub = "Use your PIN" },
    { label = "OPEN ACCOUNT", id = "open", kind = "success" },
  })
  kit.footer(s, "VRB", os.date("%H:%M"))
end

app:show(draw)
while true do
  local kind, r = app:wait()
  if kind == "tap" then handle(r.id, r.data)
  elseif kind == "timeout" then ... end
end
```

- `App.new{ surface, name, idle, min_w, min_h }`. For a monitor pass its peripheral name in `name` so touches from other monitors are ignored. Omit `surface` to use the terminal. The text scale is chosen to fit `min_w` by `min_h` (default 51 by 19).
- `app:show(draw_fn)` makes `draw_fn(s, app)` the current screen and renders it. `app:refresh()` redraws the current screen after state changes. `app:notify(text, "ok"|"error"|"warn"|"info", seconds)` shows a toast.
- `app:wait(opts)` returns one of: `"tap", region` (region has `id` and `data`), `"key", name`, `"char", c`, `"paste", text`, `"scroll", dir`, `"timeout"`, `"event", name, ...` for names listed in `opts.events`. `opts.timeout` overrides `idle`.
- Terminal mouse clicks become `"tap"` too, so the same screen works on a computer terminal and on a pocket computer.
- `s` is a `ui.screen` buffer: `s:text(x, y, str, fg, bg)`, `s:fill(x, y, w, h, bg)`, `s:region(x, y, w, h, id, data)`, `s.w`, `s.h`. The renderer sends only changed rows.

`ui.kit` helpers: `header`, `footer`, `button` (kinds `primary`, `secondary`, `danger`, `success`, `ghost`, `panel`; options `h`, `sub`, `disabled`, `active`, `data`), `grid`, `card`, `kv`, `money`, `list` and `scroll` (scrolling rows with `left`, `right`, `id`, `data`, `color`), `empty`, `center`, `hline`, `progress`, `wrap`.

`ui.flows` blocking prompts, each returns `nil` when cancelled:

- `flows.pin(app, title)` returns four digits.
- `flows.amount(app, title, { limit = cents, quick = { 500, 1000 } })` returns cents.
- `flows.number(app, title, { max = digits })` returns a digit string.
- `flows.text(app, { title, label, max, allowed = "^[%w_]$", initial })` on-screen keyboard plus physical keyboard.
- `flows.confirm(app, title, lines, { yes, no, danger })` returns a boolean.
- `flows.message(app, title, lines, "ok"|"error"|"warn")`.
- `flows.choose(app, title, { { label, id, sub, kind } }, { h })` returns the chosen id.
- `flows.pick_list(app, title, rows, { empty, hint, action_label })` returns the row id and data, or `"action"`.

After a flow returns, call `app:show(...)` again to bring your own screen back.

## Testing

Tests run the program inside a headless CC:Tweaked model (`tests/cc.lua`). Read `tests/test_ui.lua` for driving a monitor with touches and `tests/test_server.lua` for a server plus client. `tests/net.lua` has `N.world()` (boots a server computer), `N.client_pc(world, id, files, { monitors = { { w = 57, h = 38, scale = 0.5 } } })` and `N.run_client(world, pc, fn)`.

Run one test:

```
python -I tests/run.py tests/test_<name>.lua
```

Dump a screen with `monitor._dump()` (text only) to check the layout at several sizes. In `monitors = { { w, h } }` the numbers are the character size at text scale 0.5. Try a large 3 by 3 monitor (`w = 57, h = 38`), a small 2 by 1 monitor (`w = 29, h = 19`), the 51 by 19 terminal and a 26 by 20 pocket computer (`w = 26, h = 20` on the computer itself).
