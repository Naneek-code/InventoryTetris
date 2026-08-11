if not getActivatedMods():contains("\\TEST_FRAMEWORK") or not isDebugEnabled() then return end
local TestFramework = require("TestFramework/TestFramework")
local TestUtils = require("TestFramework/TestUtils")
local TetrisDevTool = require("InventoryTetris/Dev/TetrisDevTool")

TestFramework.registerTestModule("Inventory Tetris", "Dev Tool Regression Tests", function ()
    local Tests = TestUtils.newTestModule("client/InventoryTetris/Tests/DevToolRegressionTests.lua")

    function Tests.test_containerEditorLayoutFollowsScaledPreview()
        local previewY = 250
        local scales = {1.0, 1.5, 2.0, 3.0, 4.0}

        for _, scale in ipairs(scales) do
            local previewWidth = math.floor(320 * scale)
            local previewHeight = math.floor(220 * scale)
            local mockContainerUi = {
                getY = function() return previewY end,
                getWidth = function() return previewWidth end,
                getHeight = function() return previewHeight end,
            }

            local editorWidth, editorHeight, footerY = TetrisDevTool._getContainerEditorLayout(mockContainerUi)
            local previewBottom = previewY + previewHeight

            -- Smangsty: Footer must clear the bottom add-grid controls, not merely the scaled preview itself.
            TestUtils.assert(footerY >= previewBottom + 48)
            TestUtils.assert(editorHeight > footerY)
            TestUtils.assert(editorWidth >= previewWidth)
        end
    end

    return Tests
end)
