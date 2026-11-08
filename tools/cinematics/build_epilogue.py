"""Compose the 90-second Onward ending from AIGC keyframes and motion graphics.

Run from the repo root. Authoring assets stay in ignored ending-v1/; runtime video
is exported to assets/cinematics/epilogue.ogv. No external service is called here.
"""
from pathlib import Path
import subprocess, math, json, argparse, wave
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

REPO=Path(__file__).resolve().parents[2]
ROOT=REPO/'assets/cinematics/ending-v1'
RENDER=ROOT/'render/onward-90'; OVER=ROOT/'overlays/onward-90'
FF=imageio_ffmpeg.get_ffmpeg_exe()
W,H,FPS=1920,1080,24
DURATIONS=[9,12,14,12,13,11,10,9]
DURATION=sum(DURATIONS)
MUSIC_START=106.64
SCORE=ROOT/'score-onward-90.wav'
PREVIEW=ROOT/'corridor-epilogue-onward-90s.mp4'
EDIT_MANIFEST=ROOT/'edit-onward-90.json'
for p in (ROOT,RENDER,OVER): p.mkdir(parents=True,exist_ok=True)
WHITE=(232,237,235); CYAN=(161,216,220); GOLD=(224,180,125); DIM=(148,171,180)
def font(n,mono=False):
    return ImageFont.truetype('C:/Windows/Fonts/consola.ttf' if mono else 'C:/Windows/Fonts/msyhl.ttc',n)
def text(d,pos,s,n=30,c=WHITE,mono=False): d.text(pos,s,font=font(n,mono),fill=c)
def center(d,y,s,n=34,c=WHITE):
    f=font(n); d.text(((W-d.textlength(s,font=f))/2,y),s,font=f,fill=c)
def run(args,label):
    with (RENDER/(label+'.log')).open('w',encoding='utf-8') as out:
        subprocess.run([FF,'-hide_banner','-nostdin','-y',*map(str,args)],stdout=out,stderr=out,check=True)

SHOTS=[
 ('receiver.png','01 / RECEIVED','站外回执',[
   '完整账本，已抵达站外。','这一次，复位无法抹去证据。']),
 ('receiver.png','02 / AUTHORITY REVOKED','清算终止',[
   '受益账户已冻结，A-42 后续扣款被终止。','管理层的授权记录，进入站外追责程序。']),
 ('survivor.png','03 / SURVIVOR','林岑 · 存活',[
   '林岑活了下来。','失去的年岁没有回来。你救下了他剩下的时间。']),
 ('mobius.png','04 / THE SHAPE REMAINS','环，仍在',[
   '事故改变了空间站的结构。撤销授权，无法修复裂隙。','晨与暮，依然属于同一条回廊。']),
 (None,'05 / ONE CONTINUOUS SURFACE','另一面',[
   '沿着莫比乌斯环走一圈，你来到起点的另一面。','再走一圈，才回到最初。']),
 ('letter.png','06 / RECOGNITION','你的笔迹',[
   '你终于认出了 B-17 那封遗书。','那是你留给下一轮自己的警告。']),
 ('letter.png','07 / TO THE NEXT YOU','回执背面',[
   '“下次接到任务时，先别按确认。”','广播再次响起：林岑失联。请前往 B-17。']),
 ('cover','CORRIDOR / BORROWED TOMORROW','回廊',[
   '回到起点的人，已经知道真相。','这一次，你会怎样走过同一扇门？']),
]

