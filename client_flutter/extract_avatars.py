import os
from PIL import Image, ImageDraw

output_dir = r"c:\Users\coder\Desktop\kolomkhela\client_flutter\assets\avatars"
os.makedirs(output_dir, exist_ok=True)

# 1. Process Animal Avatars (new_animal_avatars_1792434443279.jpg)
animal_img_path = r"C:\Users\coder\.gemini\antigravity-ide\brain\4ecb1cfe-4fcf-4822-be41-d98fca4908bd\new_animal_avatars_1792434443279.jpg"
img_animals = Image.open(animal_img_path).convert("RGBA")
W, H = img_animals.size

# Animal definitions (approx center (cx, cy) and radius r relative to 1024x1024)
# Row 1 (y ~ 190): 3 circles at x ~ 180, 512, 840, r ~ 140
# Row 2 (y ~ 512): 3 circles at x ~ 180, 512, 840, r ~ 140
# Row 3 (y ~ 840): 4 circles at x ~ 150, 390, 634, 874, r ~ 110

animals = [
    ("avatar_fox", 175, 180, 140),
    ("avatar_polar_bear", 500, 180, 140),
    ("avatar_penguin", 825, 180, 140),
    ("avatar_deer", 175, 500, 140),
    ("avatar_seal", 500, 500, 140),
    ("avatar_owl", 825, 500, 140),
    ("avatar_red_panda", 145, 830, 110),
    ("avatar_shiba", 380, 830, 110),
    ("avatar_calico_cat", 615, 830, 110),
    ("avatar_otter", 850, 830, 110),
]

for name, cx_p, cy_p, r_p in animals:
    cx = int(cx_p * W / 1024.0)
    cy = int(cy_p * H / 1024.0)
    r = int(r_p * W / 1024.0)
    
    # Crop square
    box = (cx - r, cy - r, cx + r, cy + r)
    cropped = img_animals.crop(box)
    
    # Create circular mask with antialiasing
    mask = Image.new('L', (r * 2 * 2, r * 2 * 2), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, r * 4, r * 4), fill=255)
    mask = mask.resize((r * 2, r * 2), Image.Resampling.LANCZOS)
    
    avatar = Image.new('RGBA', (r * 2, r * 2), (0, 0, 0, 0))
    avatar.paste(cropped, (0, 0), mask=mask)
    avatar = avatar.resize((256, 256), Image.Resampling.LANCZOS)
    
    out_path = os.path.join(output_dir, f"{name}.webp")
    avatar.save(out_path, "WEBP", quality=95)
    print(f"Saved {out_path}")

# 2. Process Cartoon Humans (new_cartoon_avatars_1792434417822.jpg)
# 7 rows x 7 cols
human_img_path = r"C:\Users\coder\.gemini\antigravity-ide\brain\4ecb1cfe-4fcf-4822-be41-d98fca4908bd\new_cartoon_avatars_1792434417822.jpg"
img_humans = Image.open(human_img_path).convert("RGBA")
W, H = img_humans.size

# In a 7x7 grid:
# margin ~ 40, cell size ~ 135
# Let's pick 16 prominent, diverse avatars across the grid
selected_cells = [
    # (row, col, id_name)
    (0, 0, "avatar_girl_afro"),
    (0, 1, "avatar_boy_headset"),
    (0, 2, "avatar_girl_hijab"),
    (0, 3, "avatar_boy_cap"),
    (1, 0, "avatar_girl_pink_hair"),
    (1, 1, "avatar_gamer_glasses"),
    (1, 2, "avatar_girl_bun"),
    (1, 5, "avatar_boy_smiling"),
    (2, 0, "avatar_boy_beanie"),
    (2, 1, "avatar_girl_cap_glasses"),
    (2, 3, "avatar_pro_streamer"),
    (3, 3, "avatar_dj_headset"),
    (3, 5, "avatar_girl_blonde"),
    (4, 2, "avatar_boy_winter_hat"),
    (4, 4, "avatar_girl_blue_hair"),
    (5, 6, "avatar_girl_cyan_hair"),
]

# Calculate grid coordinates
col_step = W / 7.0
row_step = H / 7.0
radius = int((col_step * 0.44))

for row, col, name in selected_cells:
    cx = int((col + 0.5) * col_step)
    cy = int((row + 0.5) * row_step)
    r = radius
    
    box = (cx - r, cy - r, cx + r, cy + r)
    cropped = img_humans.crop(box)
    
    mask = Image.new('L', (r * 2 * 2, r * 2 * 2), 0)
    draw = ImageDraw.Draw(mask)
    draw.ellipse((0, 0, r * 4, r * 4), fill=255)
    mask = mask.resize((r * 2, r * 2), Image.Resampling.LANCZOS)
    
    avatar = Image.new('RGBA', (r * 2, r * 2), (0, 0, 0, 0))
    avatar.paste(cropped, (0, 0), mask=mask)
    avatar = avatar.resize((256, 256), Image.Resampling.LANCZOS)
    
    out_path = os.path.join(output_dir, f"{name}.webp")
    avatar.save(out_path, "WEBP", quality=95)
    print(f"Saved {out_path}")

print("All avatars extracted successfully!")
