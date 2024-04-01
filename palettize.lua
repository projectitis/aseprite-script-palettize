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
local previewScale = 2
local hue = 0
local saturation = 0
local lightness = 0
local palette = Palette(#sourceColors)
for i=1, #sourceColors, 1 do
    palette:setColor(i-1, sourceColors[i])
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
function colorShift(color)
    local hueShift = hue / 8
    local satShift = saturation / 100
    local lightShift = lightness / 200

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
            local color = colorShift(Color(image:getPixel(x, y)))
            local palColor = matchPalette(color)
            prevImageA:drawPixel(x, y, color)
            prevImageB:drawPixel(x, y, palColor)
        end
    end
    local sw = w * previewScale
    local sh = h * previewScale
    context:drawImage(prevImageA, 0, 0, w, h, 0, 0, sw, sh)
    context:drawImage(prevImageB, 0, 0, w, h, sw, 0, sw, sh)
end

-- Apply the palette to the image and convert to indexed mode
applyPalette = function(ev)
    local w = image.width
    local h = image.height
    local finalImage = Image(w, h, ColorMode.RGB)
    for y=0, h-1, 1 do
        for x=0, w-1, 1 do
            local color = colorShift(Color(image:getPixel(x, y)))
            local palColor = matchPalette(color)
            finalImage:drawPixel(x, y, palColor)
        end
    end
    sprite.cels[1].image = finalImage
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
    dlg:slider{ id="hue",
        label="Hue",
        min=-100,
        max=100,
        value=hue,
        onrelease=function(ev)
            hue = dlg.data.hue
            showDialog()
            dlg:close()
        end
    }
    dlg:slider{ id="sat",
        label="Saturation",
        min=-100,
        max=100,
        value=saturation,
        onrelease=function(ev)
            saturation = dlg.data.sat
            showDialog()
            dlg:close()
        end
    }
    dlg:slider{ id="light",
        label="Lightness",
        min=-100,
        max=100,
        value=lightness,
        onrelease=function(ev)
            lightness = dlg.data.light
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
