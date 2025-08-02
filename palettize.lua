--
-- Apply a palette to an image.
--
-- Usage (first time):
--   1) Open Aseprite
--   2) Go to File > Scripts > Open scripts folder
--   3) Copy this file to the scripts folder
--   4) In Aseprite, go to File > Scripts > Rescan scripts folder
--   5) Run the script: File > Scripts > palettize
--
-- Usage:
--   1) File > Scripts > palettize
--
local sprite = app.activeSprite
if sprite == nil then
    return app.alert("ERROR: There is no active sprite")
end
if sprite.colorMode == ColorMode.Tilemap then
    return app.alert("ERROR: Tilemap color mode not supported")
end
if sprite.colorMode ~= ColorMode.RGB then
    app.command.ChangePixelFormat{ format="rgb" }
end
local image = sprite.cels[1].image
if image == nil then
    return app.alert("ERROR: The active sprite has no image")
end

local sourceColors = { Color{ r=33, g=30, b=32 }, Color{ r=85, g=85, b=104 }, Color{ r=160, g=160, b=139 }, Color{ r=233, g=239, b=236 }}
local previewScale = math.floor((200 / image.width) + 0.5) -- Preview as close to 200 pix as possible
if previewScale < 1 then
    previewScale = 1
elseif previewScale > 8 then
    previewScale = 8
