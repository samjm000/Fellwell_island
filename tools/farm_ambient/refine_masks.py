from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
p=Path(__file__).resolve().parents[2]/'art/backgrounds/farm'
im=Image.open(p/'environment.png').convert('RGB')
r,g,b=im.split()
water=Image.new('L',im.size)
d=ImageDraw.Draw(water)
d.polygon([(1145,802),(1215,783),(1285,786),(1306,802),(1390,800),(1480,792),(1584,796),(1671,784),(1671,940),(1218,940),(1208,901),(1162,862)],fill=235)
# Water lilies and their floating leaves remain fixed, as do bank rocks and bridge.
for box in [(1372,804,1459,873),(1472,790,1575,854),(1590,800,1671,841),(1176,907,1300,941)]:
 d.ellipse(box,fill=0)
water=water.filter(ImageFilter.GaussianBlur(5))
# Extend gentle movement to a few distinct marginal grass/flower clumps.
rd=ImageDraw.Draw(r)
for box in [(800,746,830,797),(943,727,967,770),(1238,646,1260,686),(362,674,390,715)]:
 rd.ellipse(box,fill=180)
r=r.filter(ImageFilter.GaussianBlur(1.5))
Image.merge('RGB',(r,water,b)).save(p/'environment.png')
