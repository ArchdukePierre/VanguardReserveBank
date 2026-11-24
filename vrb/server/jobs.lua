local util = require("lib.util")

local Jobs = {}

function Jobs.new(log)
  local self = { list = {}, by_name = {} }

  function self.add(name, every, fn)
    local j = { name = name, every = every, next_at = util.now() + math.min(every, 10), fn = fn, runs = 0, last_ms = 0, err = nil, force = false }
    self.list[#self.list + 1] = j
    self.by_name[name] = j
  end

  function self.run_now(name)
    local j = self.by_name[name]
    if j then j.force = true end
  end

  function self.next_delay()
    local t = util.now()
    local best = 3600
    for _, j in ipairs(self.list) do
      if j.force then return 0 end
      local d = j.next_at - t
      if d < best then best = d end
    end
    return math.max(0, best)
  end

  function self.tick(step)
    local t = util.now()
    local ran = false
    for _, j in ipairs(self.list) do
      if j.force or t >= j.next_at then
        j.force = false
        local t0 = util.ms()
        local ok, err = pcall(j.fn, step)
        j.last_ms = util.ms() - t0
        j.runs = j.runs + 1
        j.next_at = util.now() + j.every
        if not ok then
          j.err = tostring(err)
          if log then log("job " .. j.name .. " failed: " .. tostring(err)) end
        else
          j.err = nil
        end
        ran = true
        if step then step() end
      end
    end
    return ran
  end

  function self.status()
    local out = {}
    for _, j in ipairs(self.list) do out[#out + 1] = { name = j.name, runs = j.runs, last_ms = j.last_ms, err = j.err } end
    return out
  end

  return self
end

return Jobs
