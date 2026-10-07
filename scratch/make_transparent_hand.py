import sys
from PIL import Image
import numpy as np

src_path = "/Users/xhzhou/.gemini/antigravity/brain/2a762f9a-01f0-43fc-b355-5a304be9bd77/stylized_hero_hand_3d_1791277455282.jpg"
dst_path = "/opt/heroesIsland/assets/icons/3d/guide_hand.png"

img = Image.open(src_path).convert("RGBA")
data = np.array(img, dtype=np.float32)

r = data[:, :, 0]
g = data[:, :, 1]
b = data[:, :, 2]

# The background is pure white: r > 250, g > 250, b > 250
# We calculate brightness and distance from white
min_c = np.minimum(np.minimum(r, g), b)
# For background white pixels: min_c is near 255
# Soft alpha transition near the edge: 242 -> 253
alpha = np.clip((253.0 - min_c) / (253.0 - 242.0), 0.0, 1.0) * 255.0

# Also check flood-fill from corners to avoid cutting inside the white glove
# We can use scipy or simple BFS floodfill for background mask
from scipy.ndimage import binary_erosion, binary_dilation

# Create a binary background candidate mask (strictly near corners/edges)
is_white = (r > 240) & (g > 240) & (b > 240)

# Flood fill from the outer borders
from collections import deque
h, w = is_white.shape
bg_mask = np.zeros((h, w), dtype=bool)
q = deque()

for x in range(w):
    if is_white[0, x]: q.append((0, x)); bg_mask[0, x] = True
    if is_white[h-1, x]: q.append((h-1, x)); bg_mask[h-1, x] = True
for y in range(h):
    if is_white[y, 0]: q.append((y, 0)); bg_mask[y, 0] = True
    if is_white[y, w-1]: q.append((y, w-1)); bg_mask[y, w-1] = True

while q:
    cy, cx = q.popleft()
    for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        ny, nx = cy + dy, cx + dx
        if 0 <= ny < h and 0 <= nx < w:
            if not bg_mask[ny, nx] and is_white[ny, nx]:
                bg_mask[ny, nx] = True
                q.append((ny, nx))

# Now alpha is 0 for background, 255 for hand, with anti-aliasing near border
final_alpha = np.ones((h, w), dtype=np.float32) * 255.0
final_alpha[bg_mask] = 0.0

# Anti-alias the 2-pixel boundary
border = binary_dilation(bg_mask, iterations=2) & ~bg_mask
for y, x in np.argwhere(border):
    # calculate distance to pure white
    val = (255.0 - min_c[y, x]) / 25.0
    final_alpha[y, x] = np.clip(val, 0.2, 1.0) * 255.0

data[:, :, 3] = final_alpha
out_img = Image.fromarray(data.astype(np.uint8))
out_img.save(dst_path, "PNG")
print("SUCCESS: Saved transparent 3D hero guide hand to", dst_path)
