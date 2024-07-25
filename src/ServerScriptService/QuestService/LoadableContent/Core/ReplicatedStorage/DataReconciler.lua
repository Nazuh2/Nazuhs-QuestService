local DataReconciler = {}
local DataReconcilerPrototype = {}
DataReconcilerPrototype.__index = DataReconcilerPrototype

function DataReconciler.init(Data: { any }, BaseInstance: Instance?, Template: { [string]: any })
	local Reconciler = setmetatable({
		Data = Data,
		BaseInstance = BaseInstance,
		Template = Template
	}, DataReconcilerPrototype)
	
	return Reconciler
end

function DataReconcilerPrototype:ReconcileModule(Module: ModuleScript)
	if not Module:IsA('ModuleScript') then
		return
	end

	local required = require(Module)

	if typeof(required) ~= 'table' then
		warn('Module doesn\'t return a table during reconciliation! Module:', Module:GetFullName())
		return
	end

	self.CurrentModuleBeingReconciled = Module:GetFullName()

	for _, Item in pairs(required) do
		Item = self:ReconcileData(Item)
	end
end

function DataReconcilerPrototype:ReconcileDescendants()
	if not self.BaseInstance then
		return
	end
	
	for _, v in self.BaseInstance:GetDescendants() do
		self:ReconcileModule(v)
	end
	
	return self
end

function DataReconcilerPrototype:ReconcileData(Data)
	for k, v in pairs(self.Template) do
		if Data[k] then
			continue
		end

		if k == 'Id' then
			warn('ITEM DOESN\'T HAVE AN ID; SKIPPING!')
			return
		end
		
		Data[k] = v
	end
	
	self.Data[Data.Id] = Data
end

function DataReconcilerPrototype:Destroy()
	setmetatable(self, nil)
	self = nil
end

return DataReconciler