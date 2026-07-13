-- buzz_motion.lua — バズの飛び方3つ（骨格版）
--
-- 3つの動き:
--   burst_takeoff : 垂直に急上昇（ベッドから飛び立つやつ）
--   room_loop     : 部屋をぐるっと一周（今は四角く回る。傾き旋回は本実装で）
--   swoop_land    : 前に滑り込みながら降りて、ゆっくり着地
--
-- 動かし方（地上局から）:
--   GUIDEDモードでarmしたあと、SCR_USER1 という数字を変えると動く
--     SCR_USER1 = 1 → burst_takeoff
--     SCR_USER1 = 2 → room_loop
--     SCR_USER1 = 3 → swoop_land
--
-- 安全ルール（CLAUDE.mdの約束）:
--   人がスティックを動かす・モードを変える・disarmする → 即座に手を引いてIDLEに戻る
--   このスクリプトは自分からarmしない（armは必ず人がやる）

-- ==== いじって遊べる数字（すべてメートル）====================
local ROOM_X    = 4.0  -- TODO(実測待ち): 部屋の奥行き
local ROOM_Y    = 3.0  -- TODO(実測待ち): 部屋の幅
local MARGIN    = 0.8  -- 壁からどれだけ離れるか
local BURST_ALT = 2.0  -- TODO(実測待ち): 急上昇の高さ（天井に合わせる）
local SWOOP_ALT = 0.8  -- 着地前にここまで滑り込む高さ
local BANK_ANGLE = 20  -- TODO: 骨格では未使用。本実装で旋回の傾き(度)に使う
-- ============================================================

local MODE_GUIDED = 4
local MODE_LAND   = 9
local WP_RADIUS   = 0.6   -- 「目標に着いた」とみなす距離(m)
local RC_DEADZONE = 150   -- スティック検知のあそび(PWM)

local state = "IDLE"
local wps = {}       -- room_loop のウェイポイント一覧
local wp_i = 0

local function say(msg)
  gcs:send_text(6, "BUZZ: " .. msg)
end

-- 人がスティック（ロール/ピッチ/ヨー）を動かしたか
local function pilot_moved_stick()
  for _, ch in ipairs({1, 2, 4}) do
    local pwm = rc:get_pwm(ch)
    if pwm and pwm > 900 and math.abs(pwm - 1500) > RC_DEADZONE then
      return true
    end
  end
  return false
end

-- 高さ（離陸地点から何m上か）
local function height_m()
  local pos = ahrs:get_relative_position_NED_home()
  if pos then return -pos:z() end
  return nil
end

-- 今いる場所から部屋の四隅ウェイポイントを作る（自分＝部屋の中心と仮定）
local function build_room_wps()
  local here = ahrs:get_location()
  if not here then return false end
  local dx = ROOM_X / 2 - MARGIN
  local dy = ROOM_Y / 2 - MARGIN
  wps = {}
  local corners = { {dx, dy}, {dx, -dy}, {-dx, -dy}, {-dx, dy}, {0, 0} }
  for _, c in ipairs(corners) do
    local wp = here:copy()
    wp:offset(c[1], c[2])
    table.insert(wps, wp)
  end
  wp_i = 0
  return true
end

local function next_wp()
  wp_i = wp_i + 1
  if wp_i > #wps then return false end
  vehicle:set_target_location(wps[wp_i])
  say(string.format("room_loop wp %d/%d", wp_i, #wps))
  return true
end

-- 目標地点まであと何m（横方向）
local function dist_to_wp()
  local here = ahrs:get_location()
  if not here or wp_i < 1 or wp_i > #wps then return nil end
  return here:get_distance(wps[wp_i])
end

local function abort_to_idle(reason)
  state = "IDLE"
  say("STOP (" .. reason .. ") -> hands off, pilot has control")
end

function update()
  -- 安全チェック: 動作中に人が介入したら即座に手を引く
  if state ~= "IDLE" and state ~= "LANDING" then
    if pilot_moved_stick() then abort_to_idle("stick input") return update, 100 end
    if vehicle:get_mode() ~= MODE_GUIDED then abort_to_idle("mode change") return update, 100 end
    if not arming:is_armed() then abort_to_idle("disarmed") return update, 100 end
  end
  if state == "LANDING" and pilot_moved_stick() then
    abort_to_idle("stick input")
    return update, 100
  end

  -- 地上局からの指示（SCR_USER1）を読む
  local cmd = param:get('SCR_USER1')
  cmd = cmd and math.floor(cmd) or 0
  if cmd ~= 0 then
    param:set('SCR_USER1', 0)  -- 一回読んだらリセット（ボタンのように使う）
    if state ~= "IDLE" then
      say("busy (" .. state .. "), command ignored")
    elseif vehicle:get_mode() ~= MODE_GUIDED or not arming:is_armed() then
      say("need GUIDED + armed first")
    elseif cmd == 1 then
      if vehicle:start_takeoff(BURST_ALT) then
        state = "TAKEOFF"
        say(string.format("burst_takeoff -> %.1fm", BURST_ALT))
      else
        say("takeoff refused")
      end
    elseif cmd == 2 then
      if build_room_wps() and next_wp() then
        state = "LOOP"
        say("room_loop start")
      end
    elseif cmd == 3 then
      local here = ahrs:get_location()
      local h = height_m()
      if here and h then
        local wp = here:copy()
        wp:offset(ROOM_X / 2 - MARGIN, 0)          -- 前方へ滑り込む
        wp:alt(wp:alt() - math.floor((h - SWOOP_ALT) * 100))  -- alt はcm単位
        vehicle:set_target_location(wp)
        state = "SWOOP"
        say("swoop_land start")
      end
    end
  end

  -- 各動きの進行チェック
  if state == "TAKEOFF" then
    local h = height_m()
    if h and h >= BURST_ALT - 0.3 then
      state = "IDLE"
      say("burst_takeoff done")
    end
  elseif state == "LOOP" then
    local d = dist_to_wp()
    if d and d < WP_RADIUS then
      if not next_wp() then
        state = "IDLE"
        say("room_loop done")
      end
    end
  elseif state == "SWOOP" then
    -- 滑り込みで高度が下がりきったら着陸モードへ
    local h = height_m()
    if h and h <= SWOOP_ALT + 0.3 then
      vehicle:set_mode(MODE_LAND)
      state = "LANDING"
      say("swoop_land: LAND")
    end
  elseif state == "LANDING" then
    if not arming:is_armed() then
      state = "IDLE"
      say("swoop_land done (disarmed)")
    end
  end

  return update, 100  -- 0.1秒ごとに繰り返す
end

-- 起動時: 押しっぱなしのボタンが残っていても無視する
param:set('SCR_USER1', 0)
say("motion script ready (1=takeoff 2=loop 3=land)")

return update()
