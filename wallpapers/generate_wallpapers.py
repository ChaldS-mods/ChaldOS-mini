#!/usr/bin/env python3
"""
ChaldOS Pixel Wallpaper Generator
Создаёт пиксельные обои для ChaldOS в ретро-стиле.
Все обои рисуются на маленьком canvas и апскейлятся nearest-neighbor для
аутентичного пиксель-арт вида.
"""

from PIL import Image
import os
import random

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
os.makedirs(OUT_DIR, exist_ok=True)

PALETTES = {
    "retro": [
        (0x0f, 0x0f, 0x23),  # dark blue-black
        (0x56, 0x54, 0x7a),  # muted purple
        (0x7e, 0x57, 0x82),  # dusty purple
        (0xc8, 0x9b, 0x7b),  # tan
        (0xeb, 0xd4, 0xa2),  # light cream
        (0xdf, 0xb9, 0x7a),  # gold
        (0xac, 0x8e, 0x5c),  # muted gold
        (0x59, 0x6b, 0x3b),  # olive
        (0x31, 0x3b, 0x24),  # dark green
        (0x8f, 0x6e, 0x4b),  # brown
    ],
    "terminal": [
        (0x0a, 0x0a, 0x0a),  # black
        (0x00, 0x80, 0x00),  # dark green
        (0x00, 0xff, 0x00),  # bright green
        (0x33, 0xff, 0x33),  # light green
        (0xcc, 0xff, 0xcc),  # very light green
        (0x00, 0x50, 0x00),  # deep green
        (0x22, 0x22, 0x22),  # dark grey
        (0x00, 0x60, 0x30),  # teal green
    ],
    "sunset": [
        (0x1a, 0x0a, 0x2e),  # deep purple
        (0x3d, 0x1c, 0x4c),  # dark plum
        (0x6b, 0x2e, 0x55),  # plum
        (0xa8, 0x44, 0x52),  # rusty red
        (0xdc, 0x6b, 0x4d),  # orange-red
        (0xf0, 0xa5, 0x4e),  # orange
        (0xf7, 0xd4, 0x6c),  # yellow
        (0xff, 0xf0, 0xb3),  # light yellow
        (0x2c, 0x1b, 0x3d),  # dark purple
    ],
    "cyber": [
        (0x00, 0x00, 0x00),  # black
        (0xff, 0x00, 0x80),  # hot pink
        (0x00, 0xff, 0xff),  # cyan
        (0x7b, 0x2d, 0x8e),  # purple
        (0x20, 0x00, 0x60),  # dark blue
        (0xff, 0x80, 0x00),  # orange
        (0x40, 0x00, 0x80),  # deep purple
        (0x00, 0x60, 0x80),  # teal
    ],
    "forest": [
        (0x0d, 0x1b, 0x0e),  # very dark green
        (0x1a, 0x33, 0x1a),  # dark forest
        (0x2d, 0x5a, 0x27),  # forest
        (0x4a, 0x7c, 0x3e),  # medium green
        (0x6b, 0x8e, 0x23),  # olive
        (0x8f, 0xb0, 0x4a),  # light green
        (0xbc, 0xce, 0x6a),  # pale green
        (0x5c, 0x4a, 0x2a),  # brown
        (0x8b, 0x6b, 0x3d),  # light brown
        (0xa8, 0x8b, 0x5a),  # tan
        (0xc4, 0xa8, 0x6b),  # light tan
    ],
    "frost": [
        (0x0a, 0x12, 0x20),  # deep navy
        (0x1a, 0x2a, 0x40),  # dark blue
        (0x3a, 0x5a, 0x70),  # steel blue
        (0x6a, 0x8a, 0xa0),  # slate blue
        (0x8a, 0xba, 0xd0),  # light blue
        (0xba, 0xda, 0xe8),  # sky blue
        (0xda, 0xea, 0xf4),  # pale blue
        (0xf0, 0xf8, 0xff),  # ice white
        (0xc0, 0xd0, 0xe0),  # silver blue
    ],
}


def scale_pixel_art(img, scale_factor):
    """Апскейлит изображение nearest-neighbor для пиксельного вида."""
    w, h = img.size
    return img.resize((w * scale_factor, h * scale_factor), Image.NEAREST)


def draw_pixel(canvas, x, y, color, scale=1):
    """Рисует один пиксель на canvas (PIL Image)."""
    if x < 0 or y < 0 or x >= canvas.width // scale or y >= canvas.height // scale:
        return
    for dy in range(scale):
        for dx in range(scale):
            px = x * scale + dx
            py = y * scale + dy
            if 0 <= px < canvas.width and 0 <= py < canvas.height:
                canvas.putpixel((px, py), color)


def fill_rect(canvas, x, y, w, h, color, scale=1):
    """Заливает прямоугольник."""
    for dy in range(h):
        for dx in range(w):
            draw_pixel(canvas, x + dx, y + dy, color, scale)


def draw_text_pixel(canvas, text, x, y, color, scale=1, font_data=None):
    """Рисует простой пиксельный текст."""
    if font_data is None:
        font_data = FONT_5X7
    spacing = 1
    x_pos = x
    for char in text:
        if char == ' ':
            x_pos += 4 + spacing
            continue
        if ord(char) in font_data:
            glyph = font_data[ord(char)]
            for gy, row in enumerate(glyph):
                for gx in range(5):
                    if row & (1 << (4 - gx)):
                        draw_pixel(canvas, x_pos + gx, y + gy, color, scale)
            x_pos += 5 + spacing


