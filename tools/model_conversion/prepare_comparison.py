"""Build a sourced, small screening set; not a held-out field validation set.

Real negatives come from Wikipedia lead photos (URLs recorded). Positive
annotations are manually reviewed boxes, NOT VespAI's prediction label files.
Synthetic scale/occlusion/edge variants are reported separately.
"""
import argparse
import hashlib
import json
from pathlib import Path
from urllib.request import Request, urlopen

import cv2
import numpy as np


def fetch(url):
    return urlopen(Request(url, headers={'User-Agent': 'HornetBenchmark/1.0 (research comparison)'}), timeout=40).read()


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--vespai', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=True)
    if (a.output / 'manifest.json').exists():
        raise SystemExit('Output already has a frozen manifest; use a fresh directory to prepare a new dataset.')
    cases = []

    def save(name, image, boxes, category, source, roi=None, synthetic=False):
        path = a.output / f'{name}.jpg'
        cv2.imwrite(str(path), image, [cv2.IMWRITE_JPEG_QUALITY, 96])
        cases.append(dict(id=name, path=path.name, category=category, source=source,
                          synthetic=synthetic, boxes=boxes,
                          roi=roi if roi is not None else ([.25,.25,.5,.5] if not boxes else None),
                          sha256=hashlib.sha256(path.read_bytes()).hexdigest()))

    sources = [('honeybee', 'Western_honey_bee'), ('many_bees', 'Swarming_(honey_bee)'),
               ('paper_wasp', 'Polistes_dominula'), ('yellowjacket', 'Vespula_vulgaris'),
               ('hoverfly', 'Episyrphus_balteatus'), ('flower', 'Flower'),
               ('leaves', 'Leaf'), ('hive_entrance', 'Beehive'),
               ('hand', 'Hand'), ('wood', 'Wood'), ('yellow_black_object', 'School_bus')]
    negatives = []
    for category, title in sources:
        summary = json.loads(fetch('https://en.wikipedia.org/api/rest_v1/page/summary/' + title))
        url = summary.get('originalimage', summary.get('thumbnail', {})).get('source')
        if url: url=url.split('?')[0]
        if not url:
            print('MISSING', category, flush=True)
            continue
        try:
            try:
                raw = fetch(url)
            except Exception:
                url=summary['thumbnail']['source'].split('?')[0]
                raw=fetch(url)
            im = cv2.imdecode(np.frombuffer(raw, np.uint8), cv2.IMREAD_COLOR)
            if im is None: raise ValueError('not a raster photo')
            h,w=im.shape[:2]
            if max(h,w)>1600: im=cv2.resize(im,(round(w*1600/max(h,w)), round(h*1600/max(h,w))))
            save(category, im, [], category, dict(page=summary['content_urls']['desktop']['page'], image=url))
            negatives.append((category, im))
            print('FETCHED', category, flush=True)
        except Exception as e:
            raise RuntimeError(f'Missing required negative category: {category}') from e

    for species, frame, boxes in [
        ('crabro', 1, [[0,.42,.625,.09,.13],[0,.42,.315,.09,.12],[0,.40,.27,.09,.085]]),
        ('velutina', 11, [[1,.49,.605,.065,.175],[1,.385,.89,.077,.10]]),
    ]:
        source = a.vespai / f'images/example-detections/{species}/frames/frame-{frame}.jpeg'
        im = cv2.imread(str(source)); h,w=im.shape[:2]
        save(species, im, boxes, 'official_positive', str(source.relative_to(a.vespai)))
        # Tight, manually selected single-hornet crop: near-field control.
        region=(.37,.57,.20,.30) if species=='crabro' else (.44,.55,.17,.27)
        rx,ry,rw,rh=region;left=round(rx*w);top=round(ry*h);cw=round(rw*w);ch=round(rh*h)
        gt=[boxes[0]]
        cropped=im[top:top+ch,left:left+cw]
        crop_boxes=[[c,(x*w-left)/cw,(y*h-top)/ch,bw*w/cw,bh*h/ch] for c,x,y,bw,bh in gt]
        save(species+'_close',cropped,crop_boxes,'close_positive',str(source.relative_to(a.vespai)),synthetic=True)
        for scale in (.6,.4,.3,.15):
            nw,nh=round(w*scale),round(h*scale); left=(w-nw)//2; top=(h-nh)//2
            canvas=np.full_like(im,114); canvas[top:top+nh,left:left+nw]=cv2.resize(im,(nw,nh))
            scaled=[[c,(left+x*nw)/w,(top+y*nh)/h,bw*nw/w,bh*nh/h] for c,x,y,bw,bh in boxes]
            save(f'{species}_scale_{scale}',canvas,scaled,'small_positive',str(source.relative_to(a.vespai)),
                 roi=[left/w,top/h,nw/w,nh/h],synthetic=True)
        # Shift the source to put the rightmost target next to the image edge.
        right=max(x+bw for _,x,y,bw,bh in boxes); shift=round((.99-right)*w)
        moved=cv2.warpAffine(im,np.float32([[1,0,shift],[0,1,0]]),(w,h),borderValue=(114,114,114))
        save(species+'_edge',moved,[[c,x+shift/w,y,bw,bh] for c,x,y,bw,bh in boxes],
             'edge_positive',str(source.relative_to(a.vespai)),synthetic=True)
        occluded=im.copy()
        for _,x,y,bw,bh in boxes:
            cv2.rectangle(occluded,(round(x*w),round(y*h)),(round((x+bw*.2)*w),round((y+bh)*h)),(114,114,114),-1)
        save(species+'_occluded',occluded,boxes,'occluded_positive',str(source.relative_to(a.vespai)),synthetic=True)

    text=np.full((720,1280,3),245,np.uint8)
    for i,line in enumerate(['Hornet search results', 'Vespa crabro 0.94', 'Bee monitoring dashboard', 'Raw AI 0 | Upload 0']):
        cv2.putText(text,line,(35,90+i*140),cv2.FONT_HERSHEY_SIMPLEX,1.5,(25,25,25),3)
    save('text_ui',text,[],'text_ui','generated text-only control',synthetic=True)
    grid=np.full((900,1280,3),245,np.uint8)
    cv2.putText(grid,'Bee / wasp image search - negative taxa only',(25,50),cv2.FONT_HERSHEY_SIMPLEX,1,(0,0,0),2)
    for i,(name,im) in enumerate(negatives[:8]):
        x=20+(i%4)*315; y=90+(i//4)*380
        h,w=im.shape[:2]; ratio=min(295/w,290/h)
        small=cv2.resize(im,(round(w*ratio),round(h*ratio)))
        grid[y:y+small.shape[0],x:x+small.shape[1]]=small
        cv2.putText(grid,name,(x,y+320),cv2.FONT_HERSHEY_SIMPLEX,.65,(0,0,0),1)
    save('negative_thumbnails',grid,[],'search_thumbnails','controlled composite of sourced negatives',synthetic=True)
    # Identical UI scene, with a labeled official hornet thumbnail added.
    original=cv2.imread(str(a.vespai/'images/example-detections/crabro/frames/frame-1.jpeg'))
    small=cv2.resize(original,(295,166));grid[90:380,20:315]=245;grid[90:256,20:315]=small
    mixed_boxes=[[c,(20+x*295)/1280,(90+y*166)/900,bw*295/1280,bh*166/900]
                 for c,x,y,bw,bh in [[0,.42,.625,.09,.13],[0,.42,.315,.09,.12],[0,.40,.27,.09,.085]]]
    save('mixed_thumbnails',grid,mixed_boxes,'mixed_ui_positive','controlled UI, official crabro + non-target photos',synthetic=True)
    hive=cv2.imread(str(a.output/'hive_entrance.jpg'))
    h,w=hive.shape[:2]
    save('empty_hive',hive[int(h*.35):int(h*.95),int(w*.15):int(w*.65)],[],
         'empty_hive','crop of sourced hive exterior; no visible target, not user field footage',synthetic=True)
    (a.output/'manifest.json').write_text(json.dumps(dict(
        limitations='Small diagnostic screening set. Official positives may overlap training. Derived variants are not independent samples. Manual boxes require visual review. No field recall claim.',
        cases=cases),indent=2))
    # Contact sheet for independent human/model visual review before metrics.
    sheet=np.full((int(np.ceil(len(cases)/4))*220,1280,3),255,np.uint8)
    for i,case in enumerate(cases):
        im=cv2.imread(str(a.output/case['path'])); h,w=im.shape[:2]
        for c,x,y,bw,bh in case['boxes']:
            cv2.rectangle(im,(round(x*w),round(y*h)),(round((x+bw)*w),round((y+bh)*h)),(0,255,0),3)
        r=min(310/w,180/h); im=cv2.resize(im,(round(w*r),round(h*r)))
        x=(i%4)*320;y=(i//4)*220
        sheet[y:y+im.shape[0],x:x+im.shape[1]]=im
        cv2.putText(sheet,case['id'],(x+5,y+205),cv2.FONT_HERSHEY_SIMPLEX,.5,(0,0,0),1)
    cv2.imwrite(str(a.output/'contact_sheet.jpg'),sheet)

if __name__=='__main__': main()
