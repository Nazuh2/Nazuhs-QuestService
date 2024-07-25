<div align="center"><h1 style="text-align: right;">Nazuh's QuestService</h1></div>
<hr>

<div align='center'>
Nazuh's QuestService is a versatile easy to use event based Quest System. I originally made this for a commission, but I modified it a bit to release it as an open source resource, so enjoy 😁. 

Special thanks to these awesome developers for making this OS resource possible:
@stravant- [GoodSignal](https://devforum.roblox.com/t/lua-signal-class-comparison-optimal-goodsignal-class/1387063)
@loleris - [ReplicaService](https://devforum.roblox.com/t/replicate-your-states-with-replicaservice-networking-system/894736)
</div>

<div align="center"><h1>Links</h1>
<hr>
<h5>
 
RBXM File: [Link](https://github.com/Nazuh2/Nazuhs-QuestService/releases/latest/download/QuestService.rbxm)

Github Repo: [Link](https://github.com/Nazuh2/Nazuhs-QuestService)

NOTE:
I most likely won't be providing a creator store link to this resource due to the bad experience
I've had with asset moderation in the past.
</div>

<br><hr>

<div align="center"><h1>Setup
</h1>
Below is an extremely basic implementation of QuestService.
</div>

<div align="center">
<h4>ReplicatedStorage.Quests:</h4>
</div>

```lua
return {
	{
		-- These two values are required
		Id = 'TestQuest',
		MaxValue = 10,
		
		-- These two values have default values of 'Unknown'.
		-- You can edit the default values specific to your
		-- game in QuestService.LoadableContent.Core.ReplicatedStorage.QuestUtil.
		DisplayName = 'Defeat Zombies',
		Description = 'Defeat 10 Zombies!',
		
		ReallyCustomQuestValueSpecificToYourGame = 'totally possible!',
		
		-- Events for Everything 😃
		CompletedCallback = function(Player: Player)
			print('Completed')
		end,
		IncrementCallback = function(Player: Player, NewAmount: number)
			print('Incremented')
		end,
		DecrementCallback = function(Player: Player, NewAmount: number)
			print('Decremented')
		end,
		QuestStartedCallback = function(Player: Player)
			print('Started')
		end,
		QuestRemovedCallback = function(Player: Player)
			print('Removed')
		end
	}
}
```

<div align="center"><h4>Server:</h4></div>

```lua
-- Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local PlayerService = game:GetService('Players')

-- Imports
local QuestService = require(script.QuestService)

-- Local Functions
local function PlayerAdded(Player: Player)
	local QuestProfile = QuestService:InitializePlayer(Player, { }) -- Pass already obtained quests here
	
	QuestProfile.QuestStarted:Connect(function(QuestInstance)
		print(Player.DisplayName, 'Started Quest:', QuestInstance.Id)
		
		-- Update data in datastore
		-- ...
	end)
	
	QuestProfile.QuestRemoved:Connect(function(QuestInstance)
		print(Player.DisplayName, 'Ended Quest:', QuestInstance.Id)
		
		-- Update data in datastore
		-- ...
	end)
	
	QuestProfile.QuestUpdated:Connect(function(QuestInstance)
		print(Player.DisplayName, 'Progressed Quest:', QuestInstance.Id)
		
		-- Update data in datastore
		-- ...
	end)
	
	QuestService:AddQuestToPlayer(Player, 'TestQuest')
end

-- Runtime

-- Startup the quest service
QuestService:Init()

-- Load your base quests into the quest service
QuestService:RegisterModule(ReplicatedStorage.Quests, true)

PlayerService.PlayerAdded:Connect(PlayerAdded)
for _, Player in PlayerService:GetPlayers() do
	task.spawn(PlayerAdded, Player)
end
```

<div align="center">
<h4>Client:</h4>
</div>

```lua
-- Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local PlayerService = game:GetService('Players')

-- Imports
--- Quest Controller is automatically loaded into replicated storage, but if you want
--- type hints you can move it there before runtime.
local QuestController = require(ReplicatedStorage:WaitForChild('QuestController'))

-- Runtime
QuestController.QuestsLoaded:Connect(function(QuestInstances)
	print('Quests Loaded', QuestInstances)
	
	for _, Quest in QuestInstances do
		-- The Base Quests are what you previously loaded into
		-- the quest controller.
		local BaseQuest = QuestController:GetBaseQuest(Quest.Id)
		
		-- ...
	end
	-- ...
end)

QuestController.QuestStarted:Connect(function(QuestInstance)
	print('Quest Started', QuestInstance)
	
	-- ...
end)

QuestController.QuestRemoved:Connect(function(QuestInstance)
	print('Quest Removed', QuestInstance)
	
	-- ...
end)

QuestController.QuestUpdated:Connect(function(QuestInstance)
	print('Quest Updated', QuestInstance)
	
	-- ...
end)

-- Startup the QuestController
QuestController:Init()

-- Load your base quests into the quest controller
QuestController:RegisterModule(ReplicatedStorage:WaitForChild('Quests'))
```
