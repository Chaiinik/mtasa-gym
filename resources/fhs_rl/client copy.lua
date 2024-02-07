outputDebugString("Loaded client.lua")

local function drawLineOfSight(startPos, endPos, ignoreElement)
    local hit, x, y, z, element = processLineOfSight(startPos, endPos, true, true, true, true, true, false, false, false, ignoreElement)
    if false then
        if hit then
            -- scale color by distance (from green, far away, to red, close)
            local distance = getDistanceBetweenPoints3D(startPos, Vector3(x, y, z))
            local r = 255 - distance * 255 / 100
            local g = distance * 255 / 100
            local b = 0
            dxDrawLine3D(startPos, Vector3(x, y, z), tocolor(r, g, b))
            --dxDrawLine3D(Vector3(x, y, z), endPos, tocolor(0, 255, 0))
        else
            dxDrawLine3D(startPos, endPos, tocolor(0, 255, 0))
        end

        -- draw distance at 1m after startpos
        local distance = nil
        if hit then
            distance = getDistanceBetweenPoints3D(startPos, Vector3(x, y, z))
        else
            distance = getDistanceBetweenPoints3D(startPos, endPos)
        end
        local textPos = startPos + (endPos - startPos):getNormalized() * 3
        local sx, sy = getScreenFromWorldPosition(textPos.x, textPos.y, textPos.z)
        if sx and sy then
            dxDrawText(string.format("%.2fm", distance), sx, sy)
        end
    end
end


-- precalculate the matrix

