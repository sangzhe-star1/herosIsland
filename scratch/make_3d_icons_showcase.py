#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageFont

ICONS_DIR = "/opt/heroesIsland/assets/icons/3d"
OUT_PATH = "/Users/xhzhou/.gemini/antigravity/brain/2a762f9a-01f0-43fc-b355-5a304be9bd77/showcase_3d_icons_upgrades.png"

NEW_ICONS = [
    # Row 1: Sorting & Hazards
    ["ball", "picture_book", "comic", "socks", "hat", "knife", "matches", "scissors"],
    # Row 2: Hazards & Home
    ["medicine", "socket", "pillow", "plaster", "berries", "fish", "blanket", "scarf"],
    # Row 3: Wardrobe & Accessories
    ["party_hat", "sunglasses", "cape_red", "wings", "cowboy_hat", "bandana", "vest", "dress"],
    # Row 4: Magic & Mounts
    ["star_robe", "cap_cloud", "board", "cloud", "trail", "halo", "sticker_book", "pose"],
    # Row 5: Skills & Defense
    ["tower", "goo", "spread", "power", "slow", "split", "blast", "wave"],
    # Row 6: Farm, Furniture & Tools
    ["spin", "lamp", "sofa", "shelf", "soil", "plank", "dish", "ear"],
]

W, H = 1920, 1440
canvas = Image.new("RGBA", (W, H), (20, 24, 36, 255))
draw = ImageDraw.Draw(canvas)

# Clean soft gradient background
for y in range(H):
    r = int(22 + (12 - 22) * (y / H))
    g = int(27 + (16 - 27) * (y / H))
    b = int(42 + (28 - 42) * (y / H))
    draw.line([(0, y), (W, y)], fill=(r, g, b, 255))

# Title
try:
    font_title = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 40)
    font_sub = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 22)
    font_lbl = ImageFont.truetype("/System/Library/Fonts/Hiragino Sans GB.ttc", 16)
except Exception:
    font_title = font_sub = font_lbl = None

draw.text((W//2, 50), "3D Glossy Icon Library Upgrades (全量 3D 图标库升级)", fill=(255, 255, 255, 255), anchor="mm", font=font_title)
draw.text((W//2, 92), "48 款全新 Blender 渲染 3D 拟真图标 · 覆盖物品分类、生活安全、衣橱装扮、技能升级与农场工坊", fill=(175, 200, 245, 240), anchor="mm", font=font_sub)

card_w, card_h = 205, 190
pad_x = (W - (8 * card_w + 7 * 20)) // 2
start_y = 135

for r_idx, row in enumerate(NEW_ICONS):
    y = start_y + r_idx * (card_h + 18)
    for c_idx, icon_name in enumerate(row):
        x = pad_x + c_idx * (card_w + 20)
        
        # Card Background
        card_rect = [x, y, x + card_w, y + card_h]
        draw.rounded_rectangle(card_rect, radius=18, fill=(35, 42, 60, 220), outline=(65, 80, 115, 255), width=2)
        
        # Inner glow ring
        draw.rounded_rectangle([x+4, y+4, x+card_w-4, y+card_h-4], radius=14, outline=(48, 62, 92, 120), width=1)
        
        # Load and paste 3D icon
        icon_file = os.path.join(ICONS_DIR, f"{icon_name}.png")
        if os.path.exists(icon_file):
            im = Image.open(icon_file).convert("RGBA")
            im = im.resize((130, 130), Image.Resampling.LANCZOS)
            canvas.alpha_composite(im, (x + (card_w - 130)//2, y + 10))
        
        # Label text
        draw.text((x + card_w//2, y + card_h - 22), icon_name, fill=(225, 235, 255, 240), anchor="mm", font=font_lbl)

canvas.save(OUT_PATH, "PNG")
print("Saved 3D Icons Showcase to:", OUT_PATH)
