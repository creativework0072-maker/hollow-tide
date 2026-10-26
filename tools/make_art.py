"""Generates all Hollow Tide pixel-art assets (Week 3).
Run:  python tools/make_art.py   (needs Pillow)
Art is drawn at a low native resolution and upscaled with nearest-neighbour
so it keeps a crisp, chunky pixel-art look."""
import math, random, os
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "art")
os.makedirs(OUT, exist_ok=True)

# Palette shared with the Week 1 design document
NAVY=(18,38,58,255); DEEP=(27,73,101,255); TEAL=(42,157,143,255)
FOAM=(207,232,228,255); GOLD=(233,196,106,255); GOLD_D=(190,150,70,255)
CORAL=(231,111,81,255); SKIN=(241,211,179,255); HAIR=(107,62,38,255)

def save(img, name, scale=2):
    img = img.resize((img.width*scale, img.height*scale), Image.NEAREST)
    img.save(os.path.join(OUT, name)); return img

def rect(d, x0, y0, x1, y1, c): d.rectangle([x0, y0, x1, y1], fill=c)

# ---------------- Mira sprite sheet (11 frames of 16x24 -> 32x48) ----------------
def mira(bob=0, lleg=0, rleg=0, larm=0, rarm=0, arms_up=False):
    im = Image.new("RGBA", (16, 24), (0,0,0,0)); d = ImageDraw.Draw(im)
    b = bob
    # legs + boots
    rect(d, 5, 19, 6, 22-lleg, NAVY); rect(d, 4, 22-lleg, 6, 23-lleg, DEEP)
    rect(d, 9, 19, 10, 22-rleg, NAVY); rect(d, 9, 22-rleg, 11, 23-rleg, DEEP)
    # coat (raincoat gets wider at the bottom)
    rect(d, 4, 10+b, 11, 14+b, GOLD); rect(d, 3, 15+b, 12, 18+b, GOLD)
    rect(d, 10, 10+b, 11, 18+b, GOLD_D)               # shade side
    rect(d, 7, 12+b, 8, 18+b, GOLD_D)                 # coat seam
    # arms
    if arms_up:
        rect(d, 2, 7+b+larm, 3, 11+b, GOLD); rect(d, 12, 7+b+rarm, 13, 11+b, GOLD)
        rect(d, 2, 6+b+larm, 3, 6+b+larm, SKIN); rect(d, 12, 6+b+rarm, 13, 6+b+rarm, SKIN)
    else:
        rect(d, 2, 11+b+larm, 3, 15+b+larm, GOLD); rect(d, 12, 11+b+rarm, 13, 15+b+rarm, GOLD)
        rect(d, 2, 16+b+larm, 3, 16+b+larm, SKIN); rect(d, 12, 16+b+rarm, 13, 16+b+rarm, SKIN)
    # head + hair
    rect(d, 5, 5+b, 10, 9+b, SKIN)
    rect(d, 4, 5+b, 4, 9+b, HAIR); rect(d, 11, 5+b, 11, 8+b, HAIR); rect(d, 5, 5+b, 10, 5+b, HAIR)
    rect(d, 6, 7+b, 6, 7+b, NAVY); rect(d, 9, 7+b, 9, 7+b, NAVY)
    # hat
    rect(d, 3, 3+b, 12, 4+b, NAVY); rect(d, 5, 0+b, 10, 3+b, NAVY); rect(d, 5, 2+b, 10, 2+b, CORAL)
    return im

frames = [
    mira(0), mira(1),                                          # idle x2
    mira(0, lleg=2, larm=1, rarm=-1), mira(1), mira(0, rleg=2, larm=-1, rarm=1), mira(1),  # run x4
    mira(0, lleg=1, rleg=1, arms_up=True),                     # jump
    mira(0, lleg=1, arms_up=True, larm=1), mira(1, rleg=1, arms_up=True, rarm=1),          # swim x4
    mira(0, rleg=1, arms_up=True, rarm=1), mira(1, lleg=1, arms_up=True, larm=1),
]
sheet = Image.new("RGBA", (16*len(frames), 24), (0,0,0,0))
for i, f in enumerate(frames): sheet.paste(f, (i*16, 0))
save(sheet, "mira_sheet.png")

