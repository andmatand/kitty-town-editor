-- Returns true if the x, y position is colliding with the mask
function IsCollision(self, x, y, flipHorizontal, flipVertical)
    if flipHorizontal then
        x = (self.size.w - 1) - x
    end
    if flipVertical then
        y = (self.size.h - 1) - y
    end

    return self.map[y * self.size.w + x + 1]
end

function CreateCollisionMask(imageData)
    local mask = {}
    mask.IsCollision = IsCollision
    mask.size = {w = imageData:getWidth(),
                 h = imageData:getHeight()}
    mask.map = {}

    for y = 0, mask.size.h - 1 do
        for x = 0, mask.size.w - 1 do
            local r, g, b, a
            r, g, b, a = imageData:getPixel(x, y)

            local bit
            if a == 255 then
                bit = true
            else
                bit = false
            end

            mask.map[y * mask.size.w + x + 1] = bit
        end
    end

    return mask
end
