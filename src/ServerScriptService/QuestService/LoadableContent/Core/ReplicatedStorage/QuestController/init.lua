-- Services
local ReplicatedStorage = game:GetService('ReplicatedStorage')

-- Imports
local ReplicaController = require(ReplicatedStorage:WaitForChild('ReplicaController'))
local DataReconciler = require(ReplicatedStorage:WaitForChild('DataReconciler'))
local QuestUtil = require(ReplicatedStorage:WaitForChild('QuestUtil'))

local Signal = require(script.Signal)

-- Local Variables
local IsInitialized = false
local CurrentData = nil

-- Controller Initialization
local QuestController = {
	Reconciler = DataReconciler.init(
		{},
		nil,
		QuestUtil.GetQuestTemplate()
	),
	
	QuestsLoaded = Signal.new(),
	
	QuestUpdated = Signal.new(),
	QuestStarted = Signal.new(),
	QuestRemoved = Signal.new(),
	
	Replica = nil,
}

-- Types
type QuestController = typeof(QuestController)
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

-- Local Functions
local function CombineTables(A, B): {any}
	local Result = table.clone(A)
	
	for _, v in B do
		table.insert(Result, v)
	end
	
	return Result
end

local function FindQuestInTable(Quests: { QuestInstance }, QuestId: string): QuestInstance?
	for _, Quest in Quests do
		if Quest.Id == QuestId then
			return Quest
		end
	end

	return nil
end

-- Controller Functions & Methods
function QuestController.Init(self: QuestController)
	if IsInitialized then
		return error('Attempted to reinitialize QuestController!')
	end
	IsInitialized = true
	
	local function UpdateCurrentData(Quests: { QuestInstance })
		Quests = table.clone(Quests)
		
		local IsCurrentDataNil = CurrentData == nil
		
		if not IsCurrentDataNil then
			local PreviousData = table.clone(CurrentData)
			CurrentData = Quests
			
			-- Fire events if possible
			local CombinedTable: { QuestInstance } = CombineTables(PreviousData, Quests)
			
			local AccountedForQuestsHashMap: { [string]: true? } = {}
			
			for _, Quest in pairs(CombinedTable) do
				if AccountedForQuestsHashMap[Quest.Id] then
					continue
				end
				
				local QuestFromCurrentData = FindQuestInTable(PreviousData, Quest.Id)
				local QuestFromNewData = FindQuestInTable(Quests, Quest.Id)
				
				local IsNewQuest = QuestFromCurrentData == nil and QuestFromNewData ~= nil
				local IsOldQuest = QuestFromNewData == nil and QuestFromCurrentData ~= nil
				
				if IsNewQuest then self.QuestStarted:Fire(QuestFromNewData)
				elseif IsOldQuest then self.QuestRemoved:Fire(QuestFromCurrentData)
					
				elseif QuestFromCurrentData.CurrentValue ~= QuestFromNewData.CurrentValue
					or QuestFromCurrentData.IsCompleted ~= QuestFromNewData.IsCompleted
				then
					self.QuestUpdated:Fire(QuestFromNewData)
				end
				
				AccountedForQuestsHashMap[Quest.Id] = true
			end
		else
			CurrentData = Quests
			
			if IsCurrentDataNil then
				self.QuestsLoaded:Fire(Quests)
			end
		end
		
	end
	
	ReplicaController.ReplicaOfClassCreated('PlayerQuests', function(Replica)
		self.Replica = Replica
		
		Replica:ListenToChange({ 'Quests' }, UpdateCurrentData)
		UpdateCurrentData(Replica.Data.Quests)
	end)
	
	ReplicaController.RequestData()
	
	return QuestController
end

function QuestController.RegisterQuest(self: QuestController, QuestPrototype: BaseQuest)
	self.Reconciler:ReconcileData(QuestPrototype)
end

function QuestController.RegisterModule(self: QuestController, Module: ModuleScript, RegisterDescendants: boolean?)
	self.Reconciler:ReconcileModule(Module)
	
	if RegisterDescendants then
		self.Reconciler.BaseInstance = Module
		self.Reconciler:ReconcileDescendants()
		
		self.Reconciler.BaseInstance = nil
	end
end

function QuestController.GetBaseQuest(self: QuestController, QuestId: string): BaseQuest?
	for _, Quest in pairs(self.Reconciler.Data) do
		if Quest.Id == QuestId then
			return Quest
		end
	end

	return nil
end

function QuestController.IsQuestCompleted(self: QuestController, QuestId: string)
	local BaseQuest = self:GetBaseQuest(QuestId)
	if not BaseQuest then
		return false
	end
	
	local QuestInstance = FindQuestInTable(CurrentData, QuestId)
	if not QuestInstance then
		return false
	end
	
	return QuestInstance.CurrentValue >= BaseQuest.MaxValue
end

return QuestController