# ---------------- Crate (25x25 -> 50x50) ----------------
c = Image.new("RGBA", (25,25), (0,0,0,0)); d = ImageDraw.Draw(c)
WOOD=(169,120,59,255); WOOD_D=(110,72,32,255); WOOD_L=(205,155,85,255)
rect(d,0,0,24,24,WOOD_D); rect(d,2,2,22,22,WOOD)
for y in (7,12,17): rect(d,2,y,22,y,WOOD_D)
d.line([(3,3),(21,21)], fill=WOOD_L); d.line([(21,3),(3,21)], fill=WOOD_L)
for p in ((1,1),(23,1),(1,23),(23,23)): rect(d,*p,*p,(60,40,20,255))
save(c, "crate.png")

# ---------------- Pearl (12x12 -> 24x24, 4 shimmer frames) ----------------
ps = Image.new("RGBA", (48,12), (0,0,0,0))
spots = [(4,4),(5,4),(5,5),(4,5)]
for i, (hx, hy) in enumerate(spots):
    f = Image.new("RGBA", (12,12), (0,0,0,0)); d = ImageDraw.Draw(f)
    r = 5 + (i % 2)
    d.ellipse([6-r,6-r,5+r,5+r], fill=(255,241,230,60))
    d.ellipse([2,2,9,9], fill=(255,241,230,255), outline=(210,190,200,255))
    rect(d,hx,hy,hx+1,hy,(255,255,255,255))
    ps.paste(f, (i*12, 0))
save(ps, "pearl_sheet.png")

# ---------------- Urchin (16x14 -> 32x28) ----------------
u = Image.new("RGBA", (16,14), (0,0,0,0)); d = ImageDraw.Draw(u)
cx, cy = 8, 8
for a in range(0, 360, 30):
    x = cx + 6.5*math.cos(math.radians(a)); y = cy + 5.5*math.sin(math.radians(a))
    if y > 13: continue
    d.line([(cx,cy),(x,y)], fill=(122,62,157,255))
    d.point((round(x),round(y)), fill=CORAL)
d.ellipse([cx-3,cy-3,cx+3,cy+3], fill=(59,31,74,255))
rect(d,6,7,6,7,CORAL); rect(d,9,7,9,7,CORAL)
save(u, "urchin.png")

# ---------------- Beacon / exit (20x40 -> 40x80, 2 lamp frames) ----------------
bs = Image.new("RGBA", (40,40), (0,0,0,0))
WHITE=(240,244,246,255)
for i in range(2):
    f = Image.new("RGBA", (20,40), (0,0,0,0)); d = ImageDraw.Draw(f)
    if i == 1: d.ellipse([0,2,19,16], fill=(255,224,138,70))        # glow halo
    d.polygon([(6,12),(13,12),(16,39),(3,39)], fill=WHITE)
    for y0 in (19,29): d.polygon([(6-(y0-12)*0.15,y0),(13+(y0-12)*0.15,y0),(13+(y0+3-12)*0.15,y0+3),(6-(y0+3-12)*0.15,y0+3)], fill=CORAL)
    rect(d,6,6,13,11,(255,224,138,255) if i==0 else (255,243,176,255))
    rect(d,6,6,6,11,NAVY); rect(d,13,6,13,11,NAVY); rect(d,9,6,10,11,(255,255,255,200) if i else (255,224,138,255))
    d.polygon([(4,6),(15,6),(9,1)], fill=NAVY)
    rect(d,8,32,11,39,DEEP)                                         # door
    bs.paste(f, (i*20, 0))
save(bs, "exit_sheet.png")

# ---------------- Ground tile (32x32 -> 64x64) ----------------
random.seed(7)
g = Image.new("RGBA", (32,32), NAVY); d = ImageDraw.Draw(g)
MORT=(28,58,82,255)
for row in range(4):
    y0 = row*8; off = 0 if row % 2 == 0 else 8
    d.line([(0,y0),(31,y0)], fill=MORT)
    for x0 in range(-16, 48, 16): d.line([(x0+off,y0),(x0+off,y0+7)], fill=MORT)
for _ in range(60):
    x, y = random.randrange(32), random.randrange(32)
    d.point((x,y), fill=random.choice([(34,66,92,255),(14,30,46,255)]))
save(g, "ground_tile.png")

# ---------------- Moss strip (32x6 -> 64x12), tiles horizontally ----------------
random.seed(11)
m = Image.new("RGBA", (32,6), (0,0,0,0)); d = ImageDraw.Draw(m)
for x in range(32):
    h = 2 + int(1.5*math.sin(x/32*math.tau*2)) + random.randint(0,2)
    d.line([(x,0),(x,min(5,h))], fill=(45,140,100,255))
    d.point((x,0), fill=(110,200,120,255))
save(m, "moss_top.png")