end
local adjustGlobal = {h=0, s=0, l=0}
local adjustR = {h=0, s=0, l=0}
local adjustY = {h=0, s=0, l=0}
local adjustG = {h=0, s=0, l=0}
local adjustC = {h=0, s=0, l=0}
local adjustB = {h=0, s=0, l=0}
local adjustP = {h=0, s=0, l=0}
local adjustType = "global"
local palette = Palette(#sourceColors)
for i=1, #sourceColors, 1 do
    palette:setColor(i-1, sourceColors[i])
end
local paletteExclusions = {}
local prevImageA = Image(image.width, image.height, ColorMode.RGB)
local prevImageB = Image(image.width, image.height, ColorMode.RGB)
local showPalette = true

getActiveAdjust = function(type)
    if type == nil then
        type = adjustType
    end
    if type == "global" then
        return adjustGlobal
    elseif type == "red" then
        return adjustR
    elseif type == "yellow" then
        return adjustY 
    elseif type == "green" then
        return adjustG
    elseif type == "cyan" then
        return adjustC
    elseif type == "blue" then
        return adjustB
    elseif type == "purple" then
        return adjustP
    end
    return nil
end

-- Load a palette from a png file
loadPalette = function(data)
    if data.src then
        palette = Palette{ fromFile=data.src }
    end
    if palette ~= nil then
        sourceColors = {}
        for i=0, #palette - 1, 1  do
            local color = palette:getColor(i)
            table.insert(sourceColors, Color{ r=color.red, g=color.green, b=color.blue })
        end
    end
end

-- Linear interpolation between first and second
function lerp(first, second, by)
    return first * (1 - by) + second * by
end

-- Shift a color by hue, saturation and lightness
function colorShift(color, type)
    local f = 1
    local v = getActiveAdjust(type)
    if type ~= "global" then
        local h = 0
        if type == "red" then
            h = 0
        elseif type == "yellow" then
            h = 60
        elseif type == "green" then
            h = 120
        elseif type == "cyan" then
            h = 180
        elseif type == "blue" then
            h = 240
        elseif type == "purple" then
            h = 300
        end
        local d = 360 - math.abs(color.hslHue - h)
        if d < 240 then
            f = 0
        else
            f = (d - 240)  / 120
        end
    end
    local hueShift = v.h * f / 8
    local satShift = v.s * f / 100
    local lightShift = v.l * f / 200

    local newColor = Color(color)

    newColor.hslHue = (newColor.hslHue + hueShift) % 360
  
    if (satShift > 0) then
      newColor.saturation = lerp(newColor.saturation, 1, satShift)
    elseif (satShift < 0) then
      newColor.saturation = lerp(newColor.saturation, 0, -satShift)
    end
  
    if (lightShift > 0) then
      newColor.lightness = lerp(newColor.lightness, 1, lightShift)
    elseif (lightShift < 0) then
      newColor.lightness = lerp(newColor.lightness, 0, -lightShift)
    end
  
    return newColor
end

isExclusion = function(index, color)
    for j=1, #paletteExclusions, 1 do
        if paletteExclusions[j].index == index then
            local exclColor = paletteExclusions[j].color
            local exclDistance = math.abs(color.red - exclColor.red) + math.abs(color.green - exclColor.green) + math.abs(color.blue - exclColor.blue)
            if (exclDistance / 765) < paletteExclusions[j].tolerance then
                return true
            end
        end
    end
    return false
end

matchPaletteId = function(color)
    if (color.alpha == 0) then
        return Color{ r=0, g=0, b=0, a=0 }
    end
    local bestMatch = 0
    local bestDistance = 999999
    for i=1, #sourceColors, 1 do
        local palColor = sourceColors[i]
        local distance = math.abs(color.red - palColor.red) + math.abs(color.green - palColor.green) + math.abs(color.blue - palColor.blue)
        if distance < bestDistance then
            if not isExclusion(i, color) then
                bestMatch = i
                bestDistance = distance
            end
        end
    end
    return bestMatch
end

-- Find the closest color in the palette
matchPalette = function(color)
    return sourceColors[matchPaletteId(color)]
end

-- Draw the exclusions as pairs of swatches
drawExclusions = function(context)
    local w = #paletteExclusions * 24 + 4
    local h = 16
    context.antialias = true
    context.strokeWidth = 1

    context:beginPath()
    context.color = app.theme.color.background
    context:roundedRect(Rectangle(0.5,0.5, w-1, h-1), 2)
    context:stroke()

    context:beginPath()
    context.color = app.theme.color.editor_sprite_border
    context:roundedRect(Rectangle(1.5,1.5, w-3,h-3), 2)
    context:stroke()

    local x = 2
    for i=1, #paletteExclusions, 1 do
        context.color = paletteExclusions[i].color
        context:fillRect(x, 2, 24, 12)
        context.color = sourceColors[paletteExclusions[i].index]
        context:beginPath()
        context:moveTo(x, 14)
        context:lineTo(x + 24, 14)
        context:lineTo(x + 24, 2)
        context:fill()

        context.color = Color{ r=0, g=0, b=0 }
        context.strokeWidth = 3
        context:beginPath()
        context:moveTo(x + 9.5, 4.5)
        context:lineTo(x + 15.5, 10.5)
        context:moveTo(x + 15.5, 4.5)
        context:lineTo(x + 9.5, 10.5)
        context:stroke()

        context.color = Color{ r=255, g=0, b=0 }
        context.strokeWidth = 1
        context:beginPath()
        context:moveTo(x + 9.5, 4.5)
        context:lineTo(x + 15.5, 10.5)
        context:moveTo(x + 15.5, 4.5)
        context:lineTo(x + 9.5, 10.5)
        context:stroke()

        x = x + 24
    end
end

-- Draw the preview images
-- The first has HSV applied
-- The second has HSV applied and is matched to the palette
drawPreviewImages = function(context)
    local w = image.width
    local h = image.height
    for y=0, h-1, 1 do
        for x=0, w-1, 1 do
            local color = Color(image:getPixel(x, y))
            color = colorShift(color, "global")
            color = colorShift(color, "red")
            color = colorShift(color, "yellow")
            color = colorShift(color, "green")
            color = colorShift(color, "cyan")
            color = colorShift(color, "blue")
            color = colorShift(color, "purple")
            local palColor = matchPalette(color)
            prevImageA:drawPixel(x, y, color)
            prevImageB:drawPixel(x, y, palColor)
        end
    end
    local sw = w * previewScale
    local sh = h * previewScale
    if context == nil then
        return
    end
    context:drawImage(prevImageA, 0, 0, w, h, 0, 0, sw, sh)
    context:drawImage(prevImageB, 0, 0, w, h, sw, 0, sw, sh)
end

-- Add an exclusion when user clicks on the preview canvas
addExclusionFromPreview = function(context, mx, my)
    mx = math.floor(mx / previewScale);
    my = math.floor(my / previewScale);
    if (mx < image.width) then
        return false
    end
    local exclColor = Color(prevImageA:getPixel(mx - image.width, my))
    local match = matchPaletteId(exclColor)
    -- If an exact match exists then exit
    for i=1, #paletteExclusions, 1 do
        if paletteExclusions[i].index == match and paletteExclusions[i].color == exclColor then
            return false
        end
    end
    table.insert(paletteExclusions, {
        index = match,
        color = exclColor,
        tolerance = 0.1
    })
    return true
end

-- Remove an exclusion when user clicks on the exclusions canvas
removeExclusion = function(context, mx, my)
    mx = mx - 2
    my = my - 2
    if (mx < 0 or mx >= #paletteExclusions * 24) then
        return false
    end
    if (my < 0 or my >= 12) then
        return false
    end
    local index = math.floor(mx / 24) + 1
    table.remove(paletteExclusions, index)
    return true
end

-- Apply the palette to the image and convert to indexed mode
applyPalette = function()
    sprite.cels[1].image = prevImageB
    sprite:setPalette(palette)
    app.command.ChangePixelFormat{ format="indexed", dithering="none" }
    app.refresh()
end

-- (re)draw the dialog
showDialog = function()
    local dlg = Dialog{ title = "Palettize" }
    dlg:file{ id="src", label="Source Palette",
        label="Pallete",
        title="Browse for palette file (png)",
        open=true,
        filetypes=".png",
        onchange=function(ev)
            loadPalette(dlg.data)
            showPalette = true
            showDialog()
            dlg:close()
        end
    }
    if showPalette then
        local swatchPerRow = 32
        local paletteRows = math.ceil(#sourceColors / swatchPerRow)
        for i=0, paletteRows-1, 1 do
            local row = {}
            for j=1, swatchPerRow, 1 do
                local index = i * swatchPerRow + j
                if index <= #sourceColors then
                    table.insert(row, sourceColors[index])
                end
            end
            dlg:shades{ id="palette"..i,
                label="",
                mode="pick",
                colors=row,
                hexpand=false,
                onclick=function(ev)
                    for i=1, #sourceColors, 1 do
                        if sourceColors[i] == ev.color then
                            table.remove(sourceColors, i)
                            for j=1, #paletteExclusions, 1 do
                                if paletteExclusions[j].index == i then
                                    table.remove(paletteExclusions, j)
                                    break
                                end
                            end
                            break
                        end
                    end
                    showDialog()
                    dlg:close()
                end
            }
        end
        dlg:button{ id="hidePalette",
            text="Hide palette",
            hexpand=false,
            onclick=function(ev)
                showPalette = false
                showDialog()
                dlg:close()
            end
        }
    else
        dlg:button{ id="showPalette",
            text="Show palette",
            hexpand=false,
            onclick=function(ev)
                showPalette = true
                showDialog()
                dlg:close()
            end
        }
    end
    if #paletteExclusions > 0 then
        dlg:canvas{ id="exclusions",
        label = "Exclusions",
        width = #paletteExclusions * 24 + 4,
        height = 16,
        onpaint=function(ev)
            drawExclusions(ev.context)
        end,
        onmouseup=function(ev)
            if removeExclusion(ev.context, ev.x, ev.y) then
                showDialog()
                dlg:close()
            end
        end
    }
    end

    dlg:radio{ id="adjustTypeAll",
        label="Adjust",
        text="Global",
        hexpand=false,
        selected=adjustType == "global",
        onclick=function(ev)
            adjustType = "global"
            showDialog()
            dlg:close()
        end
    }
    dlg:radio{ id="adjustTypeR",
        text="Reds",
        hexpand=false,
        selected=adjustType == "red",
        onclick=function(ev)
            adjustType = "red"
            showDialog()
            dlg:close()
        end
    }
    dlg:radio{ id="adjustTypeY",
        text="Yellows",
        hexpand=false,
        selected=adjustType == "yellow",
        onclick=function(ev)
            adjustType = "yellow"
            showDialog()
            dlg:close()
        end
    }
    dlg:radio{ id="adjustTypeG",
        text="Greens",
        hexpand=false,
        selected=adjustType == "green",
        onclick=function(ev)
            adjustType = "green"
            showDialog()
            dlg:close()
        end
    }
    dlg:radio{ id="adjustTypeC",
        text="Cyans",
        hexpand=false,
        selected=adjustType == "cyan",
        onclick=function(ev)
            adjustType = "cyan"
            showDialog()
            dlg:close()
        end
    }
    dlg:radio{ id="adjustTypeB",
        text="Blues",
        hexpand=false,
        selected=adjustType == "blue",
        onclick=function(ev)
            adjustType = "blue"
            showDialog()
            dlg:close()
        end
    }
    dlg:radio{ id="adjustTypeP",
        text="Purples",
        hexpand=false,
        selected=adjustType == "purple",
        onclick=function(ev)
            adjustType = "purple"
            showDialog()
            dlg:close()
        end
    }
    dlg:radio{ id="adjustTypeReset",
        text="Reset all",
        hexpand=false,
        selected=adjustType == "reset",
        onclick=function(ev)
            adjustType = "global"
            adjustGlobal = {h=0, s=0, l=0}
            adjustR = {h=0, s=0, l=0}
            adjustG = {h=0, s=0, l=0}
            adjustB = {h=0, s=0, l=0}
            showDialog()
            dlg:close()
        end
    }
    local adjust = getActiveAdjust()
    dlg:slider{ id="hue",
        label="Hue",
        min=-100,
        max=100,
        value=adjust.h,
        onrelease=function(ev)
            local adjust = getActiveAdjust()
            adjust.h = dlg.data.hue
            showDialog()
            dlg:close()
        end
    }
    dlg:slider{ id="sat",
        label="Saturation",
        min=-100,
        max=100,
        value=adjust.s,
        onrelease=function(ev)
            local adjust = getActiveAdjust()
            adjust.s = dlg.data.sat
            showDialog()
            dlg:close()
        end
    }
    dlg:slider{ id="light",
        label="Lightness",
        min=-100,
        max=100,
        value=adjust.l,
        onrelease=function(ev)
            local adjust = getActiveAdjust()
            adjust.l = dlg.data.light
            showDialog()
            dlg:close()
        end
    }
    dlg:canvas{ id="preview",
        width=image.width * previewScale * 2,
        height=image.height * previewScale,
        onpaint=function(ev)
            drawPreviewImages(ev.context)
        end,
        onmouseup=function(ev)
            if addExclusionFromPreview(ev.context, ev.x, ev.y) then
                showDialog()
                dlg:close()
            end
        end
    }
    dlg:combobox{ id="previewScale",
        label="Preview scale",
        hexpand=false,
        option=tostring(previewScale.."x"),
        options={ "1x", "2x", "3x", "4x", "5x", "6x", "7x", "8x" },
        onchange=function(ev)
            previewScale = tonumber(dlg.data.previewScale:sub(1, -2))
            showDialog()
            dlg:close()
        end
    }
    dlg:button{ id="apply",
        text="Convert to indexed mode and apply palette",
        onclick=function(ev)
            applyPalette()
            dlg:close()
        end
    }
    dlg:show{wait = false}
end

-- Run the script
showDialog(app.fgColor)
