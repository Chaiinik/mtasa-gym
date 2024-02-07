local fps = 0
local frames = 0
local nextTick = 0

local function updateFPS(msSinceLastFrame)
    local now = getTickCount()
    if (now >= nextTick) then
        fps = (1 / msSinceLastFrame) * 1000
        nextTick = now + 1000
    end
end
addEventHandler("onClientPreRender", root, updateFPS)

local function updateFPS(msSinceLastFrame)
    frames = frames + 1
    local now = getTickCount()
    if (now >= nextTick) then
        fps = frames
        frames = 0
        nextTick = now + 1000
    end
end
--addEventHandler("onClientPreRender", root, updateFPS)

local sx = guiGetScreenSize()
local function drawFPS()
    local roundedFPS = math.floor(fps+0.1)
    dxDrawText(roundedFPS, sx - dxGetTextWidth(roundedFPS), 0)
end
addEventHandler("onClientHUDRender", root, drawFPS)