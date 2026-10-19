import os
from PIL import Image, ImageDraw

output_dir = r"c:\Users\coder\Desktop\kolomkhela\client_flutter\assets\avatars"
os.makedirs(output_dir, exist_ok=True)

# 1. Animal Avatars - refined coordinates
animal_img_path = r"C:\Users\coder\.gemini\antigravity-ide\brain\4ecb1cfe-4fcf-4822-be41-d98fca4908bd\new_animal_avatars_1792434443279.jpg"
img_animals = Image.open(animal_img_path).convert("RGBA")
W, H = img_animals.size

# Animal definitions with exact bounding radii:
animals = [
    ("avatar_fox", 174, 182, 134),
    ("avatar_polar_bear", 502, 182, 134),
    ("avatar_penguin", 828, 182, 134),
    ("avatar_deer", 174, 502, 134),
    ("avatar_seal", 502, 502, 134),
    ("avatar_owl", 828, 502, 134),
    ("avatar_red_panda", 146, 836, 108),
    ("avatar_shiba", 380, 836, 108),
    ("avatar_calico_cat", 618, 836, 108),
    ("avatar_otter", 854, 836, 108),
]

for name, cx, cy, r in animals:
    box = (cx - r, cy - r, cx + r, cy + r)
    cropped = img_animals.crop(box)
    
    mask = Image.new('L', (r * 4, r * 4), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, r * 4, r * 4), fill=255)
    mask = mask.resize((r * 2, r * 2), Image.Resampling.LANCZOS)
    
    avatar = Image.new('RGBA', (r * 2, r * 2), (0, 0, 0, 0))
    avatar.paste(cropped, (0, 0), mask=mask)
    avatar = avatar.resize((256, 256), Image.Resampling.LANCZOS)
    
    out_path = os.path.join(output_dir, f"{name}.webp")
    avatar.save(out_path, "WEBP", quality=95)
    print(f"Saved {name}.webp")

# 2. Cartoon Humans - 7x7 grid
# In 1024x1024, the circles are arranged in 7 rows and 7 cols
# Row centers: y = [90, 226, 364, 502, 640, 778, 916]
# Col centers: x = [90, 226, 364, 502, 640, 778, 916]
# Radius of each circle: r = 58px

human_img_path = r"C:\Users\coder\.gemini\antigravity-ide\brain\4ecb1cfe-4fcf-4822-be41-d98fca4908bd\new_cartoon_avatars_1792434417822.jpg"
img_humans = Image.open(human_img_path).convert("RGBA")

col_centers = [92, 228, 364, 500, 636, 772, 908]
row_centers = [94, 230, 366, 502, 638, 774, 910]
r = 58  # perfect fit inside the colored badge without clipping neighboring badges

cartoon_defs = [
    # (row, col, id_name)
    (0, 0, "avatar_girl_afro"),
    (0, 1, "avatar_boy_headset"),
    (0, 2, "avatar_girl_hijab"),
    (0, 3, "avatar_boy_cap"),
    (0, 5, "avatar_boy_hoodie"),
    (1, 0, "avatar_girl_pink_hair"),
    (1, 1, "avatar_gamer_glasses"),
    (1, 2, "avatar_girl_bun"),
    (1, 4, "avatar_boy_anime"),
    (1, 6, "avatar_boy_blonde"),
    (2, 0, "avatar_boy_beanie"),
    (2, 1, "avatar_girl_cap_glasses"),
    (2, 2, "avatar_gamer_pro_boy"),
    (2, 3, "avatar_pro_streamer"),
    (3, 1, "avatar_boy_curly"),
    (3, 3, "avatar_dj_headset"),
    (3, 4, "avatar_boy_jacket"),
    (3, 5, "avatar_girl_blonde"),
    (4, 2, "avatar_boy_winter_hat"),
    (4, 4, "avatar_girl_blue_hair"),
    (5, 2, "avatar_girl_casual"),
    (5, 4, "avatar_boy_nerd_glasses"),
    (5, 6, "avatar_girl_cyan_hair"),
    (6, 1, "avatar_girl_wavy"),
]

for row, col, name in cartoon_defs:
    cx = col_centers[col]
    cy = row_centers[row]
    
    box = (cx - r, cy - r, cx + r, cy + r)
    cropped = img_humans.crop(box)
    
    mask = Image.new('L', (r * 4, r * 4), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, r * 4, r * 4), fill=255)
    mask = mask.resize((r * 2, r * 2), Image.Resampling.LANCZOS)
    
    avatar = Image.new('RGBA', (r * 2, r * 2), (0, 0, 0, 0))
    avatar.paste(cropped, (0, 0), mask=mask)
    avatar = avatar.resize((256, 256), Image.Resampling.LANCZOS)
    
    out_path = os.path.join(output_dir, f"{name}.webp")
    avatar.save(out_path, "WEBP", quality=95)
    print(f"Saved {name}.webp")

print("All refined avatars saved cleanly!")
