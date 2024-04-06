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

-- Find the closest color in the palette
matchPalette = function(color)
    if (color.alpha == 0) then
        return Color{ r=0, g=0, b=0, a=0 }
    end
    local bestMatch = nil
    local bestDistance = 999999
    for i=1, #sourceColors, 1 do
        local palColor = sourceColors[i]
        local distance = math.abs(color.red - palColor.red) + math.abs(color.green - palColor.green) + math.abs(color.blue - palColor.blue)
        if distance < bestDistance then
            bestMatch = palColor
            bestDistance = distance
        end
    end
    return bestMatch
end

-- Draw the preview images
-- The first has HSV applied
-- The second has HSV applied and is matched to the palette
drawPreviewImages = function(context)
    local w = image.width
    local h = image.height
    local prevImageA = Image(w, h, ColorMode.RGB)
    local prevImageB = Image(w, h, ColorMode.RGB)
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
        return prevImageB
    end
    context:drawImage(prevImageA, 0, 0, w, h, 0, 0, sw, sh)
    context:drawImage(prevImageB, 0, 0, w, h, sw, 0, sw, sh)
end

-- Apply the palette to the image and convert to indexed mode
applyPalette = function(ev)
    sprite.cels[1].image = drawPreviewImages()
    sprite:setPalette(palette)
    app.command.ChangePixelFormat{ format="indexed", dithering="none" }
    app.refresh()
end

-- (re)draw the dialog
showDialog = function()
    local dlg = Dialog{ title = "Palettize" }
    dlg:file{ id="src", label="Source Palette",
        label="Load pallete",
        title="Select image with palette",
        open=true,
        hexpand=false,
        filetypes=".png",
        onchange=function(ev)
            loadPalette(dlg.data)
            showDialog()
            dlg:close()
        end
    }
    local paletteRows = math.ceil(#sourceColors / 16)
    for i=0, paletteRows-1, 1 do
        local row = {}
        for j=1, 16, 1 do
            local index = i * 16 + j
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
                        break
                    end
                end
                showDialog()
                dlg:close()
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
