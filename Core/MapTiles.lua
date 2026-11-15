-- Pure layout for drawing a map's art layer as a grid of tiles.
-- No game calls: takes the numbers C_Map.GetMapArtLayers gives.
local addonName, ns = ...

local MapTiles = {}
ns.MapTiles = MapTiles

-- layer: { layerWidth, layerHeight, tileWidth, tileHeight }
-- fitWidth/fitHeight: the area to draw in.
-- Returns cols, rows, scale, and a list of tiles in the order
-- C_Map.GetMapArtLayerTextures returns them (row by row, left to right):
--   { index, x, y, width, height } in drawn (scaled) units, x/y from top-left.
function MapTiles.Layout(layer, fitWidth, fitHeight)
  local lw, lh = layer.layerWidth, layer.layerHeight
  local tw, th = layer.tileWidth, layer.tileHeight
  if not (lw and lh and tw and th) or lw <= 0 or lh <= 0 or tw <= 0 or th <= 0 then
    return nil
  end
  local cols = math.ceil(lw / tw)
  local rows = math.ceil(lh / th)
  local scale = math.min(fitWidth / lw, fitHeight / lh)
  local tiles = {}
  for r = 0, rows - 1 do
    for c = 0, cols - 1 do
      tiles[#tiles + 1] = {
        index = r * cols + c + 1,
        x = c * tw * scale,
        y = r * th * scale,
        width = tw * scale,
        height = th * scale,
      }
    end
  end
  return cols, rows, scale, tiles
end
