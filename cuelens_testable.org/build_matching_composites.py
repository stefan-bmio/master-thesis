#!/usr/bin/env python3
"""Build Testable matching composite scenes from the exact CueLens Android PNGs.

Run inside a local checkout, for example:
    python build_matching_composites.py \
      --source ../master-thesis/cuelens/app/src/main/res/drawable \
      --output assets

The script intentionally creates only the five PoC scenes 000..004.
"""
from pathlib import Path
from PIL import Image
import argparse

CANVAS=(420,760)
CUE_BOX=(0,0,420,545)
LEFT_BOX=(35,565,190,710)
RIGHT_BOX=(230,565,385,710)
BG=(215,236,233)

def fit(im, box):
    w,h=box[2]-box[0], box[3]-box[1]
    x=im.copy(); x.thumbnail((w,h), Image.Resampling.LANCZOS)
    return x, (box[0]+(w-x.width)//2, box[1]+(h-x.height)//2)

def cover(im, size):
    ratio=max(size[0]/im.width,size[1]/im.height)
    n=im.resize((round(im.width*ratio),round(im.height*ratio)), Image.Resampling.LANCZOS)
    l=(n.width-size[0])//2; t=(n.height-size[1])//2
    return n.crop((l,t,l+size[0],t+size[1]))

p=argparse.ArgumentParser()
p.add_argument('--source', required=True)
p.add_argument('--output', required=True)
a=p.parse_args()
src=Path(a.source); out=Path(a.output); out.mkdir(parents=True, exist_ok=True)
for i in range(5):
    s=f'{i:03d}'
    cue=Image.open(src/f'cue_{s}.png').convert('RGB')
    aa=Image.open(src/f'match_a_{s}.png').convert('RGB')
    bb=Image.open(src/f'match_b_{s}.png').convert('RGB')
    canvas=Image.new('RGB',CANVAS,BG)
    cue_crop=cover(cue,(CUE_BOX[2]-CUE_BOX[0],CUE_BOX[3]-CUE_BOX[1]))
    canvas.paste(cue_crop,(CUE_BOX[0],CUE_BOX[1]))
    left,right=(aa,bb) if i%2==0 else (bb,aa)
    for im,box in ((left,LEFT_BOX),(right,RIGHT_BOX)):
        fitted,pos=fit(im,box); canvas.paste(fitted,pos)
    canvas.save(out/f'matching_scene_{s}.png', optimize=True)
print('Created 5 PoC composites.')
