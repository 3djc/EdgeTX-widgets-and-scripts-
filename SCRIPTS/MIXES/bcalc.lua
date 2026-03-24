
-- input below the name of your total lipo voltage sensor
local myBatSensorName = "RxBt"

-- input below the name of the percentage sensor you want created
local myBatPercentName = "BatP"

local outputs = { "BatP" }

-- No changes needed below
-- Percentage table extracted from Robbe lipo tester. Only suitable for LIPO type batteries
local myArrayPercentList =
{{3, 0}, {3.093, 1}, {3.196, 2}, {3.301, 3}, {3.401, 4}, {3.477, 5}, {3.544, 6}, {3.601, 7}, {3.637, 8}, {3.664, 9}, {3.679, 10}, {3.683, 11}, {3.689, 12}, {3.692, 13}, {3.705, 14}, {3.71, 15}, {3.713, 16}, {3.715, 17}, {3.72, 18}, {3.731, 19}, {3.735, 20}, {3.744, 21}, {3.753, 22}, {3.756, 23}, {3.758, 24}, {3.762, 25}, {3.767, 26}, {3.774, 27}, {3.78, 28}, {3.783, 29}, {3.786, 30}, {3.789, 31}, {3.794, 32}, {3.797, 33}, {3.8, 34}, {3.802, 35}, {3.805, 36}, {3.808, 37}, {3.811, 38}, {3.815, 39}, {3.818, 40}, {3.822, 41}, {3.825, 42}, {3.829, 43}, {3.833, 44}, {3.836, 45}, {3.84, 46}, {3.843, 47}, {3.847, 48}, {3.85, 49}, {3.854, 50}, {3.857, 51}, {3.86, 52}, {3.863, 53}, {3.866, 54}, {3.87, 55}, {3.874, 56}, {3.879, 57}, {3.888, 58}, {3.893, 59}, {3.897, 60}, {3.902, 61}, {3.906, 62}, {3.911, 63}, {3.918, 64}, {3.923, 65}, {3.928, 66}, {3.939, 67}, {3.943, 68}, {3.949, 69}, {3.955, 70}, {3.961, 71}, {3.968, 72}, {3.974, 73}, {3.981, 74}, {3.987, 75}, {3.994, 76}, {4.001, 77}, {4.007, 78}, {4.014, 79}, {4.021, 80}, {4.029, 81}, {4.036, 82}, {4.044, 83}, {4.052, 84}, {4.062, 85}, {4.074, 86}, {4.085, 87}, {4.095, 88}, {4.105, 89}, {4.111, 90}, {4.116, 91}, {4.12, 92}, {4.125, 93}, {4.129, 94}, {4.135, 95}, {4.145, 96}, {4.176, 97}, {4.179, 98}, {4.193, 99}, {4.2, 100}}

local function percentcell(targetVoltage)
  if targetVoltage >= 4.2 then return 100 end
  local result = 0
  for _, v in ipairs(myArrayPercentList) do
    if v[1] >= targetVoltage then
      result = v[2]
      break
    end
  end
  return result
end

local function run()
  local myvoltage = getValue(myBatSensorName)
  if myvoltage == 0 then
    setTelemetryValue(0x0310, 0, 1, 0, 13, 0, myBatPercentName)
    return 0
  end
  local cellCount = math.ceil(myvoltage / 4.25)
  local cellPercent = percentcell(myvoltage / cellCount)
  setTelemetryValue(0x0310, 0, 1, cellPercent, 13, 0, myBatPercentName)
  return cellPercent * 10.24  -- maps 0-100% to 0-1024 (EdgeTX mix range)
end

return { run=run, outputs=outputs }
