local InputContainer = require("ui/widget/container/inputcontainer")
local CenterContainer = require("ui/widget/container/centercontainer")
local Notification = require("ui/widget/notification")
local ConfirmBox = require("ui/widget/confirmbox")
local Menu = require("ui/widget/menu")
local Device = require("device")
local Screen = require("device").screen
local Input = require("device").input
local Event = require("ui/event")
local UIManager = require("ui/uimanager")
local Screen = require("device").screen
local DEBUG = require("dbg")
local _ = require("gettext")

local ReaderFont = InputContainer:new{
    font_face = nil,
    font_size = nil,
    line_space_percent = nil,
    font_menu_title = _("Change font"),
    face_table = nil,
    -- default gamma from crengine's lvfntman.cpp
    gamma_index = nil,
}

function ReaderFont:init()
    if Device:hasKeyboard() then
        -- add shortcut for keyboard
        self.key_events = {
            ShowFontMenu = { {"F"}, doc = "show font menu" },
            IncreaseSize = {
                { "Shift", Input.group.PgFwd },
                doc = "increase font size",
                event = "ChangeSize", args = "increase" },
            DecreaseSize = {
                { "Shift", Input.group.PgBack },
                doc = "decrease font size",
                event = "ChangeSize", args = "decrease" },
            IncreaseLineSpace = {
                { "Alt", Input.group.PgFwd },
                doc = "increase line space",
                event = "ChangeLineSpace", args = "increase" },
            DecreaseLineSpace = {
                { "Alt", Input.group.PgBack },
                doc = "decrease line space",
                event = "ChangeLineSpace", args = "decrease" },
        }
    end
    -- build face_table for menu
    self.face_table = {}
    local face_list = cre.getFontFaces()
    for k,v in ipairs(face_list) do
        table.insert(self.face_table, {
            text = v,
            callback = function()
                self:setFont(v)
            end,
            hold_callback = function()
                self:makeDefault(v)
            end,
            checked_func = function()
                return v == self.font_face
            end
        })
        face_list[k] = {text = v}
    end
    self.ui.menu:registerToMainMenu(self)
end

function ReaderFont:onSetDimensions(dimen)
    self.dimen = dimen
end

function ReaderFont:onReadSettings(config)
    self.font_face = config:readSetting("font_face")
            or self.ui.document.default_font
    self.ui.document:setFontFace(self.font_face)

    self.header_font_face = config:readSetting("header_font_face")
            or self.ui.document.header_font
    self.ui.document:setHeaderFont(self.header_font_face)

    self.font_size = config:readSetting("font_size")
            or DCREREADER_CONFIG_DEFAULT_FONT_SIZE or 22
    self.ui.document:setFontSize(Screen:scaleBySize(self.font_size))

    self.font_embolden = config:readSetting("font_embolden")
            or G_reader_settings:readSetting("copt_font_weight") or 0
    self.ui.document:toggleFontBolder(self.font_embolden)

    self.line_space_percent = config:readSetting("line_space_percent")
            or G_reader_settings:readSetting("copt_line_spacing")
            or DCREREADER_CONFIG_LINE_SPACE_PERCENT_MEDIUM
    self.ui.document:setInterlineSpacePercent(self.line_space_percent)

    self.gamma_index = config:readSetting("gamma_index")
            or G_reader_settings:readSetting("copt_font_gamma")
            or DCREREADER_CONFIG_DEFAULT_FONT_GAMMA
    self.ui.document:setGammaIndex(self.gamma_index)

    -- Dirty hack: we have to add folloing call in order to set
    -- m_is_rendered(member of LVDocView) to true. Otherwise position inside
    -- document will be reset to 0 on first view render.
    -- So far, I don't know why this call will alter the value of m_is_rendered.
    table.insert(self.ui.postInitCallback, function()
        self.ui:handleEvent(Event:new("UpdatePos"))
    end)
end

function ReaderFont:onShowFontMenu()
    -- build menu widget
    local main_menu = Menu:new{
        title = self.font_menu_title,
        item_table = self.face_table,
        width = Screen:getWidth() - 100,
    }
    -- build container
    local menu_container = CenterContainer:new{
        main_menu,
        dimen = Screen:getSize(),
    }
    main_menu.close_callback = function ()
        UIManager:close(menu_container)
    end
    -- show menu

    main_menu.show_parent = menu_container

    UIManager:show(menu_container)

    return true
end

--[[
    UpdatePos event is used to tell ReaderRolling to update pos.
--]]
function ReaderFont:onChangeSize(direction)
    local delta = direction == "decrease" and -1 or 1
    self.font_size = self.font_size + delta
    self.ui:handleEvent(Event:new("SetFontSize", self.font_size))
    return true
end

function ReaderFont:onSetFontSize(new_size)
    if new_size > 72 then new_size = 72 end
    if new_size < 12 then new_size = 12 end

    self.font_size = new_size
    UIManager:show(Notification:new{
        text = _("Set font size to ")..self.font_size,
        timeout = 1,
    })
    self.ui.document:setFontSize(Screen:scaleBySize(new_size))
    self.ui:handleEvent(Event:new("UpdatePos"))

    return true
end

function ReaderFont:onSetLineSpace(space)
    self.line_space_percent = math.min(200, math.max(80, space))
    UIManager:show(Notification:new{
        text = _("Set line space to ")..self.line_space_percent.."%",
        timeout = 1,
    })
    self.ui.document:setInterlineSpacePercent(self.line_space_percent)
    self.ui:handleEvent(Event:new("UpdatePos"))
    return true
end

function ReaderFont:onToggleFontBolder(toggle)
    self.font_embolden = toggle
    self.ui.document:toggleFontBolder(toggle)
    self.ui:handleEvent(Event:new("UpdatePos"))
    return true
end

function ReaderFont:onSetFontGamma(gamma)
    self.gamma_index = gamma
    UIManager:show(Notification:new{
        text = _("Set font gamma to ")..self.gamma_index,
        timeout = 1
    })
    self.ui.document:setGammaIndex(self.gamma_index)
    self.ui:handleEvent(Event:new("RedrawCurrentView"))
    return true
end

function ReaderFont:onSaveSettings()
    self.ui.doc_settings:saveSetting("font_face", self.font_face)
    self.ui.doc_settings:saveSetting("header_font_face", self.header_font_face)
    self.ui.doc_settings:saveSetting("font_size", self.font_size)
    self.ui.doc_settings:saveSetting("font_embolden", self.font_embolden)
    self.ui.doc_settings:saveSetting("line_space_percent", self.line_space_percent)
    self.ui.doc_settings:saveSetting("gamma_index", self.gamma_index)
end

function ReaderFont:setFont(face)
    if face and self.font_face ~= face then
        self.font_face = face
        UIManager:show(Notification:new{
            text = _("Redrawing with font ")..face,
            timeout = 1,
        })

        self.ui.document:setFontFace(face)
        -- signal readerrolling to update pos in new height
        self.ui:handleEvent(Event:new("UpdatePos"))
    end
end

function ReaderFont:makeDefault(face)
    if face then
        UIManager:show(ConfirmBox:new{
            text = _("Set default font to ")..face.."?",
            ok_callback = function()
                G_reader_settings:saveSetting("cre_font", face)
            end,
        })
    end
end

function ReaderFont:addToMainMenu(tab_item_table)
    -- insert table to main reader menu
    table.insert(tab_item_table.typeset, {
        text = self.font_menu_title,
        sub_item_table = self.face_table,
    })
end

return ReaderFont
