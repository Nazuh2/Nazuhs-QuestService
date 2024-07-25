--[[
	Handles communicating with datastores to update and store
	player quest data. Also sets up QuestService
]]

-- Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')
local PlayerService = game:GetService('Players')

-- Imports
local DataReconciler = nil -- require on init as it needs to be under replicated storage so the client has access to it
local PlayerProfile = nil -- require on init as it needs replicaservice to be under serverscriptservice

-- Local Variables
local IsInitialized = false

-- QuestService Initialization
local QuestService = {
	-- CONSTANT - Changing these variables midgame will have no effect
	LoadReplicaService = true, -- disable if you already have replicaservice in your game
	
	-- DYNAMIC - changing these variables midgame will have an effect
	AllowQuestValuesToExceedMaxValues = false,
	AllowQuestValuesToDecrease = true,
	
	---- NOTE: These don't effect PlayerProfile Events. Only the callbacks defined inside the base quests
	DoIncrementCallbacks = true,
	DoDecrementCallbacks = true,
	DoCompletedCallbacks = true,
	DoStartedCallbacks = true,
	DoRemovedCallbacks = true,
	
	-- PRIVATE - These variables aren't meant to be user modified
	PlayerProfiles = {} :: { [Player]: PlayerProfile },
}

-- Types
type QuestService = typeof(QuestService)

export type BaseQuest = {
	Id: string,
	MaxValue: number,

	CompletedCallback: ((Player: Player) -> ())?, -- successfully finish quest
	IncrementCallback: ((Player: Player, NewAmount: number) -> ())?, -- Called when a quest's value increases
	DecrementCallback: ((Player: Player, NewAmount: number) -> ())?, -- Called when a quest's value decreases
	QuestStartedCallback: ((Player: Player) -> ())?, -- called when a player starts a quest
	QuestRemovedCallback: ((Player: Player) -> ())? -- called when a quest is removed from a player
}

export type QuestInstance = {
	Id: string,
	CurrentValue: number,
	IsCompleted: boolean
}

export type PlayerProfile = typeof(require(script.Libraries.PlayerProfile).new())

-- QuestService Functions & Methods
function QuestService.Init(self: QuestService): QuestService?
	if IsInitialized then
		return error('Attempted to reinitialize QuestService!')
	end
	IsInitialized = true
	
	if not self.LoadReplicaService and script.LoadableContent:FindFirstChild('ReplicaService') then
		script.LoadableContent.ReplicaService:Destroy()
	end
	
	-- Setup Loadable Content
	for _, Category in script.LoadableContent:GetChildren() do
		for _, Folder in Category:GetChildren() do
			local CorrespondingService = game:GetService(Folder.Name)
			if not CorrespondingService then
				continue
			end

			for _, Object in Folder:GetChildren() do
				Object.Parent = CorrespondingService
			end
		end
	end
	script.LoadableContent:Destroy()
	
	DataReconciler = require(ReplicatedStorage.DataReconciler)
	self.Reconciler = DataReconciler.init(
		{},
		nil,
		require(ReplicatedStorage.QuestUtil).GetQuestTemplate()
	)
	
	PlayerProfile = require(script.Libraries.PlayerProfile)
	
	-- Cleanup on player removing
	PlayerService.PlayerRemoving:Connect(function(Player)
		if not self.PlayerProfiles[Player] then
			return
		end
		
		self.PlayerProfiles[Player]:Destroy()
		self.PlayerProfiles[Player] = nil
	end)
	
	return QuestService
end

function QuestService.RegisterQuest(self: QuestService, QuestPrototype: BaseQuest)
	self.Reconciler:ReconcileData(QuestPrototype)
end

function QuestService.RegisterModule(self: QuestService, Module: ModuleScript, RegisterDescendants: boolean?)
	self.Reconciler:ReconcileModule(Module)
	
	if RegisterDescendants then
		self.Reconciler.BaseInstance = Module
		self.Reconciler:ReconcileDescendants()

		self.Reconciler.BaseInstance = nil
	end
end

function QuestService.InitializePlayer(self: QuestService, Player: Player, ObtainedQuests: { QuestInstance }?): PlayerProfile?
	if self.PlayerProfiles[Player] then
		return
	end
	
	self.PlayerProfiles[Player] = PlayerProfile.new(Player, ObtainedQuests or { })
	return self.PlayerProfiles[Player]
end

function QuestService.GetPlayerProfile(self: QuestService, Player: Player): PlayerProfile?
	return self.PlayerProfiles[Player]
end

function QuestService.GetBaseQuest(self: QuestService, QuestId: string): BaseQuest?
	for _, Quest in pairs(self.Reconciler.Data) do
		if Quest.Id == QuestId then
			return Quest
		end
	end
	
	return nil
end

function QuestService.PlayerHasQuest(self: QuestService, Player: Player, QuestId: string): boolean
	local Profile = self:GetPlayerProfile(Player)
	if not Profile then
		return false
	end
	
	return Profile:HasQuest(QuestId)