# ---------------- Water tile (32x32 -> 64x64) and surface (32x6 -> 64x12) ----------------
random.seed(3)
w = Image.new("RGBA", (32,32), (42,157,143,110)); d = ImageDraw.Draw(w)
for base in (6, 16, 26):
    for x in range(32):
        y = base + round(1.5*math.sin(x/32*math.tau))
        d.point((x,y), fill=(190,245,235,90))
for _ in range(25): d.point((random.randrange(32), random.randrange(32)), fill=(255,255,255,40))
save(w, "water_tile.png")
s = Image.new("RGBA", (32,6), (0,0,0,0)); d = ImageDraw.Draw(s)
for x in range(32):
    y = 2 + round(1.5*math.sin(x/32*math.tau))
    d.line([(x,y+1),(x,5)], fill=(42,157,143,150))
    d.point((x,y), fill=(235,255,250,230)); d.point((x,y+1), fill=(170,235,225,200))
save(s, "water_surface.png")

# ---------------- Sky gradient (8x256) ----------------
sky = Image.new("RGBA", (8,256))
top, bot = (130,175,210), (240,226,196)
for y in range(256):
    t = y/255
    c = tuple(round(top[i]*(1-t)+bot[i]*t) for i in range(3)) + (255,)
    for x in range(8): sky.putpixel((x,y), c)
sky.save(os.path.join(OUT, "bg_sky.png"))

# ---------------- Ruined city silhouette (600x133 -> 1800x399) ----------------
random.seed(21)
city = Image.new("RGBA", (600,133), (0,0,0,0)); d = ImageDraw.Draw(city)
x = 0
while x < 600:
    bw = random.randint(18,42); bh = random.randint(35,105)
    col = random.choice([(92,122,150,255),(80,110,140,255),(104,134,160,255)])
    top_y = 133-bh
    d.rectangle([x,top_y,x+bw,133], fill=col)
    if random.random() < .6:                          # broken, slanted roof
        d.polygon([(x,top_y),(x+bw,top_y),(x+bw,top_y-random.randint(4,12))], fill=(0,0,0,0))
        d.polygon([(x,top_y),(x+bw,top_y),(x,top_y-random.randint(2,8))], fill=col)
    for wx in range(x+4, x+bw-4, 8):
        for wy in range(top_y+8, 125, 12):
            if random.random() < .35: d.rectangle([wx,wy,wx+2,wy+3], fill=(150,180,200,255))
    x += bw + random.randint(0,6)
save(city, "bg_city.png", 3)



# =====================  WEEK 4: environmental assets  =====================

# ---- Electric eel (24x10 -> 48x20, 2 swim frames) ----
es = Image.new("RGBA", (48,10), (0,0,0,0))
for i in range(2):
    f = Image.new("RGBA", (24,10), (0,0,0,0)); d = ImageDraw.Draw(f)
    pts = [(x, 5 + round(2*math.sin(x/3 + i*math.pi))) for x in range(2,22)]
    for (x,y) in pts:
        d.rectangle([x,y-1,x,y+1], fill=(30,80,90,255)); d.point((x,y-1), fill=(60,140,140,255))
    hx, hy = pts[-1]
    d.rectangle([hx-1,hy-2,hx+1,hy+2], fill=(40,100,110,255)); d.point((hx,hy-1), fill=(255,224,80,255))
    for sx, sy in ([(6,0),(12,9),(16,0)] if i == 0 else [(8,9),(14,0),(4,9)]):
        d.point((sx,sy), fill=(255,255,160,255))
    es.paste(f, (i*24, 0))
save(es, "eel_sheet.png")

# ---- Checkpoint lantern (12x24 -> 24x48; frame 0 unlit, frame 1 lit) ----
ls = Image.new("RGBA", (24,24), (0,0,0,0))
for i in range(2):
    f = Image.new("RGBA", (12,24), (0,0,0,0)); d = ImageDraw.Draw(f)
    if i == 1: d.ellipse([0,0,11,12], fill=(255,224,138,70))
    rect(d,5,10,6,23,NAVY); rect(d,3,2,8,2,NAVY); rect(d,3,9,8,9,NAVY)
    rect(d,3,3,3,8,NAVY); rect(d,8,3,8,8,NAVY)
    rect(d,4,3,7,8,(255,224,138,255) if i else (60,80,100,255))
    rect(d,2,1,9,1,DEEP)
    ls.paste(f, (i*12, 0))
save(ls, "lantern_sheet.png")

