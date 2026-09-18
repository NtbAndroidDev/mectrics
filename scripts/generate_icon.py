import os
import math
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def create_mectrics_icon(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Outer squircle padding
    pad = int(size * 0.08)
    rect = [pad, pad, size - pad, size - pad]
    corner_radius = int(size * 0.22)
    
    # Shadow
    shadow_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow_img)
    shadow_pad = pad + 10
    shadow_rect = [shadow_pad, shadow_pad + 18, size - shadow_pad, size - shadow_pad + 18]
    shadow_draw.rounded_rectangle(shadow_rect, radius=corner_radius, fill=(0, 0, 0, 140))
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(int(size * 0.035)))
    img.paste(shadow_img, (0, 0), shadow_img)
    
    # Background squircle with dark high-tech gradient
    base_sq = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sq_draw = ImageDraw.Draw(base_sq)
    sq_draw.rounded_rectangle(rect, radius=corner_radius, fill=(15, 23, 42, 255))
    
    # Gradient overlay (Deep navy to dark graphite)
    grad = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(grad)
    for y in range(rect[1], rect[3]):
        ratio = (y - rect[1]) / (rect[3] - rect[1])
        r = int(12 + ratio * 16)
        g = int(24 + ratio * 15)
        b = int(48 + ratio * 20)
        g_draw.line([(rect[0], y), (rect[2], y)], fill=(r, g, b, 255))
        
    # Mask gradient to squircle
    mask = Image.new("L", (size, size), 0)
    m_draw = ImageDraw.Draw(mask)
    m_draw.rounded_rectangle(rect, radius=corner_radius, fill=255)
    img.paste(grad, (0, 0), mask)
    
    # Subtle border highlight
    highlight = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    h_draw = ImageDraw.Draw(highlight)
    h_draw.rounded_rectangle(rect, radius=corner_radius, outline=(255, 255, 255, 35), width=int(size * 0.008))
    img.alpha_composite(highlight)
    
    # Center Gauge / Waveform Symbol
    cx, cy = size // 2, size // 2
    r_outer = int(size * 0.32)
    r_inner = int(size * 0.28)
    
    # Background Track Ring
    draw.arc([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], start=135, end=405, fill=(51, 65, 85, 180), width=int(size * 0.035))
    
    # Active Cyan/Teal Arc (from 135 deg to ~330 deg)
    draw.arc([cx - r_outer, cy - r_outer, cx + r_outer, cy + r_outer], start=135, end=340, fill=(6, 182, 212, 255), width=int(size * 0.035))
    
    # Pulse / Sparkline in center
    points = [
        (cx - int(size * 0.24), cy + int(size * 0.05)),
        (cx - int(size * 0.14), cy + int(size * 0.05)),
        (cx - int(size * 0.08), cy - int(size * 0.08)),
        (cx - int(size * 0.02), cy + int(size * 0.12)),
        (cx + int(size * 0.05), cy - int(size * 0.16)),
        (cx + int(size * 0.11), cy + int(size * 0.05)),
        (cx + int(size * 0.24), cy + int(size * 0.05))
    ]
    
    # Draw glow for waveform
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(glow)
    g_draw.line(points, fill=(56, 189, 248, 160), width=int(size * 0.04), joint="curve")
    glow = glow.filter(ImageFilter.GaussianBlur(int(size * 0.02)))
    img.alpha_composite(glow)
    
    # Draw sharp waveform line
    draw.line(points, fill=(240, 249, 255, 255), width=int(size * 0.022), joint="curve")
    
    # Target dots on peaks
    p_high = points[4]
    draw.ellipse([p_high[0] - int(size*0.02), p_high[1] - int(size*0.02), p_high[0] + int(size*0.02), p_high[1] + int(size*0.02)], fill=(56, 189, 248, 255))
    draw.ellipse([p_high[0] - int(size*0.01), p_high[1] - int(size*0.01), p_high[0] + int(size*0.01), p_high[1] + int(size*0.01)], fill=(255, 255, 255, 255))
    
    return img

def main():
    iconset_dir = "Mectrics.iconset"
    os.makedirs(iconset_dir, exist_ok=True)
    
    sizes = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2),
    ]
    
    master = create_mectrics_icon(1024)
    
    for base_size, scale in sizes:
        px = base_size * scale
        resized = master.resize((px, px), Image.Resampling.LANCZOS)
        if scale == 1:
            name = f"icon_{base_size}x{base_size}.png"
        else:
            name = f"icon_{base_size}x{base_size}@2x.png"
        resized.save(os.path.join(iconset_dir, name))
        
    print("Iconset generated. Creating AppIcon.icns...")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", "AppIcon.icns"], check=True)
    subprocess.run(["rm", "-rf", iconset_dir], check=True)
    print("AppIcon.icns created successfully!")

if __name__ == "__main__":
    main()