local function renderStuff()
    -- draw line of sight
    if localPlayer.vehicle then
        local scale = 100
        if false then
            local min, max = localPlayer.vehicle:getBoundingBox()
            local wheel_rb = localPlayer.vehicle:getComponentPosition("wheel_rb_dummy", "world") + Vector3(0, 0, 0.5)
            local wheel_lb = localPlayer.vehicle:getComponentPosition("wheel_lb_dummy", "world") + Vector3(0, 0, 0.5)
            local wheel_rf = localPlayer.vehicle:getComponentPosition("wheel_rf_dummy", "world") + Vector3(0, 0, 0.5)
            local wheel_lf = localPlayer.vehicle:getComponentPosition("wheel_lf_dummy", "world") + Vector3(0, 0, 0.5)

            -- front left forward
            drawLineOfSight(wheel_lf, wheel_lf + localPlayer.vehicle.matrix.forward * scale, localPlayer.vehicle)
            -- front left left
            drawLineOfSight(wheel_lf, wheel_lf - localPlayer.vehicle.matrix.right * scale, localPlayer.vehicle)
            -- front left corner
            drawLineOfSight(wheel_lf, wheel_lf + localPlayer.vehicle.matrix.forward * scale - localPlayer.vehicle.matrix.right * scale, localPlayer.vehicle)

            -- front right forward
            drawLineOfSight(wheel_rf, wheel_rf + localPlayer.vehicle.matrix.forward * scale, localPlayer.vehicle)
            -- front right right
            drawLineOfSight(wheel_rf, wheel_rf + localPlayer.vehicle.matrix.right * scale, localPlayer.vehicle)
            -- front right corner
            drawLineOfSight(wheel_rf, wheel_rf + localPlayer.vehicle.matrix.forward * scale + localPlayer.vehicle.matrix.right * scale, localPlayer.vehicle)
            -- back left backward
            drawLineOfSight(wheel_lb, wheel_lb - localPlayer.vehicle.matrix.forward * scale, localPlayer.vehicle)
            -- back left left
            drawLineOfSight(wheel_lb, wheel_lb - localPlayer.vehicle.matrix.right * scale, localPlayer.vehicle)
            -- back left corner
            drawLineOfSight(wheel_lb, wheel_lb - localPlayer.vehicle.matrix.forward * scale - localPlayer.vehicle.matrix.right * scale, localPlayer.vehicle)
            -- back right backward
            drawLineOfSight(wheel_rb, wheel_rb - localPlayer.vehicle.matrix.forward * scale, localPlayer.vehicle)
            -- back right right
            drawLineOfSight(wheel_rb, wheel_rb + localPlayer.vehicle.matrix.right * scale, localPlayer.vehicle)
            -- back right corner
            drawLineOfSight(wheel_rb, wheel_rb - localPlayer.vehicle.matrix.forward * scale + localPlayer.vehicle.matrix.right * scale, localPlayer.vehicle)
        else
            local pos = localPlayer.vehicle.position --+ localPlayer.vehicle.velocity*2
            local matrix = localPlayer.vehicle.matrix
            for i = 0, 360, 1 do
                for z = -10, 10, 5 do
                    local x = math.cos(math.rad(i)) * scale
                    local y = math.sin(math.rad(i)) * scale
                    drawLineOfSight(pos, pos + matrix.forward * x + matrix.right * y + matrix.up * z, localPlayer.vehicle)
                end
            end

        end

        -- draw vehicle properties
        if false then
            local text = string.format("position: %.2f %.2f %.2f\n", localPlayer.vehicle.position.x, localPlayer.vehicle.position.y, localPlayer.vehicle.position.z)
            text = text .. string.format("rotation: %.2f %.2f %.2f\n", localPlayer.vehicle.rotation.x, localPlayer.vehicle.rotation.y, localPlayer.vehicle.rotation.z)
            text = text .. string.format("velocity: %.2f %.2f %.2f\n", localPlayer.vehicle.velocity.x, localPlayer.vehicle.velocity.y, localPlayer.vehicle.velocity.z)
            -- use pythagorean theorem to get actual velocity
            local speed = math.sqrt(localPlayer.vehicle.velocity.x^2 + localPlayer.vehicle.velocity.y^2 + localPlayer.vehicle.velocity.z^2)
            -- multiply by 50 to obtain the speed in metres per second
            local speed_kmh = speed * 180
            text = text .. string.format("speed: %.2f km/h\n", speed_kmh)
            -- wheels (0: front left, 1: rear left, 2: front right, 3: rear right)
            --text = text .. string.format("wheel friction: %d %d %d %d\n", localPlayer.vehicle:getWheelFrictionState(0), localPlayer.vehicle:getWheelFrictionState(1), localPlayer.vehicle:getWheelFrictionState(2), localPlayer.vehicle:getWheelFrictionState(3))
            dxDrawText(text, 200, 100)
        end
    else
        local scale = 10
        -- add offset based on velocity
        local offset = localPlayer.velocity*2
        drawLineOfSight(localPlayer.position+offset, localPlayer.position + localPlayer.matrix.forward * scale)
        drawLineOfSight(localPlayer.position+offset, localPlayer.position - localPlayer.matrix.forward * scale)
        drawLineOfSight(localPlayer.position+offset, localPlayer.position + localPlayer.matrix.right * scale)
        drawLineOfSight(localPlayer.position+offset, localPlayer.position - localPlayer.matrix.right * scale)
        drawLineOfSight(localPlayer.position+offset, localPlayer.position + localPlayer.matrix.up * scale)
        drawLineOfSight(localPlayer.position+offset, localPlayer.position - localPlayer.matrix.up * scale)

        drawLineOfSight(localPlayer.position+offset, localPlayer.position + localPlayer.matrix.forward * scale + localPlayer.matrix.right * scale)
        drawLineOfSight(localPlayer.position+offset, localPlayer.position + localPlayer.matrix.forward * scale - localPlayer.matrix.right * scale)
        drawLineOfSight(localPlayer.position+offset, localPlayer.position - localPlayer.matrix.forward * scale + localPlayer.matrix.right * scale)
        drawLineOfSight(localPlayer.position+offset, localPlayer.position - localPlayer.matrix.forward * scale - localPlayer.matrix.right * scale)
    end
end
addEventHandler("onClientRender", root, renderStuff)