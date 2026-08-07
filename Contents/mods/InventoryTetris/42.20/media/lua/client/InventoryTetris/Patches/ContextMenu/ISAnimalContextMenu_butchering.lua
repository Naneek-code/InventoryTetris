Events.OnGameBoot.Add(function()
    -- Guard: this function may not exist in all B42 builds
    if not ISDropAnimalCorpseAndThen then return end

    local og_complete = ISDropAnimalCorpseAndThen.complete
    function ISDropAnimalCorpseAndThen:complete()
        -- Vanilla only removes from the player's main inventory.
        -- If the item is in a backpack, it duplicates. We remove it from its actual container here.
        local inv = self.item:getContainer()
        if inv and inv ~= self.character:getInventory() then
            inv:Remove(self.item)
            sendRemoveItemFromContainer(inv, self.item)
        end
        return og_complete(self)
    end

    local og_isValid = ISDropAnimalCorpseAndThen.isValid
    function ISDropAnimalCorpseAndThen:isValid()
        if not self.character:getCurrentSquare() then
            return false
        end
        
        -- Fix vanilla B42 bug where MP (isClient) fails to validate if corpse is in a backpack
        -- because it uses getInventory():containsID() which is not recursive.
        local inv = self.item:getContainer()
        if not inv or not inv:isInCharacterInventory(self.character) then
            return false
        end
        
        return true
    end
end)
