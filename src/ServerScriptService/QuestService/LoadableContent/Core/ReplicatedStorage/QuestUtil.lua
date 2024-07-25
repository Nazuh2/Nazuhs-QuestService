-- Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- Imports
local Util = {}

function Util.GetQuestTemplate()
	return {
		Id = 'Unknown',
		DisplayName = 'Unknown',
		Description = 'Unknown'
	}
end

return Util