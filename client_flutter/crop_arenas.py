import os
from PIL import Image

src_path = r"C:\Users\coder\.gemini\antigravity-ide\brain\4ecb1cfe-4fcf-4822-be41-d98fca4908bd\.user_uploaded\media_1792435069463.jpg"
out_dir = r"c:\Users\coder\Desktop\kolomkhela\client_flutter\assets\arenas"
os.makedirs(out_dir, exist_ok=True)

img = Image.open(src_path).convert("RGBA")
W, H = img.size
print(f"Source image size: {W}x{H}")

# In 2x2 grid:
# Top-Left: Primary School
# Top-Right: High School
# Bottom-Left: College Tong Canteen
# Bottom-Right: University / Medical Grandmaster Hall

half_w = W // 2
half_h = H // 2

# We crop each quadrant with a clean margin
quadrants = [
    ("room_primary", 0, 0, half_w, half_h),
    ("room_highschool", half_w, 0, W, half_h),
    ("room_college", 0, half_h, half_w, H),
    ("room_university", half_w, half_h, W, H),
]

for name, x1, y1, x2, y2 in quadrants:
    cropped = img.crop((x1, y1, x2, y2))
    
    # Save as high quality WEBP
    out_path = os.path.join(out_dir, f"{name}.webp")
    cropped.save(out_path, "WEBP", quality=95)
    print(f"Saved {out_path} ({cropped.size[0]}x{cropped.size[1]})")

print("Crop complete!")
