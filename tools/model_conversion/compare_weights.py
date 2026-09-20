"""Paired PyTorch/TFLite screening with identical RGB/letterbox/NMS inputs.

Ground truth is explicit in the manifest. No prediction is promoted to truth.
Recall is species-correct one-to-one IoU >= .5; latency is host-only, not iPhone.
"""
import argparse
import csv
import hashlib
import json
import statistics
import sys
import time
from pathlib import Path

import cv2
import numpy as np
from verify_tflite import CLASS_NAMES, _iou, _letterbox_rgb, decode_predictions

THRESHOLDS=(.65,.70,.75,.80,.85,.90)


def read_case(root, case):
    path = root / case['path']
    if hashlib.sha256(path.read_bytes()).hexdigest() != case['sha256']:
        raise ValueError(f'Fixture changed: {path}')
    image = cv2.imread(str(path))
    if image is None:
        raise ValueError(f'Unreadable fixture: {path}')
    return image


def match(predictions, truth):
    available=set(range(len(truth))); matches=[]
    for prediction in sorted(predictions,key=lambda p:p['confidence'],reverse=True):
        candidates=[(i,_iou(prediction,truth[i])) for i in available
                    if truth[i]['class_index']==prediction['class_index']]
        index,overlap=max(candidates,key=lambda pair:pair[1],default=(-1,0))
        if overlap>=.5:
            available.remove(index);matches.append((prediction['confidence'],overlap))
    return dict(tp=len(matches),fp=len(predictions)-len(matches),fn=len(available),
                matched_confidences=[x[0] for x in matches],ious=[x[1] for x in matches])


