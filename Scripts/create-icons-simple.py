#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw, ImageColor

def create_icon(size, output_path):
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    scale = size / 512
    cx = size // 2
    cy = size // 2
    
    # Draw rounded rectangle background
    radius = size // 5
    draw.rounded_rectangle([0, 0, size, size], radius, fill=(0, 0, 0, 0))
    
    # Create gradient background by drawing pixels
    for y in range(size):
        for x in range(size):
            # Calculate gradient factor (0 to 1)
            t = (x / size) * 0.7 + (y / size) * 0.3
            # Interpolate between blue and purple
            r = int(59 + (139 - 59) * t)
            g = int(130 + (92 - 130) * t)
            b = int(246 + (246 - 246) * t)
            img.putpixel((x, y), (r, g, b, 255))
    
    # Re-draw rounded rectangle mask
    mask = Image.new('L', (size, size), 0)
    draw_mask = ImageDraw.Draw(mask)
    draw_mask.rounded_rectangle([0, 0, size, size], radius, fill=255)
    
    # Apply mask
    img.putalpha(mask)
    
    # Draw white arc
    arc_radius = int(140 * scale)
    draw.arc(
        [cx - arc_radius, cy - arc_radius, cx + arc_radius, cy + arc_radius],
        start=90, end=270,
        fill='white',
        width=int(20 * scale)
    )
    
    # Draw arrow
    arrow_line_width = int(24 * scale)
    # Left line of arrow
    draw.line(
        [(cx - int(60 * scale), cy), (cx, cy - int(70 * scale))],
        fill='white',
        width=arrow_line_width,
        joint='round'
    )
    # Right line of arrow
    draw.line(
        [(cx, cy - int(70 * scale)), (cx + int(60 * scale), cy)],
        fill='white',
        width=arrow_line_width,
        joint='round'
    )
    
    # Draw circle
    circle_radius = int(20 * scale)
    circle_y = cy + int(40 * scale)
    draw.ellipse(
        [cx - circle_radius, circle_y - circle_radius, cx + circle_radius, circle_y + circle_radius],
        fill='white'
    )
    
    img.save(output_path, 'PNG')
    print(f'Saved {output_path}')

def main():
    # Create output directory
    app_icon_dir = os.path.join(
        os.path.dirname(__file__),
        '..',
        'Assets.xcassets',
        'AppIcon.appiconset'
    )
    os.makedirs(app_icon_dir, exist_ok=True)
    
    # Generate all sizes (must match AppIcon.appiconset/Contents.json)
    icons = [
        (16, 'icon_16.png'),
        (32, 'icon_16@2x.png'),
        (32, 'icon_32.png'),
        (64, 'icon_32@2x.png'),
        (128, 'icon_128.png'),
        (256, 'icon_128@2x.png'),
        (256, 'icon_256.png'),
        (512, 'icon_256@2x.png'),
        (512, 'icon_512.png'),
        (1024, 'icon_512@2x.png'),
    ]
    
    for size, filename in icons:
        output_path = os.path.join(app_icon_dir, filename)
        create_icon(size, output_path)
    
    print('All icons created successfully!')

if __name__ == '__main__':
    main()