def overlays(i):
    art,label,title,caps=SHOTS[i]
    im=Image.new('RGBA',(W,H)); d=ImageDraw.Draw(im)
    for y in range(735,974):
        d.line((0,y,W,y),fill=(1,5,9,int(212*((y-735)/239)**1.4)))
    d.rectangle((0,0,W,107),fill=(2,5,8,255)); d.rectangle((0,973,W,H),fill=(2,5,8,255))
    text(d,(94,42),'C O R R I D O R',20,CYAN,True)
    text(d,(1410,42),'E-7 / RETURN RECEIPT',19,DIM,True)
    text(d,(94,1015),'EPILOGUE / THE OTHER SIDE OF THE LOOP',17,DIM,True)
    if i!=7:
        text(d,(96,151),label,19,CYAN,True)
        text(d,(92,192),title,38)
        d.line((96,255,152,255),fill=CYAN,width=2)
    if i==0:
        d.rectangle((1050,567,1772,786),fill=(3,12,18,195),outline=(79,130,148),width=1)
        text(d,(1080,594),'INDEPENDENT AUDIT / 外部存证',22,CYAN)
        text(d,(1080,642),'完整账本  ·  校验通过',34)
        text(d,(1080,707),'站内复位权限  /  不可撤回',24,GOLD)
    if i==1:
        d.rectangle((96,315,1158,813),fill=(3,11,17,226),outline=(65,109,126),width=1)
        rows=[('管理层受益账户','已冻结'),('A-42 后续扣款','已终止'),('授权签署记录','站外追责'),('历史交割 X-71','保留 · 无法复位')]
        for k,(name,state) in enumerate(rows):
            y=348+k*106
            text(d,(134,y),name,29)
            text(d,(669,y),state,29,CYAN if k<3 else GOLD)
            d.line((134,y+68,1118,y+68),fill=(35,64,76),width=1)
    if i==2:
        d.rectangle((96,340,685,628),fill=(3,11,17,191),outline=(65,109,126),width=1)
        text(d,(128,370),'LIN CEN / PERSONNEL STATUS',21,CYAN,True)
        text(d,(126,419),'生命体征稳定',44)
        text(d,(130,505),'后续扣款已停止',26,CYAN)
        text(d,(130,556),'历史交割不可撤回',25,GOLD)
    if i in (5,6):
        # Caption on a separate dark panel, never forge typography into the AI paper.
        d.rectangle((96,333,1017,685),fill=(3,10,16,218),outline=(54,91,109),width=1)
        text(d,(131,366),'B-17 / PERSONAL ARCHIVE',20,CYAN,True)
        text(d,(128,424),'下次接到任务时，',40)
        text(d,(128,488),'先别按确认。',46)
        text(d,(132,594),'笔迹核验：与你一致',25,GOLD)
    if i==7:
        d.rectangle((0,108,830,972),fill=(0,5,10,123))
        text(d,(138,180),'审计匣 / 起点重建',25,CYAN)
        text(d,(125,300),'回 廊',128)
        text(d,(137,488),'借 来 的 明 天',43,CYAN)
        d.line((138,575,452,575),fill=CYAN,width=1)
        text(d,(138,628),'收到。告诉我还有谁。',32)
    im.save(OVER/f'{i}.png')
    for j,cap in enumerate(caps):
        im=Image.new('RGBA',(W,H)); center(ImageDraw.Draw(im),904,cap,34)
        im.save(OVER/f'{i}-sub-{j}.png')

def project(points):
    p=np.asarray(points); angle=-.20
    xx=p[:,0]*math.cos(angle)+p[:,1]*math.sin(angle)
    yy=-p[:,0]*math.sin(angle)+p[:,1]*math.cos(angle)
    depth=yy*.77+p[:,2]*.64
    scale=490/(1+depth*.1)
    return [(float(960+x*s),float(548+(y*.64-z*.77)*s)) for x,y,z,s in zip(xx,yy,p[:,2],scale)]
def edge(u):
    return ((1+.29*math.cos(u/2))*math.cos(u),(1+.29*math.cos(u/2))*math.sin(u),.29*math.sin(u/2))
