require "ISUI/ISUIElement"

---@class (partial) ISUIElement
---@field public drawTextureCenteredAndSquare fun(self: ISUIElement, texture: Texture, x: number, y: number, targetSizePixels: number, alpha: number, r: number, g: number, b: number)
---@field public isMouseOverAnyUI fun(): boolean

function ISUIElement:drawTextureCenteredAndSquare(texture, x, y, targetSizePixels, alpha, r, g, b)
    ---@type number
    local texW = texture:getWidth()
    ---@type number
    local texH = texture:getHeight()

    local largestDimension = math.max(texW, texH)
    local scaler = targetSizePixels / largestDimension
    
    local diff = math.abs(largestDimension - targetSizePixels)
    if diff < 8 then -- Just draw the texture unscale if it's close enough
        scaler = 1
    end

    texW = texW * scaler
    texH = texH * scaler

    local x2 = x - texW * 0.5
    local y2 = y - texH * 0.5
    self:drawTextureScaled(texture, x2, y2, texW, texH, alpha, r, g, b);
end

ISUIElement.isMouseOverAnyUI = function()
    local mouseOverUi = false
    local mx, my = getMouseX(), getMouseY()
    local allUi = UIManager.getUI()
    for i = 0, allUi:size() - 1 do
        local ui = allUi:get(i)
        if ui:isPointOver(mx, my) then
            mouseOverUi = true
            break
        end
    end
    return mouseOverUi
end