-- LegendRegistry: a tiny list of every legend currently alive in the world.
-- Traps use it to ask "is this part I just hit part of a legend?" and
-- "where are the legends right now?".

local LegendRegistry = {}

local legendsByModel = {} -- [Model] = legend object (for example a Mossback)

function LegendRegistry.register(model: Model, legend)
	legendsByModel[model] = legend
	model.Destroying:Connect(function()
		legendsByModel[model] = nil
	end)
end

-- Returns the table of [Model] = legend. Don't change it, just read it.
function LegendRegistry.getAll()
	return legendsByModel
end

-- Given any part, returns the legend it belongs to (or nil).
function LegendRegistry.fromPart(part: Instance)
	for model, legend in legendsByModel do
		if part:IsDescendantOf(model) then
			return legend
		end
	end
	return nil
end

return LegendRegistry