end
 
function QuestService.AddQuestToPlayer(self: QuestService, Player: Player, QuestId: string, InitialValue: number?, SkipStartedCallback: boolean?): ()
	local Profile = self:GetPlayerProfile(Player)
	if not Profile then
		return
	end
	
	local BaseQuest = self:GetBaseQuest(QuestId)
	if not BaseQuest then
		return
	end
	
	-- prevent duplicates
	if Profile:HasQuest(QuestId) then
		return
	end
	
	Profile:AddQuest(
		QuestId,
		InitialValue or 0
	)
	
	if (SkipStartedCallback ~= true) and typeof(BaseQuest.QuestStartedCallback) == 'function' and self.DoStartedCallbacks then
		BaseQuest.QuestStartedCallback(Player)
	end
end

function QuestService.SkipQuestForPlayer(self: QuestService, Player: Player, QuestId: string, SkipCompletedCallback: boolean?): ()
	local Profile = self:GetPlayerProfile(Player)
	if not Profile then
		return
	end
	
	if not Profile:HasQuest(QuestId) then
		return
	end
	
	-- Get Base Quest
	local BaseQuest = self:GetBaseQuest(QuestId)
	if not BaseQuest then
		-- This should never happen unless a quest has been removed from the Quests module
		-- or if the quest never existed in the first place
		return
	end
	
	-- Update Quest
	Profile:UpdateQuest(
		QuestId,
		BaseQuest.MaxValue,
		true
	)
	
	if (SkipCompletedCallback ~= true) and typeof(BaseQuest.CompletedCallback) == 'function' and self.DoCompletedCallbacks then
		BaseQuest.CompletedCallback(Player)
	end
end

function QuestService.RemoveAllQuestsFromPlayer(self: QuestService, Player: Player, SkipRemovedCallbacks: boolean?): ()
	local Profile = self:GetPlayerProfile(Player)
	if not Profile then
		return
	end
	
	for _, Quest in Profile.Replica.Data.Quests do
		self:RemoveQuestFromPlayer(Player, Quest.Id, SkipRemovedCallbacks)
	end
end

function QuestService.RemoveQuestFromPlayer(self: QuestService, Player: Player, QuestId: string, SkipRemovedCallback: boolean?): ()
	local Profile = self:GetPlayerProfile(Player)
	if not Profile then
		return
	end
	
	if not Profile:HasQuest(QuestId) then
		return
	end

	local BaseQuest = self:GetBaseQuest(QuestId)
	if not BaseQuest then
		return
	end
	
	Profile:RemoveQuest(QuestId)

	if (SkipRemovedCallback ~= true) and typeof(BaseQuest.QuestRemovedCallback) == 'function' and self.DoRemovedCallbacks then
		BaseQuest.QuestRemovedCallback(Player)
	end
end

function QuestService.UpdateQuestForPlayer(self: QuestService, Player: Player, QuestId: string, NewAmount: number): ()
	local Profile = self:GetPlayerProfile(Player)
	if not Profile then
		return
	end
	
	-- Get Base Quest
	local BaseQuest = self:GetBaseQuest(QuestId)
	if not BaseQuest then
		return
	end
	
	-- Check if there wasn't a change between the new amount and the current amount
	local QuestToUpdate = Profile:GetQuest(QuestId)
	if QuestToUpdate.CurrentValue == NewAmount then
		return
	end
	
	if (not self.AllowQuestValuesToDecrease) and NewAmount < QuestToUpdate.CurrentValue then
		return
	end
	
	if (not self.AllowQuestValuesToExceedMaxValues) and NewAmount > BaseQuest.MaxValue then
		return
	end
	
	Profile:UpdateQuest(
		QuestId,
		NewAmount
	)
	
	if NewAmount < 0 or NewAmount > BaseQuest.MaxValue then
		return
	end
	
	if NewAmount == BaseQuest.MaxValue and typeof(BaseQuest.CompletedCallback) == 'function' and self.DoCompletedCallbacks then
		BaseQuest.CompletedCallback(Player)
	end
	
	local IsIncremented = QuestToUpdate.CurrentValue < NewAmount
	
	if IsIncremented then
		if typeof(BaseQuest.IncrementCallback) == 'function' and self.DoIncrementCallbacks then
			BaseQuest.IncrementCallback(Player, NewAmount)
		end
	else
		if typeof(BaseQuest.DecrementCallback) == 'function' and self.DoDecrementCallbacks then
			BaseQuest.DecrementCallback(Player, NewAmount)
		end
	end
end

function QuestService.GetQuestFromPlayer(self: QuestService, Player: Player, QuestId: string): QuestInstance?
	local Profile = self:GetPlayerProfile(Player)
	if not Profile then
		return
	end
	
	return Profile:GetQuest(QuestId)
end

return QuestService