def topology_frame(t,duration):
    im=Image.new('RGB',(W,H),(3,10,16)); d=ImageDraw.Draw(im)
    for x in range(90,W,90): d.line((x,120,x,972),fill=(9,24,31))
    for y in range(160,973,90): d.line((90,y,1830,y),fill=(9,24,31))
    for j,v in enumerate(np.linspace(-.29,.29,13)):
        pts=[((1+v*math.cos(u/2))*math.cos(u),(1+v*math.cos(u/2))*math.sin(u),v*math.sin(u/2)) for u in np.linspace(0,2*math.pi,241)]
        d.line(project(pts),fill=CYAN if j in (0,12) else (39,80,93),width=2 if j in (0,12) else 1)
    for u in np.linspace(0,2*math.pi,64):
        d.line(project([((1+v*math.cos(u/2))*math.cos(u),(1+v*math.cos(u/2))*math.sin(u),v*math.sin(u/2)) for v in (-.29,.29)]),fill=(51,103,120),width=1)
    # One edge closes only after u reaches 4*pi: a genuine Mobius boundary.
    travel=duration-0.5
    u=4*math.pi*min(t/travel,1)
    pts=project([edge(v) for v in np.linspace(max(0,u-.8),u,45)])
    d.line(pts,fill=GOLD,width=5)
    x,y=project([edge(u)])[0]; d.ellipse((x-8,y-8,x+8,y+8),fill=WHITE)
    text(d,(126,749),'一圈 / 抵达另一面' if t<travel/2 else '两圈 / 回到最初',29,GOLD)
    text(d,(1255,324),'ONE SURFACE',26,CYAN,True)
    text(d,(1255,366),'ONE CONTINUOUS EDGE',19,DIM,True)
    return im
def topology_video(duration):
    out=RENDER/'topology.mp4'
    with (RENDER/'topology.log').open('w') as log:
        p=subprocess.Popen([FF,'-hide_banner','-y','-f','rawvideo','-pix_fmt','rgb24','-s','1920x1080','-r',str(FPS),'-i','-','-an','-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p',str(out)],stdin=subprocess.PIPE,stdout=log,stderr=log)
        for n in range(round(duration*FPS)): p.stdin.write(topology_frame(n/FPS,duration).tobytes())
        p.stdin.close()
        if p.wait(): raise RuntimeError('Topology rendering failed')
    return out

def shot(i):
    overlays(i); art=SHOTS[i][0]; duration=DURATIONS[i]
    if art:
        image=REPO/'assets/ui/menu_cover.png' if art=='cover' else ROOT/'art'/art
        inp=['-loop','1','-i',image]
        z=f'1.08-0.05*on/{duration*FPS}' if i in (3,7) else f'1.02+0.055*on/{duration*FPS}'
        base=f"scale=3840:2160,zoompan=z='{z}':x='iw/2-iw/zoom/2':y='ih/2-ih/zoom/2':d=1:s=1920x1080:fps=24,setsar=1,eq=brightness=-0.018:saturation=0.87"
    else:
        inp=['-i',topology_video(duration)]; base='setsar=1'
    for name in [f'{i}.png',f'{i}-sub-0.png',f'{i}-sub-1.png']: inp+=['-loop','1','-i',OVER/name]
    filters=f"[0:v]{base}[b];[b][1:v]overlay=0:0[c];[c][2:v]overlay=0:0:enable='between(t,0.45,{duration/2-.1})'[d];[d][3:v]overlay=0:0:enable='between(t,{duration/2+.1},{duration-.4})'[e];[e]fade=t=in:st=0:d=0.4,fade=t=out:st={duration-.35}:d=0.35,format=yuv420p[v]"
    run([*inp,'-filter_complex_threads','1','-filter_complex',filters,'-map','[v]','-t',duration,'-r','24','-an','-c:v','libx264','-preset','fast','-crf','19','-threads','4',RENDER/f'shot-{i}.mp4'],f'shot-{i}')
    print(f'Ending shot {i+1}/8 complete',flush=True)

