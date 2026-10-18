from PIL import Image
from pathlib import Path
import json,hashlib
src=Image.open('art/camp-build-v1/candidate-01/generated.png').convert('RGBA')
# The model returned a 1254 square with a tall torch beginning above the nominal
# final row. Ownership boundaries are measured from the inspected actual image.
xs=[0,313,627,940,1254];ys=[0,313,627,917,1254]
sheet=Image.new('RGBA',(1400,1400),(255,0,255,255))
for y in range(4):
 for x in range(4):
  crop=src.crop((xs[x],ys[y],xs[x+1],ys[y+1]))
  sheet.paste(crop,(x*350+(350-crop.width)//2,y*350+(350-crop.height)//2))
sheet.save('art/camp-build-v1/owned-sheet.png')
