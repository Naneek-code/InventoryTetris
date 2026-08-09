local SETTINGS = require ("EquipmentUI/Settings")

local events_hooked = false
Events.OnGameStart.Add(function()
	if events_hooked then return end

	local og_renderdetails = ISInventoryPane.renderdetails
	function ISInventoryPane:renderdetails(doDragged)
		---@cast self.parent ISInventoryPage
		local inventoryPage = self.parent

		if not inventoryPage or not inventoryPage.onCharacter then
			og_renderdetails(self, doDragged)
			return
		end

		if self.doHideEquipped ~= SETTINGS.HIDE_EQUIPPED_ITEMS then -- So the list is updated when the setting is changed
			self:refreshContainer()
		end

		if not SETTINGS.HIDE_EQUIPPED_ITEMS then 
			self.doHideEquipped = false
			og_renderdetails(self, doDragged)
		else
			self.doHideEquipped = true
			self.itemslist = self.hideEquippedItemsList
			og_renderdetails(self, doDragged)
			self.itemslist = self.cachedItemList
		end
	end

	local og_refreshContainer = ISInventoryPane.refreshContainer
	function ISInventoryPane:refreshContainer()
		og_refreshContainer(self)

		---@cast self.parent ISInventoryPage
		local inventoryPage = self.parent
		
		if not inventoryPage then return end
		if not inventoryPage.onCharacter then return end
		if SETTINGS.InventoryTetris then return end

		self.cachedItemList = self.itemslist

		if not SETTINGS.HIDE_EQUIPPED_ITEMS or not inventoryPage.onCharacter then return end

		local newlist = {}
		for k, v in ipairs(self.itemslist) do
			if v and not (v.equipped or v.inHotbar) then
				newlist[#newlist+1] = self.itemslist[k]
			end
		end
		self.hideEquippedItemsList = newlist
	end

	events_hooked = true
end)
