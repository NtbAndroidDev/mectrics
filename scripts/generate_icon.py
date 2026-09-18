import os
import math
import subprocess
from PIL import Image, ImageDraw, ImageFilter

def create_superellipse_mask(size, radius):
    """Creates a smooth anti-aliased squircle mask."""
    scale = 4
    large_size = size * scale
    large_radius = radius * scale
    mask = Image.new("L", (large_size, large_size), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle([0, 0, large_size - 1, large_size - 1], radius=large_radius, fill=255)
    return mask.resize((size, size), Image.Resampling.LANCZOS)

def create_premium_mectrics_icon(size=1024):
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    
    pad = int(size * 0.09)
    sq_size = size - (pad * 2)
    radius = int(sq_size * 0.224)
    
    # 1. Realistic Multi-layer macOS Drop Shadow
    shadow_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_img)
    # Ambient shadow
    s_draw.rounded_rectangle([pad + 6, pad + 14, size - pad - 6, size - pad + 18], radius=radius, fill=(0, 0, 0, 110))
    shadow_img = shadow_img.filter(ImageFilter.GaussianBlur(int(size * 0.045)))
    img.paste(shadow_img, (0, 0), shadow_img)
    
    # Direct drop shadow
    shadow_img2 = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s2_draw = ImageDraw.Draw(shadow_img2)
    s2_draw.rounded_rectangle([pad + 4, pad + 24, size - pad - 4, size - pad + 28], radius=radius, fill=(0, 0, 0, 160))
    shadow_img2 = shadow_img2.filter(ImageFilter.GaussianBlur(int(size * 0.025)))
    img.alpha_composite(shadow_img2)
    
    # 2. Main Squircle Canvas
    squircle = Image.new("RGBA", (sq_size, sq_size), (0, 0, 0, 0))
    sq_draw = ImageDraw.Draw(squircle)
    
    # Background gradient: Ultra deep slate navy to dark graphite
    for y in range(sq_size):
        ratio = y / sq_size
        r = int(24 - ratio * 14)
        g = int(28 - ratio * 16)
        b = int(40 - ratio * 20)
        sq_draw.line([(0, y), (sq_size, y)], fill=(r, g, b, 255))
        
    # Radial sheen highlight on top-center
    cx, cy = sq_size // 2, int(sq_size * 0.42)
    sheen = Image.new("RGBA", (sq_size, sq_size), (0, 0, 0, 0))
    sh_draw = ImageDraw.Draw(sheen)
    max_dist = int(sq_size * 0.6)
    for i in range(max_dist, 0, -4):
        alpha = int((1.0 - (i / max_dist)) * 28)
        sh_draw.ellipse([cx - i, cy - int(i * 0.8), cx + i, cy + int(i * 0.8)], fill=(255, 255, 255, alpha))
    sheen = sheen.filter(ImageFilter.GaussianBlur(int(sq_size * 0.05)))
    squircle.alpha_composite(sheen)
    
    # Grid pattern in background (high-tech subtle monitor grid)
    grid_img = Image.new("RGBA", (sq_size, sq_size), (0, 0, 0, 0))
    g_draw = ImageDraw.Draw(grid_img)
    step = int(sq_size * 0.075)
    for x in range(0, sq_size, step):
        g_draw.line([(x, 0), (x, sq_size)], fill=(255, 255, 255, 6), width=1)
    for y in range(0, sq_size, step):
        g_draw.line([(0, y), (sq_size, y)], fill=(255, 255, 255, 6), width=1)
    squircle.alpha_composite(grid_img)
    
    # Mask squircle
    mask = create_superellipse_mask(sq_size, radius)
    
    # 3. Inner Bevel Highlight & Rim (Apple style frosted edge)
    border_img = Image.new("RGBA", (sq_size, sq_size), (0, 0, 0, 0))
    b_draw = ImageDraw.Draw(border_img)
    b_draw.rounded_rectangle([1, 1, sq_size - 2, sq_size - 2], radius=radius, outline=(255, 255, 255, 50), width=int(sq_size * 0.008))
    # Top highlight line
    b_draw.rounded_rectangle([2, 2, sq_size - 3, sq_size - 3], radius=radius, outline=(255, 255, 255, 30), width=int(sq_size * 0.004))
    squircle.alpha_composite(border_img)
    
    # 4. Center Metrics Gauge & Pulse Waveform Graphic
    center_img = Image.new("RGBA", (sq_size, sq_size), (0, 0, 0, 0))
    c_draw = ImageDraw.Draw(center_img)
    
    gcx, gcy = sq_size // 2, sq_size // 2
    gauge_r = int(sq_size * 0.31)
    track_w = int(sq_size * 0.034)
    
    # Dark circular track
    c_draw.arc([gcx - gauge_r, gcy - gauge_r, gcx + gauge_r, gcy + gauge_r],
               start=135, end=405, fill=(45, 55, 72, 220), width=track_w)
    
    # Ticks along the gauge arc
    for deg in range(135, 410, 15):
        rad = math.radians(deg)
        r_inner = gauge_r - track_w - int(sq_size * 0.02)
        r_outer = r_inner + int(sq_size * 0.025)
        x1 = gcx + r_inner * math.cos(rad)
        y1 = gcy + r_inner * math.sin(rad)
        x2 = gcx + r_outer * math.cos(rad)
        y2 = gcy + r_outer * math.sin(rad)
        c_draw.line([(x1, y1), (x2, y2)], fill=(255, 255, 255, 45), width=2)
        
    # Active Coral Gauge Arc (135 to 335 degrees)
    # Glow layer
    glow_arc = Image.new("RGBA", (sq_size, sq_size), (0, 0, 0, 0))
    ga_draw = ImageDraw.Draw(glow_arc)
    ga_draw.arc([gcx - gauge_r, gcy - gauge_r, gcx + gauge_r, gcy + gauge_r],
                start=135, end=335, fill=(250, 92, 115, 180), width=track_w + 14)
    glow_arc = glow_arc.filter(ImageFilter.GaussianBlur(int(sq_size * 0.022)))
    center_img.alpha_composite(glow_arc)
    
    # Sharp active arc
    c_draw.arc([gcx - gauge_r, gcy - gauge_r, gcx + gauge_r, gcy + gauge_r],
               start=135, end=335, fill=(250, 92, 115, 255), width=track_w)
    
    # Needle / Current point indicator
    head_rad = math.radians(335)
    hx = gcx + gauge_r * math.cos(head_rad)
    hy = gcy + gauge_r * math.sin(head_rad)
    head_r = int(track_w * 0.85)
    c_draw.ellipse([hx - head_r, hy - head_r, hx + head_r, hy + head_r], fill=(255, 255, 255, 255))
    c_draw.ellipse([hx - head_r//2, hy - head_r//2, hx + head_r//2, hy + head_r//2], fill=(250, 92, 115, 255))
    
    # Center live pulse sparkline waveform
    pts = [
        (gcx - int(sq_size * 0.22), gcy + int(sq_size * 0.06)),
        (gcx - int(sq_size * 0.12), gcy + int(sq_size * 0.06)),
        (gcx - int(sq_size * 0.06), gcy - int(sq_size * 0.08)),
        (gcx - int(sq_size * 0.01), gcy + int(sq_size * 0.12)),
        (gcx + int(sq_size * 0.05), gcy - int(sq_size * 0.15)),
        (gcx + int(sq_size * 0.11), gcy + int(sq_size * 0.06)),
        (gcx + int(sq_size * 0.22), gcy + int(sq_size * 0.06))
    ]
    
    # Waveform deep glow
    wave_glow = Image.new("RGBA", (sq_size, sq_size), (0, 0, 0, 0))
    wg_draw = ImageDraw.Draw(wave_glow)
    wg_draw.line(pts, fill=(250, 92, 115, 200), width=int(sq_size * 0.045), joint="curve")
    wave_glow = wave_glow.filter(ImageFilter.GaussianBlur(int(sq_size * 0.02)))
    center_img.alpha_composite(wave_glow)
    
    # Waveform sharp line
    c_draw.line(pts, fill=(255, 245, 247, 255), width=int(sq_size * 0.024), joint="curve")
    
    # Data node dots on peaks
    p_peak = pts[4]
    c_draw.ellipse([p_peak[0] - int(sq_size*0.02), p_peak[1] - int(sq_size*0.02),
                    p_peak[0] + int(sq_size*0.02), p_peak[1] + int(sq_size*0.02)], fill=(250, 92, 115, 255))
    c_draw.ellipse([p_peak[0] - int(sq_size*0.01), p_peak[1] - int(sq_size*0.01),
                    p_peak[0] + int(sq_size*0.01), p_peak[1] + int(sq_size*0.01)], fill=(255, 255, 255, 255))
    
    squircle.alpha_composite(center_img)
    
    # Composite squircle onto shadow canvas with mask
    img.paste(squircle, (pad, pad), mask)
    
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
    
    master = create_premium_mectrics_icon(1024)
    master.save("AppIcon_1024.png")
    
    for base_size, scale in sizes:
        px = base_size * scale
        resized = master.resize((px, px), Image.Resampling.LANCZOS)
        if scale == 1:
            name = f"icon_{base_size}x{base_size}.png"
        else:
            name = f"icon_{base_size}x{base_size}@2x.png"
        resized.save(os.path.join(iconset_dir, name))
        
    print("Mectrics.iconset generated. Running iconutil...")
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", "AppIcon.icns"], check=True)
    subprocess.run(["rm", "-rf", iconset_dir], check=True)
    print("✅ High-end AppIcon.icns generated successfully!")

if __name__ == "__main__":
    main()
