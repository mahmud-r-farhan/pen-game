import os
from PIL import Image

LOGO_PATH = r"C:\Users\coder\.gemini\antigravity-ide\brain\4ecb1cfe-4fcf-4822-be41-d98fca4908bd\kolom_minimal_logo_1792443709510.jpg"
SPLASH_PATH = r"C:\Users\coder\.gemini\antigravity-ide\brain\4ecb1cfe-4fcf-4822-be41-d98fca4908bd\kolom_minimal_splash_1792443736087.jpg"

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RES_DIR = os.path.join(BASE_DIR, "android", "app", "src", "main", "res")
ASSETS_DIR = os.path.join(BASE_DIR, "assets")
WEB_DIR = os.path.join(BASE_DIR, "web")

def process_branding():
    print("Loading minimalist logo from:", LOGO_PATH)
    logo_img = Image.open(LOGO_PATH).convert("RGBA")
    
    # 1. Save 512x512 Master Logo
    os.makedirs(os.path.join(ASSETS_DIR, "icon"), exist_ok=True)
    master_logo_512 = logo_img.resize((512, 512), Image.Resampling.LANCZOS)
    master_logo_512.save(os.path.join(ASSETS_DIR, "icon", "app_logo.png"), "PNG")
    print("Saved master logo: assets/icon/app_logo.png")

    # 2. Android Mipmap Icons
    mipmap_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in mipmap_sizes.items():
        folder_path = os.path.join(RES_DIR, folder)
        os.makedirs(folder_path, exist_ok=True)
        icon_resized = logo_img.resize((size, size), Image.Resampling.LANCZOS)
        out_path = os.path.join(folder_path, "ic_launcher.png")
        icon_resized.save(out_path, "PNG")
        print(f"Saved Android icon ({size}x{size}): {folder}/ic_launcher.png")

    # 3. Web Icons
    web_icons = {
        "favicon.png": 64,
        "icons/Icon-192.png": 192,
        "icons/Icon-512.png": 512,
        "icons/Icon-maskable-192.png": 192,
        "icons/Icon-maskable-512.png": 512,
    }
    for subpath, size in web_icons.items():
        out_path = os.path.join(WEB_DIR, subpath)
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        web_resized = logo_img.resize((size, size), Image.Resampling.LANCZOS)
        web_resized.save(out_path, "PNG")
        print(f"Saved Web icon ({size}x{size}): web/{subpath}")

    # 4. Splash Screen
    print("Loading minimalist splash art from:", SPLASH_PATH)
    splash_img = Image.open(SPLASH_PATH).convert("RGB")
    
    # Android drawable-nodpi for full-bleed crisp native splash
    nodpi_dir = os.path.join(RES_DIR, "drawable-nodpi")
    os.makedirs(nodpi_dir, exist_ok=True)
    splash_1080 = splash_img.resize((1080, 1920), Image.Resampling.LANCZOS)
    splash_nodpi_path = os.path.join(nodpi_dir, "splash_background.png")
    splash_1080.save(splash_nodpi_path, "PNG", optimize=True)
    print("Saved Android native splash: drawable-nodpi/splash_background.png")

    # Also save in assets/images for in-app Flutter reference
    os.makedirs(os.path.join(ASSETS_DIR, "images"), exist_ok=True)
    splash_1080.save(os.path.join(ASSETS_DIR, "images", "splash_art.png"), "PNG", optimize=True)
    print("Saved asset splash: assets/images/splash_art.png")

    print("Minimalist branding installation completed successfully!")

if __name__ == "__main__":
    process_branding()