def music():
    source=ROOT/'music/a-kun-onward.flac'
    if not source.exists(): raise FileNotFoundError('User-supplied Onward FLAC is required in the local ending-v1/music folder')
    # Materialize the downmix first so measurement and gain use identical samples.
    raw=RENDER/'score-stereo.wav'
    run(['-ss',MUSIC_START,'-i',source,'-t',DURATION,'-map','0:a:0','-vn','-ar','48000','-ac','2','-c:a','pcm_s16le','-map_metadata','-1',raw],'score-stereo')
    r=subprocess.run([FF,'-hide_banner','-i',str(raw),'-map','0:a:0','-vn','-af','loudnorm=I=-19:TP=-1.5:LRA=11:print_format=json','-f','null','-'],capture_output=True,check=True)
    log=r.stderr.decode(errors='replace'); m=json.loads(log[log.rfind('{'):log.rfind('}')+1])
    with wave.open(str(raw),'rb') as pcm:
        samples=np.frombuffer(pcm.readframes(pcm.getnframes()),dtype='<i2').astype(np.float64)/32768
    sample_peak=20*math.log10(float(np.abs(samples).max()))
    gain=min(-19-float(m['input_i']), -2-float(m['input_tp']), -2-sample_peak)
    # Preserve the final orchestral hit and its natural reverb; just smooth the tail.
    filters=f'volume={gain:.3f}dB,afade=t=in:st=0:d=2,afade=t=out:st={DURATION-1.5}:d=1.5'
    run(['-i',raw,'-map','0:a:0','-vn','-af',filters,'-ar','48000','-ac','2','-map_metadata','-1',SCORE],'score')

def main(audio_only=False):
    for i in range(8):
        target=RENDER/f'shot-{i}.mp4'
        if not target.exists() or target.stat().st_size<1024: shot(i)
    music()
    (RENDER/'concat.txt').write_text(''.join(f"file 'shot-{i}.mp4'\n" for i in range(8)),encoding='utf-8')
    preview=PREVIEW
    run(['-f','concat','-safe','0','-i',RENDER/'concat.txt','-i',SCORE,'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','aac','-b:a','256k','-t',DURATION,'-movflags','+faststart',preview],'preview')
    print('Ending MP4 complete',flush=True)
    runtime=RENDER/'epilogue.ogv'
    if audio_only:
        # Only valid once the installed video already has this edit's duration.
        import cv2
        cap=cv2.VideoCapture(str(REPO/'assets/cinematics/epilogue.ogv'))
        existing_duration=cap.get(cv2.CAP_PROP_FRAME_COUNT)/cap.get(cv2.CAP_PROP_FPS)
        cap.release()
        if abs(existing_duration-DURATION)>0.1: raise ValueError('Installed video has another duration; perform a full build first')
        run(['-i',REPO/'assets/cinematics/epilogue.ogv','-i',SCORE,'-map','0:v:0','-map','1:a:0','-c:v','copy','-c:a','libvorbis','-q:a','5','-ar','48000',runtime],'game-transcode')
    else:
        run(['-i',preview,'-map','0:v:0','-map','0:a:0','-c:v','libtheora','-q:v','7','-g','48','-pix_fmt','yuv420p','-c:a','libvorbis','-q:a','5','-ar','48000',runtime],'game-transcode')
    runtime.replace(REPO/'assets/cinematics/epilogue.ogv')
    offsets=np.cumsum([0]+DURATIONS).tolist()
    manifest={'duration':DURATION,'fps':FPS,'music':'阿鲲 - 前行','music_source_seconds':[MUSIC_START,MUSIC_START+DURATION],
              'preview':preview.name,'score':SCORE.name,
              'shots':[{'start':offsets[i],'end':offsets[i+1],'title':SHOTS[i][2]} for i in range(8)]}
    EDIT_MANIFEST.write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Runtime epilogue.ogv complete',flush=True)

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--audio-only',action='store_true',help='Reuse existing Theora video while remuxing a revised score')
    main(parser.parse_args().audio_only)
