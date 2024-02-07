local floor = math.floor

local function getAreaID(x, y)
	return floor((y + 3000)/750)*8 + floor((x + 3000)/750)
end

local function getNodeByID(db, nodeID)
	local areaID = floor(nodeID / 65536)
	return db[areaID][nodeID]
end

local function findNodeClosestToPoint(db, x, y, z)
	local areaID = getAreaID(x, y)
	local minDist, minNode
	local nodeX, nodeY, dist
	for id,node in pairs(db[areaID]) do
		nodeX, nodeY = node.x, node.y
		dist = (x - nodeX)*(x - nodeX) + (y - nodeY)*(y - nodeY)
		if not minDist or dist < minDist then
			minDist = dist
			minNode = node
		end
	end
	return minNode
end

local function calculatePath(db, nodeFrom, nodeTo)
	local next = next

	local g = { [nodeFrom] = 0 }		-- { node = g }
	local hcache = {}					-- { node = h }
	local parent = {}					-- { node = parent }
	local openheap = MinHeap.new()

	local function h(node)
		if hcache[node] then
			return hcache[node]
		end
		local x, y, z = node.x - nodeTo.x, node.y - nodeTo.y, node.z - nodeTo.z
		hcache[node] = x*x + y*y + z*z
		return hcache[node]
	end
	local nodeMT = {
		__lt = function(a, b)
			return g[a] + h(a) <  g[b] + h(b)
		end,
		__le = function(a, b)
			if not g[a] or not g[b] then
				outputConsole(debug.traceback())
			end
			return g[a] + h(a) <= g[b] + h(b)
		end
	}
	setmetatable(nodeFrom, nodeMT)
	openheap:insertvalue(nodeFrom)

	local current
	while not openheap:empty() do
		current = openheap:deleteindex(0)
		if current == nodeTo then
			break
		end

		local successors = {}
		for id,distance in pairs(current.neighbours) do
			local successor = getNodeByID(db, id)
			local successor_g = g[current] + distance*distance
			if not g[successor] or g[successor] > successor_g then
				setmetatable(successor, nodeMT)

				g[successor] = successor_g
				openheap:insertvalue(successor)
				parent[successor] = current
			end
		end
	end

	if current == nodeTo then
		local path = {}
		repeat
			table.insert(path, 1, current)
			current = parent[current]
		until not current
		return path
	else
		return false
	end
end

function calculatePathByCoords(x1, y1, z1, x2, y2, z2)
	return calculatePath(vehicleNodes, findNodeClosestToPoint(vehicleNodes, x1, y1, z1), findNodeClosestToPoint(vehicleNodes, x2, y2, z2))
end

function calculatePathByNodeIDs(node1, node2)
	node1 = getNodeByID(vehicleNodes, node1)
	node2 = getNodeByID(vehicleNodes, node2)
	if node1 and node2 then
		return calculatePath(vehicleNodes, node1, node2)
	else
		return false
	end
end

destination = Vector3(313.69269, -237.22072, 1.57812)

function createColShapes(element)
	local x, y, z = getElementPosition(element)
    local path = calculatePathByCoords(x, y, z, destination.x, destination.y, destination.z)
    for i,node in ipairs(path) do
        local shape = createColSphere(node.x, node.y, node.z, 5)
        setElementData(shape, "reward", 100)
    end

    -- create shape at target
    local shape = createColSphere(destination.x, destination.y, destination.z, 5)
    setElementData(shape, "reward", 10000)

	-- destroy nearest checkpoint
    local nearestCheckpoint = nil
    local nearestDistance = nil
    for i, shape in ipairs(getElementsByType("colshape")) do
        local cx, cy, cz = getElementPosition(shape)
        local distance = getDistanceBetweenPoints3D(x, y, z, cx, cy, cz)
        if (nearestDistance == nil or distance < nearestDistance) then
            nearestCheckpoint = shape
            nearestDistance = distance
        end
	end
	if (nearestCheckpoint ~= nil) then
		outputDebugString("destroying nearest checkpoint")
		destroyElement(nearestCheckpoint)
	end
end

function destroyColShapes()
    for i, shape in ipairs(getElementsByType("colshape")) do
        destroyElement(shape)
    end
end

function getNearestCheckpoint(element)
    local x, y, z = getElementPosition(element)
    local nearestCheckpoint = nil
    local nearestDistance = nil
    for i, shape in ipairs(getElementsByType("colshape")) do
        local cx, cy, cz = getElementPosition(shape)
        local distance = getDistanceBetweenPoints3D(x, y, z, cx, cy, cz)
        if (nearestDistance == nil or distance < nearestDistance) then
            nearestCheckpoint = shape
            nearestDistance = distance
        end
    end

	if (nearestCheckpoint == nil) then
		return Vector3(0, 0, 0)
	end
    return Vector3(getElementPosition(nearestCheckpoint))
end