# --- 1. RETRO TERMINAL ---
def wallpaper_terminal(width=1920, height=1080, palette_name="terminal"):
    """Терминальный стиль — зелёный текст на чёрном фоне, как в Matrix."""
    pal = PALETTES[palette_name]
    scale = 4
    cw, ch = width // scale, height // scale

    img = Image.new("RGB", (width, height), pal[0])
    canvas = Image.new("RGB", (cw, ch), pal[0])

    # Линии сканирования
    for y in range(0, ch, 2):
        for x in range(cw):
            if canvas.getpixel((x, y)) == pal[0]:
                canvas.putpixel((x, y), (0x0d, 0x0d, 0x0d))

    # Терминальный边框
    border_color = pal[2]
    for x in range(cw):
        canvas.putpixel((x, 2), border_color)
        canvas.putpixel((x, ch - 3), border_color)
    for y in range(ch):
        canvas.putpixel((2, y), border_color)
        canvas.putpixel((cw - 3, y), border_color)

    # Угловые скобки
    corner_chars = [
        (3, 3, 0x1f), (cw - 9, 3, 0x1e),  # top-left, top-right
        (3, ch - 9, 0x18), (cw - 9, ch - 9, 0x19),  # bottom-left, bottom-right
    ]
    for cx, cy, char_code in corner_chars:
        # простой уголок
        for i in range(8):
            draw_pixel(canvas, cx + i, cy, pal[2])
            draw_pixel(canvas, cx, cy + i, pal[2])

    # Строки "кода" — падающие столбцы
    random.seed(42)
    columns = cw // 7
    for col in range(columns):
        cx = col * 7 + 4
        start_y = random.randint(0, ch // 2)
        length = random.randint(5, ch // 3)
        speed = random.random() * 0.5
        offset = random.randint(0, 20)
        for i in range(length):
            ly = (start_y + int(i * 1.3) + offset) % ch
            bright = random.random()
            if bright > 0.8:
                c = pal[3]  # bright
            elif bright > 0.4:
                c = pal[2]  # medium
            else:
                c = pal[1]  # dark
            canvas.putpixel((cx, ly), c)

    # ASCII art: логотип ChaldOS
    logo = [
        "  CCCCC  H   H   AAA   L      DDDD   OOO   SSS  ",
        " C       H   H  A   A  L      D   D O   O S     ",
        " C       HHHHH  AAAAA  L      D   D O   O  SSS  ",
        " C       H   H  A   A  L      D   D O   O     S ",
        "  CCCCC  H   H  A   A  LLLLL  DDDD   OOO   SSS  ",
    ]
    logo_start_x = (cw - len(logo[0])) // 2
    logo_start_y = ch // 3
    for ly, line in enumerate(logo):
        for lx, char in enumerate(line):
            if char != ' ':
                draw_pixel(canvas, logo_start_x + lx, logo_start_y + ly, pal[3])

    # Подпись внизу
    footer = "> CHALDOS v1.0 — PIXEL TERMINAL     "
    draw_text_pixel(canvas, footer, 6, ch - 7, pal[2])

    # Верхний заголовок
    header = "CHALDOS TERMINAL v1.0 — [PIXEL MODE]"
    draw_text_pixel(canvas, header, 6, 5, pal[2])

    img = scale_pixel_art(canvas, scale)
    return img


# --- 2. MOUNTAIN SUNSET ---
def wallpaper_mountains(width=1920, height=1080, palette_name="sunset"):
    """Пиксельные горы на закате."""
    pal = PALETTES[palette_name]
    scale = 6
    cw, ch = width // scale, height // scale

    canvas = Image.new("RGB", (cw, ch), pal[0])

    # Небо — градиент (снизу вверх)
    for y in range(ch * 3 // 4):
        t = y / (ch * 3 // 4)
        if t < 0.3:
            c = pal[0]
        elif t < 0.5:
            idx = 0
            c = pal[idx]
        elif t < 0.65:
            c = pal[1]
        elif t < 0.75:
            c = pal[2]
        elif t < 0.85:
            c = pal[3]
        else:
            c = pal[4]
        color_idx = min(int(t * len(pal)), len(pal) - 1)
        # делаем плавнее
        if t < 0.4:
            c = pal[0]
        elif t < 0.55:
            c = pal[1]
        elif t < 0.7:
            c = pal[2]
        elif t < 0.8:
            c = pal[3]
        elif t < 0.88:
            c = pal[4]
        elif t < 0.94:
            c = pal[5]
        else:
            c = pal[6]
        fill_rect(canvas, 0, ch - 1 - y, cw, 1, c)

    # Солнце
    sun_radius = 8
    sun_x, sun_y = cw // 2, ch * 3 // 5
    for dy in range(-sun_radius, sun_radius + 1):
        for dx in range(-sun_radius, sun_radius + 1):
            if dx * dx + dy * dy <= sun_radius * sun_radius:
                dist = (dx * dx + dy * dy) ** 0.5 / sun_radius
                if dist < 0.5:
                    c = pal[7]  # центр — яркий
                elif dist < 0.75:
                    c = pal[6]
                else:
                    c = pal[5]
                draw_pixel(canvas, sun_x + dx, sun_y + dy, c)

    # Горы — несколько слоёв
    random.seed(1337)

    def draw_mountain_layer(base_y, color, height_factor, roughness):
        """Рисует слой гор."""
        peaks = []
        x = 0
        while x < cw:
            peaks.append((x, base_y - random.randint(5, max(6, int(height_factor * 20)))))
            x += random.randint(3, 8)
        peaks.append((cw - 1, base_y - random.randint(2, 5)))

        # Интерполяция пиков
        points = peaks
        for i in range(len(points) - 1):
            x1, y1 = points[i]
            x2, y2 = points[i + 1]
            for x in range(x1, x2):
                t = (x - x1) / (x2 - x1) if x2 != x1 else 0
                y = int(y1 + (y2 - y1) * t)
                # заливка от вершины до base_y
                for fill_y in range(y, base_y + 1):
                    draw_pixel(canvas, x, fill_y, color)

        # Снежные шапки (если достаточно высокие)
        for x in range(cw):
            y_found = None
            for check_y in range(base_y - int(height_factor * 15), base_y):
                if check_y >= 0 and canvas.getpixel((x, check_y)) == color:
                    # если это верхняя точка
                    if check_y == 0 or canvas.getpixel((x, check_y - 1)) != color:
                        y_found = check_y
                        break
            if y_found is not None and random.random() < 0.6:
                props = [
                    (color, 0), (pal[-1] if palette_name == "sunset" else pal[-2], 0),
                    (pal[-1] if palette_name == "sunset" else pal[-3], 0)
                ]
                snow_color = (0xf8, 0xf0, 0xe0) if palette_name == "sunset" else (0xff, 0xff, 0xff)
                # снег на вершине на 1-2 пикселя
                for sx in range(max(0, x - 1), min(cw, x + 2)):
                    for sy in range(y_found, min(ch - 1, y_found + 2)):
                        if random.random() < 0.7:
                            draw_pixel(canvas, sx, sy, snow_color)

    # Слои гор (от дальних к ближним)
    mountain_configs = [
        (ch * 2 // 3, 0.6, 4, pal[1]),     # дальние (тёмные)
        (ch * 3 // 4, 0.8, 5, pal[2]),
        (ch * 4 // 5, 1.0, 3, pal[3] if palette_name == "sunset" else pal[4]),
        (ch - 3, 0.7, 2, pal[4] if palette_name == "sunset" else pal[5]),
    ]

    for base_y, height_f, rough, color in mountain_configs:
        draw_mountain_layer(base_y, color, height_f, rough)

    # Звёзды
    random.seed(42)
    for _ in range(30):
        sx = random.randint(0, cw - 1)
        sy = random.randint(0, ch // 3)
        if random.random() < 0.5:
            canvas.putpixel((sx, sy), (0xff, 0xff, 0xcc))
        else:
            canvas.putpixel((sx, sy), (0xcc, 0xcc, 0xff))

    # Трава на переднем плане
    grass_colors = [
        (0x2a, 0x1a, 0x0a),
        (0x3a, 0x2a, 0x15),
    ]
    fill_rect(canvas, 0, ch - 3, cw, 3, grass_colors[0])
    for x in range(0, cw, 2):
        if random.random() < 0.6:
            draw_pixel(canvas, x, ch - 4, grass_colors[1])

    # Логотип CHALDOS в правом нижнем углу (маленький водяной знак)
    logo_small = "CHALDOS"
    draw_text_pixel(canvas, logo_small, cw - len(logo_small) * 7 - 5, ch - 7, pal[7] if palette_name == "sunset" else pal[-2])

    img = scale_pixel_art(canvas, scale)
    return img


# --- 3. CHALDOS LOGO ---
def wallpaper_logo(width=1920, height=1080, palette_name="retro"):
    """Большой пиксельный логотип ChaldOS по центру."""
    pal = PALETTES[palette_name]
    scale = 4
    cw, ch = width // scale, height // scale

    canvas = Image.new("RGB", (cw, ch), pal[0])

    # Фоновый градиент
    for y in range(ch):
        t = y / ch
        if t < 0.5:
            c = pal[0]
        else:
            idx = min(int((t - 0.5) * 2 * (len(pal) - 1)), len(pal) - 1)
            c = pal[idx]
        fill_rect(canvas, 0, y, cw, 1, c)

    # === Большой пиксельный логотип "C" ===
    # Рисуем большую пиксельную букву C (как символ ChaldOS)
    logo_data = [
        "  #####  ",
        " ##   ## ",
        "##       ",
        "##       ",
        "##       ",
        "##       ",
        "##       ",
        " ##   ## ",
        "  #####  ",
    ]

    logo_scale = 4  # размер "пикселя" внутри лого
    logo_w = len(logo_data[0]) * logo_scale
    logo_h = len(logo_data) * logo_scale
    logo_x = (cw - logo_w) // 2
    logo_y = (ch - logo_h) // 2 - 20

    for ly, line in enumerate(logo_data):
        for lx, char in enumerate(line):
            if char == '#':
                # Градиент внутри лого (золотой-янтарный)
                t = ly / len(logo_data)
                if t < 0.3:
                    color = pal[5]  # золотой
                elif t < 0.7:
                    color = pal[4]  # кремовый
                else:
                    color = pal[6]  # muted gold
                fill_rect(canvas,
                          logo_x + lx * logo_scale,
                          logo_y + ly * logo_scale,
                          logo_scale, logo_scale, color)

                # Обводка левой стороны
                if lx == 0 or (lx > 0 and logo_data[ly][lx - 1] == ' '):
                    fill_rect(canvas,
                              logo_x + lx * logo_scale,
                              logo_y + ly * logo_scale,
                              1, logo_scale, pal[3])
                # Обводка верхней стороны
                if ly == 0 or (ly > 0 and logo_data[ly - 1][lx] == ' '):
                    fill_rect(canvas,
                              logo_x + lx * logo_scale,
                              logo_y + ly * logo_scale,
                              logo_scale, 1, pal[3])

    # Текст под логотипом
    title = "CHALDOS"
    subtitle = "PIXEL OPERATING SYSTEM"
    ver = "v1.0.0"

    title_x = (cw - len(title) * 6) // 2
    subtitle_x = (cw - len(subtitle) * 6) // 2
    ver_x = (cw - len(ver) * 6) // 2

    draw_text_pixel(canvas, title, title_x, logo_y + logo_h + 15, pal[5])
    draw_text_pixel(canvas, subtitle, subtitle_x, logo_y + logo_h + 25, pal[3])
    draw_text_pixel(canvas, ver, ver_x, logo_y + logo_h + 35, pal[2])

    # Декоративные линии
    line_y = logo_y + logo_h + 10
    for lx in range(cw):
        if lx < cw // 2 - len(title) * 3 - 5 or lx > cw // 2 + len(title) * 3 + 5:
            if lx % 3 == 0:
                draw_pixel(canvas, lx, line_y, pal[4])
            if lx % 3 == 0:
                draw_pixel(canvas, lx, line_y + 45, pal[4])

    # Узор по краям (орнамент)
    def draw_ornament(start_x, start_y, color, variant=0):
        pattern = [
            "# # #",
            " ### ",
            "  #  ",
            " ### ",
            "# # #",
        ] if variant == 0 else [
            " ### ",
            "# # #",
            "# # #",
            "# # #",
            " ### ",
        ]
        for py, line in enumerate(pattern):
            for px, ch in enumerate(line):
                if ch == '#':
                    draw_pixel(canvas, start_x + px, start_y + py, color)

    # Угловые орнаменты
    margin = 10
    draw_ornament(margin, margin, pal[4], 0)
    draw_ornament(cw - margin - 5, margin, pal[4], 0)
    draw_ornament(margin, ch - margin - 5, pal[4], 1)
    draw_ornament(cw - margin - 5, ch - margin - 5, pal[4], 1)

    img = scale_pixel_art(canvas, scale)
    return img


# --- 4. NIGHT SKY ---
def wallpaper_night(width=1920, height=1080, palette_name="frost"):
    """Ночное небо с луной и звёздами."""
    pal = PALETTES[palette_name]
    scale = 5
    cw, ch = width // scale, height // scale

    canvas = Image.new("RGB", (cw, ch), pal[0])

    # Небо
    for y in range(ch):
        t = y / ch
        if t < 0.7:
            c = pal[0]
        elif t < 0.85:
            c = pal[1]
        else:
            c = pal[2]
        fill_rect(canvas, 0, y, cw, 1, c)

    random.seed(1234)

    # Звёзды разных размеров
    for _ in range(200):
        sx = random.randint(0, cw - 1)
        sy = random.randint(0, int(ch * 0.75))
        brightness = random.random()
        if brightness > 0.9:
            c = (0xff, 0xff, 0xff)
            draw_pixel(canvas, sx, sy, c)
            draw_pixel(canvas, sx - 1, sy, c)
            draw_pixel(canvas, sx + 1, sy, c)
            draw_pixel(canvas, sx, sy - 1, c)
            draw_pixel(canvas, sx, sy + 1, c)
        elif brightness > 0.7:
            c = (0xdd, 0xdd, 0xff)
            draw_pixel(canvas, sx, sy, c)
        else:
            c = (0x88, 0x88, 0xcc)
            draw_pixel(canvas, sx, sy, c)

    # Луна (большая, пиксельная)
    moon_x = cw * 3 // 4
    moon_y = ch // 4
    moon_r = 14

    for dy in range(-moon_r, moon_r + 1):
        for dx in range(-moon_r, moon_r + 1):
            if dx * dx + dy * dy <= moon_r * moon_r:
                # Кратерная текстура
                dist = (dx * dx + dy * dy) ** 0.5
                if dist < moon_r * 0.3:
                    c = (0xf0, 0xf0, 0xf0)
                elif dist < moon_r * 0.7:
                    c = (0xff, 0xff, 0xf0)
                else:
                    c = (0xe8, 0xe8, 0xd0)

                # Кратеры
                craters = [(4, -3, 3), (-5, 2, 2), (2, 5, 2), (-2, -6, 1.5), (7, 1, 1)]
                for cdx, cdy, cr in craters:
                    rel_dx = dx - cdx
                    rel_dy = dy - cdy
                    if rel_dx * rel_dx + rel_dy * rel_dy <= cr * cr:
                        c = (0xd0, 0xd0, 0xb8)

                draw_pixel(canvas, moon_x + dx, moon_y + dy, c)

    # Облака (полупрозрачные пиксельные облака на фоне луны)
    random.seed(5678)
    for cloud in range(3):
        cx = random.randint(0, cw)
        cy = random.randint(0, ch // 3)
        cloud_w = random.randint(20, 40)
        cloud_h = random.randint(4, 8)
        for py in range(cloud_h):
            offset = abs(py - cloud_h // 2)
            row_w = cloud_w - offset * 3
            row_x = cx + offset * 1
            for px in range(row_w):
                if random.random() < 0.6:
                    draw_pixel(canvas, row_x + px, cy + py, pal[7])

    # Пиксельный лес на переднем плане
    random.seed(9012)
    tree_colors = [pal[3], pal[4], pal[3]]
    tree_base_y = ch - 5

    # Земля
    fill_rect(canvas, 0, ch - 5, cw, 5, (0x0a, 0x15, 0x0a))

    # Деревья
    for tx in range(0, cw, 3):
        tree_h = random.randint(10, 25)
        tree_type = random.randint(0, 2)
        if tree_type == 0:
            # Сосна (треугольник)
            for level in range(tree_h):
                width_at_level = (tree_h - level) // 3 + 1
                for wx in range(-width_at_level, width_at_level + 1):
                    if random.random() < 0.85:
                        draw_pixel(canvas, tx + wx, tree_base_y - level, pal[3])
        else:
            # Лиственное (округлое)
            radius = min(tree_h // 2, 6)
            for dy in range(tree_h):
                for dx in range(-radius, radius + 1):
                    if random.random() < 0.7:
                        dist = (dx * dx + (dy - tree_h // 2) ** 2) ** 0.5
                        if dist < radius:
                            draw_pixel(canvas, tx + dx, tree_base_y - dy, pal[4])

    img = scale_pixel_art(canvas, scale)
    return img


# --- 5. CYBERPUNK GRID ---
def wallpaper_cyberpunk(width=1920, height=1080, palette_name="cyber"):
    """Синтвейв/киберпанк сетка на закате."""
    pal = PALETTES[palette_name]
    scale = 5
    cw, ch = width // scale, height // scale

    canvas = Image.new("RGB", (cw, ch), pal[3])

    # Небо (градиент)
    for y in range(ch * 3 // 5):
        t = y / (ch * 3 // 5)
        if t < 0.3:
            c = (0x0a, 0x00, 0x1a)
        elif t < 0.5:
            c = (0x15, 0x00, 0x30)
        elif t < 0.7:
            c = pal[4]
        else:
            c = pal[3]
        fill_rect(canvas, 0, y, cw, 1, c)

    # Солнце
    sun_y = ch * 2 // 5
    for y in range(sun_y, ch):
        t = (y - sun_y) / (ch - sun_y)
        if t < 0.15:
            c = pal[5]  # orange
        elif t < 0.3:
            c = pal[1]  # hot pink
        elif t < 0.5:
            c = pal[2]  # purple
        else:
            c = (0x0a, 0x00, 0x1a)
        fill_rect(canvas, 0, y, cw, 1, c)

    # Солнце (диск)
    sun_r = 10
    sun_x = cw // 2
    for dy in range(-sun_r, sun_r + 1):
        for dx in range(-sun_r, sun_r + 1):
            if dx * dx + dy * dy <= sun_r * sun_r:
                dist = (dx * dx + dy * dy) ** 0.5 / sun_r
                if dist < 0.3:
                    c = (0xff, 0xff, 0x80)
                elif dist < 0.6:
                    c = pal[5]
                elif dist < 0.8:
                    c = pal[1]
                else:
                    c = pal[2]
                draw_pixel(canvas, sun_x + dx, sun_y + dy, c)

    # Горизонт (линия)
    horizon_y = ch * 3 // 5
    fill_rect(canvas, 0, horizon_y, cw, 2, pal[2])

    # Сетка (перспективная)
    grid_color = pal[1]
    for x in range(0, cw, 6):
        # Линии к горизонту
        start_x = x
        end_x = cw // 2 + (x - cw // 2) // 4
        for y in range(horizon_y + 2, ch):
            t = (y - horizon_y) / (ch - horizon_y)
            lx = int(start_x + (end_x - start_x) * t)
            if random.random() < 0.3:
                draw_pixel(canvas, lx, y, grid_color)

    # Горизонтальные линии сетки
    for y in range(horizon_y + 5, ch, 5):
        shade = 0.3 + 0.7 * (y - horizon_y) / (ch - horizon_y)
        if random.random() < 0.4:
            continue
        for x in range(cw):
            if x % 6 < 2:
                draw_pixel(canvas, x, y, grid_color)

    # Неоновая луна в углу
    neon_x, neon_y = cw - 30, 15
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            if dx * dx + dy * dy <= 36:
                c = pal[1] if dx * dx + dy * dy > 20 else (0xff, 0x60, 0xc0)
                draw_pixel(canvas, neon_x + dx, neon_y + dy, c)

    # Текст в стиле OutRun
    title = "CHALDOS"
    draw_text_pixel(canvas, title, cw // 2 - len(title) * 3 - 3, 5, pal[1])

    subtitle = "// PIXEL_OS //"
    draw_text_pixel(canvas, subtitle, cw // 2 - len(subtitle) * 3 - 3, 14, pal[2])

    # Пальмы (силуэты)
    random.seed(42)

    def draw_palm(base_x, base_y, height):
        """Пиксельная пальма."""
        # Ствол
        for i in range(height):
            sway = int((i / height) * 2)
            draw_pixel(canvas, base_x + sway, base_y - i, (0x0a, 0x00, 0x1a))
        # Листья
        leaf_y = base_y - height
        for angle in range(-3, 4):
            for dist in range(1, 7):
                lx = base_x + int(dist * 1.5 * (angle / 3))
                ly = leaf_y - dist // 2 + abs(angle)
                if 0 <= lx < cw and 0 <= ly < ch:
                    draw_pixel(canvas, lx, ly, (0x0a, 0x00, 0x1a))

    draw_palm(30, ch - 3, 35)
    draw_palm(cw - 25, ch - 3, 30)
    draw_palm(cw // 4, ch - 3, 25)
    draw_palm(cw * 3 // 4, ch - 3, 28)

    img = scale_pixel_art(canvas, scale)
    return img


# --- 6. PIXEL FOREST ---
def wallpaper_forest(width=1920, height=1080, palette_name="forest"):
    """Пиксельный лес с глубиной и светом."""
    pal = PALETTES[palette_name]
    scale = 5
    cw, ch = width // scale, height // scale

    canvas = Image.new("RGB", (cw, ch), pal[0])

    # Небо
    sky_colors = [pal[1], pal[2], pal[3]]
    for y in range(ch // 4):
        t = y / (ch // 4)
        idx = min(int(t * len(sky_colors)), len(sky_colors) - 1)
        c = sky_colors[idx]
        fill_rect(canvas, 0, y, cw, 1, c)

    # Солнечный свет (уголок)
    light_origin_x = cw // 4
    light_origin_y = 0
    for y in range(ch // 2):
        for x in range(cw):
            dist = ((x - light_origin_x) ** 2 + y ** 2) ** 0.5
            if dist < 60 and y < ch // 3:
                brightness = max(0, 1 - dist / 60)
                r = int(pal[5][0] * brightness + pal[2][0] * (1 - brightness))
                g = int(pal[5][1] * brightness + pal[2][1] * (1 - brightness))
                b = int(pal[5][2] * brightness + pal[2][2] * (1 - brightness))
                draw_pixel(canvas, x, y, (r, g, b))

    # Дальний лес (тёмный, размытый)
    random.seed(2468)
    for x in range(0, cw, 2):
        h = random.randint(10, 25)
        for y in range(ch * 3 // 4 - h, ch * 3 // 4):
            if random.random() < 0.6:
                draw_pixel(canvas, x, y, pal[1])

    # Средний лес
    random.seed(1357)
    for x in range(0, cw, 2):
        h = random.randint(15, 35)
        for y in range(ch - h - 5, ch):
            if random.random() < 0.7:
                c = pal[2] if random.random() < 0.6 else pal[3]
                draw_pixel(canvas, x, y, c)

    # Передний план — крупные деревья
    random.seed(9753)

    def draw_big_tree(base_x, base_y, height, trunk_color, leaf_color):
        """Большое пиксельное дерево на переднем плане."""
        # Ствол
        trunk_w = 3
        for ty in range(height):
            for tx in range(-trunk_w // 2, trunk_w // 2 + 1):
                if random.random() < 0.9:
                    draw_pixel(canvas, base_x + tx, base_y - ty, trunk_color)

        # Крона (большой шар)
        crown_r = height // 3 + random.randint(1, 3)
        crown_y = base_y - height - crown_r // 2
        for dy in range(-crown_r, crown_r + 1):
            for dx in range(-crown_r, crown_r + 1):
                if dx * dx + dy * dy <= crown_r * crown_r:
                    dist = (dx * dx + dy * dy) ** 0.5
                    if dist < crown_r * 0.5:
                        c = leaf_color[0] if leaf_color else pal[5]
                    elif dist < crown_r * 0.8:
                        c = leaf_color[1] if len(leaf_color) > 1 else pal[4]
                    else:
                        c = leaf_color[2] if len(leaf_color) > 2 else pal[3]
                    draw_pixel(canvas, base_x + dx, crown_y + dy, c)

    # Большие деревья по бокам
    draw_big_tree(15, ch - 3, 40, pal[7], (pal[4], pal[3], pal[2]))
    draw_big_tree(cw - 15, ch - 3, 45, pal[7], (pal[4], pal[3], pal[2]))
    draw_big_tree(cw * 3 // 4 + 10, ch - 3, 30, pal[7], (pal[5], pal[4], pal[3]))

    # Трава и кусты на земле
    for x in range(cw):
        for y in range(ch - 3, ch):
            draw_pixel(canvas, x, y, pal[-1])
    for x in range(cw):
        if random.random() < 0.3:
            draw_pixel(canvas, x, ch - 4, pal[-2])

    # Грибы
    random.seed(1111)
    for _ in range(8):
        mx = random.randint(10, cw - 10)
        my = ch - 4
        # Ножка
        draw_pixel(canvas, mx, my, pal[8])
        draw_pixel(canvas, mx, my - 1, pal[8])
        # Шляпка
        cap_color = (0xd0, 0x50, 0x50)
        for dx in range(-2, 3):
            draw_pixel(canvas, mx + dx, my - 2, cap_color)
        draw_pixel(canvas, mx - 1, my - 3, cap_color)
        draw_pixel(canvas, mx + 1, my - 3, cap_color)

    # Логотип ChaldOS в свете
    draw_text_pixel(canvas, "CHALDOS", cw // 2 - 15, 8, pal[5])

    img = scale_pixel_art(canvas, scale)
    return img


# --- 7. PIXEL CITY ---
def wallpaper_city(width=1920, height=1080, palette_name="retro"):
    """Пиксельный городской пейзаж с закатом."""
    pal = PALETTES[palette_name]
    scale = 5
    cw, ch = width // scale, height // scale

    canvas = Image.new("RGB", (cw, ch), pal[2])

    # Небо
    for y in range(ch * 2 // 3):
        t = y / (ch * 2 // 3)
        if t < 0.2:
            c = (0x2a, 0x1a, 0x4a)
        elif t < 0.4:
            c = (0x4a, 0x2a, 0x5a)
        elif t < 0.6:
            c = pal[4]
        elif t < 0.8:
            c = pal[3]
        else:
            c = pal[4]
        fill_rect(canvas, 0, y, cw, 1, c)

    # Звёзды
    random.seed(42)
    for _ in range(50):
        sx = random.randint(0, cw - 1)
        sy = random.randint(0, ch // 3)
        if random.random() < 0.3:
            c = (0xff, 0xff, 0xff)
            draw_pixel(canvas, sx, sy, c)
            draw_pixel(canvas, sx - 1, sy, c)
            draw_pixel(canvas, sx + 1, sy, c)
        else:
            c = (0xaa, 0xaa, 0xcc)
            draw_pixel(canvas, sx, sy, c)

    # Луна
    moon_x, moon_y = cw - 25, 15
    for dy in range(-6, 7):
        for dx in range(-6, 7):
            if dx * dx + dy * dy <= 32:
                c = (0xf0, 0xe8, 0xc0) if abs(dx) > 1 or abs(dy) > 1 else (0xff, 0xf8, 0xe0)
                draw_pixel(canvas, moon_x + dx, moon_y + dy, c)

    # Город (силуэты зданий)
    buildings = []
    x = 0
    while x < cw:
        b_w = random.randint(4, 12)
        b_h = random.randint(15, 45)
        buildings.append((x, b_w, b_h))
        x += b_w + random.randint(1, 3)

    building_color = (0x15, 0x10, 0x20)
    for bx, bw, bh in buildings:
        for y in range(ch - bh, ch):
            for dx in range(bw):
                draw_pixel(canvas, bx + dx, y, building_color)
        # Окна
        for wy in range(ch - bh + 3, ch - 3, 4):
            for wx in range(bx + 1, bx + bw - 1, 3):
                if random.random() < 0.5:
                    window_bright = random.random()
                    if window_bright > 0.7:
                        wc = (0xff, 0xff, 0x80)
                    elif window_bright > 0.4:
                        wc = (0xff, 0xa0, 0x40)
                    else:
                        wc = (0x60, 0x60, 0x80)
                    draw_pixel(canvas, wx, wy, wc)

    # Передний план — улица
    road_y = ch - 4
    fill_rect(canvas, 0, road_y, cw, 4, (0x0a, 0x0a, 0x14))

    # Разметка дороги
    for x in range(0, cw, 8):
        fill_rect(canvas, x, road_y + 2, 3, 1, (0xff, 0xff, 0x40))

    # ChaldOS неон
    neon_text = "CHALDOS"
    neon_x = cw // 2 - len(neon_text) * 3 - 2
    neon_y = ch // 2 - 5

    # Свечение
    for glow in range(1, 4):
        for lx, char in enumerate(neon_text):
            if char == ' ':
                continue
            if ord(char) in FONT_5X7:
                glyph = FONT_5X7[ord(char)]
                for gy, row in enumerate(glyph):
                    for gx in range(5):
                        if row & (1 << (4 - gx)):
                            for gdx in range(-glow, glow + 1):
                                for gdy in range(-glow, glow + 1):
                                    if gdx * gdx + gdy * gdy <= glow * glow:
                                        alpha = max(0, 1 - glow / 4)
                                        r = int(pal[5][0] * alpha * 0.5)
                                        g = int(pal[5][1] * alpha * 0.5)
                                        b = int(pal[5][2] * alpha * 0.5)
                                        nx = neon_x + lx * 6 + gx + gdx
                                        ny = neon_y + gy + gdy
                                        if 0 <= nx < cw and 0 <= ny < ch:
                                            draw_pixel(canvas, nx, ny, (r, g, b))

    # Текст (поверх свечения)
    draw_text_pixel(canvas, neon_text, neon_x, neon_y, pal[5])

    img = scale_pixel_art(canvas, scale)
    return img


# --- ПРОСТОЙ ПИКСЕЛЬНЫЙ ШРИФТ 5x7 ---
FONT_5X7 = {
    32: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00],  # space
    33: [0x04, 0x04, 0x04, 0x04, 0x04, 0x00, 0x04],  # !
    46: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x04],  # .
    47: [0x02, 0x02, 0x04, 0x04, 0x08, 0x08, 0x10],  # /
    48: [0x0e, 0x11, 0x13, 0x15, 0x19, 0x11, 0x0e],  # 0
    49: [0x04, 0x0c, 0x04, 0x04, 0x04, 0x04, 0x0e],  # 1
    50: [0x0e, 0x11, 0x01, 0x02, 0x04, 0x08, 0x1f],  # 2
    51: [0x0e, 0x11, 0x01, 0x06, 0x01, 0x11, 0x0e],  # 3
    52: [0x02, 0x06, 0x0a, 0x12, 0x1f, 0x02, 0x02],  # 4
    53: [0x1f, 0x10, 0x1e, 0x01, 0x01, 0x11, 0x0e],  # 5
    54: [0x06, 0x08, 0x10, 0x1e, 0x11, 0x11, 0x0e],  # 6
    55: [0x1f, 0x01, 0x02, 0x04, 0x08, 0x08, 0x08],  # 7
    56: [0x0e, 0x11, 0x11, 0x0e, 0x11, 0x11, 0x0e],  # 8
    57: [0x0e, 0x11, 0x11, 0x0f, 0x01, 0x02, 0x0c],  # 9
    58: [0x00, 0x04, 0x00, 0x00, 0x00, 0x04, 0x00],  # :
    65: [0x04, 0x0a, 0x11, 0x11, 0x1f, 0x11, 0x11],  # A
    66: [0x1e, 0x11, 0x11, 0x1e, 0x11, 0x11, 0x1e],  # B
    67: [0x0e, 0x11, 0x10, 0x10, 0x10, 0x11, 0x0e],  # C
    68: [0x1c, 0x12, 0x11, 0x11, 0x11, 0x12, 0x1c],  # D
    69: [0x1f, 0x10, 0x10, 0x1e, 0x10, 0x10, 0x1f],  # E
    70: [0x1f, 0x10, 0x10, 0x1e, 0x10, 0x10, 0x10],  # F
    71: [0x0e, 0x11, 0x10, 0x17, 0x11, 0x11, 0x0f],  # G
    72: [0x11, 0x11, 0x11, 0x1f, 0x11, 0x11, 0x11],  # H
    73: [0x0e, 0x04, 0x04, 0x04, 0x04, 0x04, 0x0e],  # I
    74: [0x01, 0x01, 0x01, 0x01, 0x11, 0x11, 0x0e],  # J
    75: [0x11, 0x12, 0x14, 0x18, 0x14, 0x12, 0x11],  # K
    76: [0x10, 0x10, 0x10, 0x10, 0x10, 0x10, 0x1f],  # L
    77: [0x11, 0x1b, 0x15, 0x11, 0x11, 0x11, 0x11],  # M
    78: [0x11, 0x19, 0x15, 0x13, 0x11, 0x11, 0x11],  # N
    79: [0x0e, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0e],  # O
    80: [0x1e, 0x11, 0x11, 0x1e, 0x10, 0x10, 0x10],  # P
    81: [0x0e, 0x11, 0x11, 0x11, 0x15, 0x12, 0x0d],  # Q
    82: [0x1e, 0x11, 0x11, 0x1e, 0x14, 0x12, 0x11],  # R
    83: [0x0f, 0x10, 0x10, 0x0e, 0x01, 0x01, 0x1e],  # S
    84: [0x1f, 0x04, 0x04, 0x04, 0x04, 0x04, 0x04],  # T
    85: [0x11, 0x11, 0x11, 0x11, 0x11, 0x11, 0x0e],  # U
    86: [0x11, 0x11, 0x11, 0x11, 0x11, 0x0a, 0x04],  # V
    87: [0x11, 0x11, 0x11, 0x15, 0x15, 0x1b, 0x11],  # W
    88: [0x11, 0x11, 0x0a, 0x04, 0x0a, 0x11, 0x11],  # X
    89: [0x11, 0x11, 0x0a, 0x04, 0x04, 0x04, 0x04],  # Y
    90: [0x1f, 0x01, 0x02, 0x04, 0x08, 0x10, 0x1f],  # Z
    95: [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1f],  # _
}


if __name__ == "__main__":
    print("=== ChaldOS Pixel Wallpaper Generator ===")
    print("")
    import sys
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')  # noqa

    wallpapers = [
        ("chaldos_terminal.png", wallpaper_terminal, "terminal", "Rétro Terminal — зелёный код на чёрном фоне"),
        ("chaldos_sunset.png", wallpaper_mountains, "sunset", "Горный закат — пиксельные горы и солнце"),
        ("chaldos_logo.png", wallpaper_logo, "retro", "Логотип ChaldOS — крупный пиксельный логотип"),
        ("chaldos_night.png", wallpaper_night, "frost", "Ночное небо — луна, звёзды, лес"),
        ("chaldos_cyberpunk.png", wallpaper_cyberpunk, "cyber", "Cyberpunk Grid — синтвейв/киберпанк"),
        ("chaldos_forest.png", wallpaper_forest, "forest", "Пиксельный лес — деревья, свет, грибы"),
        ("chaldos_city.png", wallpaper_city, "retro", "Ночной город — неон, здания, улица"),
    ]

    for filename, func, palette, desc in wallpapers:
        print(f"[GENERATE] {desc} ...")
        img = func(1920, 1080, palette)
        path = os.path.join(OUT_DIR, filename)
        img.save(path, "PNG")
        print(f"  [OK] Saved: {filename} ({img.size[0]}x{img.size[1]})")

    # Preview-версии (уменьшенные)
    print("\n[PREVIEW] Creating thumbnails...")
    preview_dir = os.path.join(OUT_DIR, "preview")
    os.makedirs(preview_dir, exist_ok=True)
    for filename, func, palette, desc in wallpapers:
        img = func(480, 270, palette)  # уменьшенная версия для превью
        img.save(os.path.join(preview_dir, filename), "PNG")

    # Создаём HTML-превью
    html = """<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <title>ChaldOS Wallpapers — Preview</title>
    <style>
        body { background: #111; color: #eee; font-family: monospace; padding: 20px; text-align: center; }
        h1 { color: #0f0; font-size: 2em; letter-spacing: 4px; }
        .gallery { display: flex; flex-wrap: wrap; gap: 20px; justify-content: center; }
        .card { background: #1a1a2e; border: 2px solid #333; border-radius: 8px; overflow: hidden; width: 480px; }
        .card img { width: 100%; display: block; image-rendering: pixelated; }
        .card .label { padding: 10px; font-size: 14px; color: #aaa; }
        .card .label span { color: #0f0; }
        footer { margin-top: 30px; color: #555; font-size: 12px; }
    </style>
</head>
<body>
    <h1>═══ CHALDOS PIXEL WALLPAPERS ═══</h1>
    <p style="color: #888;">1920×1080 — Pixel Art</p>
    <div class="gallery">
"""
    for filename, _, _, desc in wallpapers:
        html += f'        <div class="card"><img src="../{filename}" alt="{desc}"><div class="label"><span>◆</span> {desc}</div></div>\n'

    html += """    </div>
    <footer>ChaldOS — Pixel Operating System // 2026</footer>
</body>
</html>
"""
    with open(os.path.join(preview_dir, "index.html"), "w", encoding="utf-8") as f:
        f.write(html)

    print(f"\n[FOLDER] All wallpapers saved to: {OUT_DIR}/")
    print(f"[PREVIEW] Open: {preview_dir}/index.html")
    print("\n[DONE] 7 unique pixel wallpapers for ChaldOS generated!")