class Model:
    def __init__(self,path,yolo):
        self.path=path
        self.metadata={'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'bytes':path.stat().st_size}
        if path.suffix=='.pt':
            sys.path.insert(0,str(yolo))
            import torch
            torch.set_num_threads(4)
            from models.experimental import attempt_load
            checkpoint=torch.load(path,map_location='cpu',weights_only=False)
            self.model=attempt_load(str(path),device=torch.device('cpu'),fuse=True).float().eval()
            names=self.model.names
            if isinstance(names,dict):names=list(names.values())
            if names!=list(CLASS_NAMES) or self.model.model[-1].nc!=2:
                raise ValueError(f'Incompatible classes: {names}')
            opt=checkpoint.get('opt',{})
            if not isinstance(opt,dict): opt=vars(opt)
            self.metadata.update(classes=names,nc=self.model.model[-1].nc,
                architecture=self.model.yaml,training_options={k:opt.get(k) for k in ('data','cfg','epochs','imgsz','weights','hyp')})
            self.backend='pytorch'
        else:
            import tensorflow as tf
            self.model=tf.lite.Interpreter(model_path=str(path),num_threads=4)
            self.model.allocate_tensors()
            self.input=self.model.get_input_details()[0]; self.output=self.model.get_output_details()[0]
            if list(self.input['shape'])!=[1,640,640,3] or list(self.output['shape'])!=[1,25200,7]:
                raise ValueError('Unexpected TFLite tensor contract')
            if self.input['dtype'] != np.float32 or self.output['dtype'] != np.float32:
                raise ValueError('Expected float32 TFLite tensors')
            self.metadata.update(classes=list(CLASS_NAMES),nc=2,input_shape=self.input['shape'].tolist(),output_shape=self.output['shape'].tolist())
            self.backend='tflite'
        self.raw(np.full((640,640,3),114,np.uint8))

    def raw(self,image):
        started=time.perf_counter()
        data=_letterbox_rgb(image,640,640).astype(np.float32)/255
        if self.backend=='pytorch':
            import torch
            tensor=torch.from_numpy(data.transpose(2,0,1).copy())[None]
            with torch.inference_mode(): rows=self.model(tensor)[0][0].numpy().copy()
            rows[:,:4]/=640
        else:
            self.model.set_tensor(self.input['index'],data[None]);self.model.invoke()
            rows=self.model.get_tensor(self.output['index'])[0]
        if rows.shape!=(25200,7): raise ValueError(f'Unexpected raw head: {rows.shape}')
        return rows,(time.perf_counter()-started)*1000


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--manifest',type=Path,required=True)
    parser.add_argument('--model',type=Path,action='append',required=True)
    parser.add_argument('--yolo',type=Path,default=Path('/tmp/yolov5-23701eac'))
    parser.add_argument('--output',type=Path,required=True)
    args=parser.parse_args(); manifest=json.loads(args.manifest.read_text())
    args.output.mkdir(parents=True,exist_ok=True)
    report={'manifest_sha256':hashlib.sha256(args.manifest.read_bytes()).hexdigest(),'limitations':manifest['limitations'],'protocol':{'thresholds':THRESHOLDS,'nms_iou':.45,'match_iou':.5,'latency':'Mac CPU, 4 threads, median of 3 incl preprocessing, excludes decoding'},'models':{}}
    table=[]
    for path in args.model:
        model=Model(path,args.yolo); results=[]
        for case in manifest['cases']:
            image=read_case(args.manifest.parent,case);h,w=image.shape[:2]
            truth=[dict(class_index=c,x=x,y=y,width=bw,height=bh) for c,x,y,bw,bh in case['boxes']]
            for mode in (['full','roi'] if case.get('roi') else ['full']):
                left=top=0;cw=w;ch=h
                if mode=='roi':
                    x,y,bw,bh=case['roi'];left=int(round(x*w));top=int(round(y*h));cw=int(round(bw*w));ch=int(round(bh*h))
                crop=image[top:top+ch,left:left+cw]
                times=[]
                for _ in range(3):rows,ms=model.raw(crop);times.append(ms)
                for threshold in THRESHOLDS:
                    boxes=decode_predictions(rows,frame_width=cw,frame_height=ch,input_width=640,input_height=640,confidence_threshold=threshold,iou_threshold=.45)
                    for box in boxes:
                        box.update(x=(left+box['x']*cw)/w,y=(top+box['y']*ch)/h,width=box['width']*cw/w,height=box['height']*ch/h)
                    record=dict(id=case['id'],category=case['category'],synthetic=case['synthetic'],mode=mode,threshold=threshold,
                                expected=len(truth),detected=len(boxes),latency_ms=statistics.median(times),detections=boxes,**match(boxes,truth))
                    results.append(record)
                    table.append(dict(model=path.stem,**{k:v for k,v in record.items() if k not in ('detections','matched_confidences','ious')}))
                    if threshold==.8 and (record['fp'] or record['fn']):
                        visual=image.copy()
                        for box in boxes:
                            x,y,bw,bh=[box[k] for k in ('x','y','width','height')]
                            cv2.rectangle(visual,(round(x*w),round(y*h)),(round((x+bw)*w),round((y+bh)*h)),(0,0,255),3)
                            cv2.putText(visual,f"{box['class_index']} {box['confidence']:.3f}",(round(x*w),max(20,round(y*h)-8)),cv2.FONT_HERSHEY_SIMPLEX,.7,(0,0,255),2)
                        cv2.imwrite(str(args.output/f'{path.stem}_{case["id"]}_{mode}.jpg'),visual)
        summary=[]
        for threshold in THRESHOLDS:
            for mode in ('full','roi'):
                selected=[r for r in results if r['threshold']==threshold and r['mode']==mode]
                positive=[r for r in selected if r['expected']]; negative=[r for r in selected if not r['expected']]
                count=sum(r['expected'] for r in positive);conf=[x for r in positive for x in r['matched_confidences']]
                summary.append(dict(threshold=threshold,mode=mode,positive_cases=len(positive),expected=count,
                    tp=sum(r['tp'] for r in positive),recall=sum(r['tp'] for r in positive)/count if count else None,
                    negative_cases=len(negative),negative_fp=sum(r['fp'] for r in negative),positive_fp=sum(r['fp'] for r in positive),
                    mean_tp_confidence=statistics.mean(conf) if conf else None,
                    exact_count_cases=sum(r['expected']==r['detected'] for r in positive),
                    median_latency_ms=statistics.median([r['latency_ms'] for r in selected]) if selected else None))
        report['models'][path.stem]=dict(metadata=model.metadata,summary=summary,results=results)
        print(path.stem,json.dumps([s for s in summary if s['threshold']==.8]),flush=True)
        (args.output/'results.json').write_text(json.dumps(report,indent=2))
    with (args.output/'cases.csv').open('w') as stream:
        writer=csv.DictWriter(stream,fieldnames=list(table[0]));writer.writeheader();writer.writerows(table)

if __name__=='__main__':main()
