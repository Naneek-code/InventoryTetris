Events.OnGameStart.Add(function ()
    local og_new = ISMoveablesAction.new

    function ISMoveablesAction:new(character, square, mode, origSpriteName, object, direction, item, moveCursor)
        if moveCursor then
            -- Smangsty: Pass the action mode explicitly so placement-only JIT transfer does not rely on cursor-global state.
            ISMoveableCursor.tetris_jitTransferItems(character, moveCursor.currentMoveProps, origSpriteName, mode)
        end
        return og_new(self, character, square, mode, origSpriteName, object, direction, item, moveCursor)
    end
end)