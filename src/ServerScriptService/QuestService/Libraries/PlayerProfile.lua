-- Imports
local ReplicaService = require(game:GetService('ServerScriptService').ReplicaService)
local Signal = require(script.Parent.Signal)
local ProfileToken = ReplicaService.NewClassToken('PlayerQuests')

local PlayerProfile = {}
PlayerProfilePrototype = {}
PlayerProfilePrototype.__index = PlayerProfilePrototype
export type PlayerProfile = {
	Player: Player,
	Replica: any,
	
	QuestStarted: { Connect: (Quest: { Id: string, CurrentValue: number }) -> () },
	QuestRemoved: { Connect: (Quest: { Id: string, CurrentValue: number }) -> () },
	QuestUpdated: { Connect: (Quest: { Id: string, CurrentValue: number }) -> () },
} & typeof(PlayerProfilePrototype)

function PlayerProfile.new(Player: Player, ObtainedQuests: { any })
	return setmetatable({
		Player = Player,
		Replica = ReplicaService.NewReplica({
			ClassToken = ProfileToken,
			Tags = { Player = Player },
			Data = { Quests = table.clone(ObtainedQuests) },
			Replication = 'All'
		}),
		
		QuestStarted = Signal.new(),
		QuestRemoved = Signal.new(),
		QuestUpdated = Signal.new()
	}, PlayerProfilePrototype)
end

function PlayerProfilePrototype:Destroy()
	self.Replica:Destroy()
	
	self.QuestStarted:DisconnectAll()
	self.QuestRemoved:DisconnectAll()
	self.QuestUpdated:DisconnectAll()
	
	setmetatable(self, nil)
	self = nil
end

function PlayerProfilePrototype:AddQuest(QuestId: string, InitialAmount: number)
	local Quest = {
		Id = QuestId,
		CurrentValue = InitialAmount
	}
	
	self.Replica:SetValue(
		{ 'Quests' },
		{
			Quest,
			table.unpack(self.Replica.Data.Quests)
		}
	)
	
	self.QuestStarted:Fire(Quest)
end

function PlayerProfilePrototype:RemoveQuest(QuestId: string)
	local Quests = table.clone(self.Replica.Data.Quests)
	
	-- Find quest to remove given a questid
	for i, Quest in Quests do
		if Quest.Id == QuestId then
			self.QuestRemoved:Fire(Quest)
			table.remove(Quests, i)
			break
		end
	end
	
	self.Replica:SetValue({ 'Quests' }, Quests)
end

function PlayerProfilePrototype:HasQuest(QuestId: string)
	for _, Quest in self.Replica.Data.Quests do
		if Quest.Id == QuestId then
			return true
		end
	end
	
	return false
end

function PlayerProfilePrototype:UpdateQuest(QuestId: string, NewAmount: number)
	local Quests = table.clone(self.Replica.Data.Quests)

	-- Find quest to remove given a questid
	local IsSuccess = false
	for i, Quest in Quests do
		if Quest.Id ~= QuestId then
			continue
		end
		
		IsSuccess = true
		Quest.CurrentValue = math.max(0, NewAmount)
		
		self.QuestUpdated:Fire(Quest)
	end
	
	if not IsSuccess then
		return
	end
	
	self.Replica:SetValue({ 'Quests' }, Quests)
end

function PlayerProfilePrototype:GetQuest(QuestId: string)
	for _, Quest in self.Replica.Data.Quests do
		if Quest.Id ~= QuestId then
			continue
		end
		
		return table.clone(Quest)
	end
end

function PlayerProfilePrototype:GetQuests()
	return table.clone(self.Replica.Data.Quests)
end

return PlayerProfile