# ---- Story mural (24x32 -> 48x64) ----
m = Image.new("RGBA", (24,32), (0,0,0,0)); d = ImageDraw.Draw(m)
rect(d,1,1,22,31,(28,58,82,255)); rect(d,3,3,20,29,(18,38,58,255))
for x in range(4,20):
    d.point((x, 22+round(1.5*math.sin(x/2))), fill=(127,255,212,255))
    d.point((x, 26+round(1.5*math.sin(x/2+1))), fill=(42,157,143,255))
rect(d,11,10,12,20,(127,255,212,255)); d.polygon([(10,10),(13,10),(11.5,7)], fill=GOLD)
for (x,y) in [(5,6),(18,8),(7,14),(17,15)]: d.point((x,y), fill=GOLD)
save(m, "mural.png")

# ---- Iron gate (20x32 -> 40x64, tiles vertically) ----
IRON=(52,58,70,255); IRON_L=(100,112,128,255)
g2 = Image.new("RGBA", (20,32), (0,0,0,0)); d = ImageDraw.Draw(g2)
for bx in (1, 8, 15):
    rect(d,bx,0,bx+2,31,IRON); rect(d,bx,0,bx,31,IRON_L)
for ry in (4, 26): rect(d,0,ry,19,ry+1,IRON); rect(d,0,ry,19,ry,IRON_L)
for (x,y) in [(4,4),(11,4),(17,4),(4,26),(11,26),(17,26)]: d.point((x,y), fill=CORAL)
save(g2, "gate_tile.png")

# ---- Pressure plate (36x8 per frame -> 72x16; frame 0 up, frame 1 pressed) ----
pl = Image.new("RGBA", (72,8), (0,0,0,0))
for i in range(2):
    f = Image.new("RGBA", (36,8), (0,0,0,0)); d = ImageDraw.Draw(f)
    top = 1 if i == 0 else 3
    rect(d,0,top,35,7,(90,110,125,255)); rect(d,0,top,35,top,(140,160,175,255))
    gc = (127,255,212,255) if i else (50,90,100,255)
    rect(d,16,top+2,19,top+3,gc); rect(d,10,top+3,12,top+3,gc); rect(d,23,top+3,25,top+3,gc)
    pl.paste(f, (i*36, 0))
save(pl, "plate_sheet.png")

# ---- Market stall awning (16x10 -> 32x20, tiles horizontally) ----
st = Image.new("RGBA", (16,10), (0,0,0,0)); d = ImageDraw.Draw(st)
for x in range(16):
    col = CORAL if (x % 16) < 8 else FOAM
    depth = 7 + (2 if (x % 8) in (2,3,4,5) else 1)
    d.line([(x,0),(x,depth)], fill=col)
    d.point((x,0), fill=(110,72,32,255))
save(st, "stall_top.png")

# ---- Seaweed (8x20 -> 16x40) ----
sw = Image.new("RGBA", (8,20), (0,0,0,0)); d = ImageDraw.Draw(sw)
for bx, hh in ((1,14),(3,19),(5,11)):
    for y in range(hh):
        x = bx + round(1.2*math.sin(y/3 + bx))
        d.point((max(0,min(7,x)), 19-y), fill=(30,120,90,255) if y % 2 else (60,170,110,255))
save(sw, "seaweed.png")

# ---- Broken pillar (16x48 -> 32x96) ----
pi = Image.new("RGBA", (16,48), (0,0,0,0)); d = ImageDraw.Draw(pi)
rect(d,3,6,12,46,(150,165,175,255)); rect(d,10,6,12,46,(120,135,150,255))
for fx in (5,8): d.line([(fx,8),(fx,44)], fill=(130,145,158,255))
d.polygon([(3,6),(5,3),(7,6),(9,2),(12,6)], fill=(150,165,175,255))
rect(d,1,44,14,47,(120,135,150,255))
save(pi, "pillar.png")

# ---- Bubble (3x3 -> 6x6) ----
bu = Image.new("RGBA", (3,3), (0,0,0,0)); d = ImageDraw.Draw(bu)
for p_ in [(1,0),(0,1),(2,1),(1,2)]: d.point(p_, fill=(210,240,255,210))
save(bu, "bubble.png")

print("art done:", sorted(os.listdir(OUT)))

# [WEEK5-OPT] Lossless PNG optimisation: re-save every PNG with maximum compression.
for _f in os.listdir(OUT):
    if _f.endswith(".png"):
        _p = os.path.join(OUT, _f)
        Image.open(_p).convert("RGBA").save(_p, optimize=True, compress_level=9)
print("PNG files optimised")
