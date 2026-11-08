"""Verify media and extract an eight-shot review sheet from the final MP4."""
from pathlib import Path
import subprocess, json, wave
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import imageio_ffmpeg

repo=Path(__file__).resolve().parents[2]
root=repo/'assets/cinematics/ending-v1'
ff=imageio_ffmpeg.get_ffmpeg_exe()
edit=json.loads((root/'edit-onward-90.json').read_text(encoding='utf-8'))
expected=float(edit['duration'])
video=root/edit['preview']
cap=cv2.VideoCapture(str(video)); assert cap.isOpened()
fps=cap.get(cv2.CAP_PROP_FPS); count=int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
width=int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)); height=int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
assert (fps,count,width,height)==(24,round(expected*24),1920,1080),(fps,count,width,height)
sheet=Image.new('RGB',(1440,884),(3,9,14)); d=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/consola.ttf',18)
for i,shot in enumerate(edit['shots']):
    t=(shot['start']+shot['end'])/2
    cap.set(cv2.CAP_PROP_POS_MSEC,t*1000); ok,frame=cap.read(); assert ok and frame.mean()>4,t
    cv2.imwrite(str(root/'render/onward-90'/f'qa-{t:05.1f}.jpg'),frame)
    image=Image.fromarray(cv2.cvtColor(frame,cv2.COLOR_BGR2RGB)).resize((480,270))
    x=(i%3)*480; y=(i//3)*294
    sheet.paste(image,(x,y)); d.text((x+13,y+271),f'{t:04.1f}s / SHOT {i+1:02d}',font=font,fill=(166,211,219))
sheet.save(root/'ending-onward-contact-sheet.jpg',quality=92)
cap.release()
audio_durations={}
for path in [video,repo/'assets/cinematics/epilogue.ogv']:
    result=subprocess.run([ff,'-v','error','-i',str(path),'-f','null','-'],capture_output=True)
    assert result.returncode==0 and not result.stderr,result.stderr.decode(errors='replace')
    decoded=subprocess.run([ff,'-v','error','-i',str(path),'-map','0:a:0','-vn','-ac','2','-ar','48000','-f','f32le','-'],capture_output=True,check=True)
    audio_durations[path.suffix]=len(decoded.stdout)/(2*4*48000)
    assert abs(audio_durations[path.suffix]-expected)<.1,audio_durations
    media=cv2.VideoCapture(str(path))
    media_seconds=media.get(cv2.CAP_PROP_FRAME_COUNT)/media.get(cv2.CAP_PROP_FPS)
    media.release()
    assert abs(media_seconds-expected)<.1,(path,media_seconds)
with wave.open(str(root/edit['score']),'rb') as w:
    seconds=w.getnframes()/w.getframerate(); channels=w.getnchannels()
    audio=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').astype(np.float64)/32768
    peak=float(20*np.log10(np.abs(audio).max()))
assert abs(seconds-expected)<.1 and channels==2 and peak<0,(seconds,channels,peak)
result=subprocess.run([ff,'-hide_banner','-i',str(video),'-map','0:a:0','-vn','-af','loudnorm=I=-19:TP=-1.5:LRA=11:print_format=json','-f','null','-'],capture_output=True,check=True)
log=result.stderr.decode(errors='replace'); levels=json.loads(log[log.rfind('{'):log.rfind('}')+1])
report={'duration':count/fps,'music':edit['music'],'music_source_seconds':edit['music_source_seconds'],
        'decoded_audio_durations':audio_durations,'size':[width,height],'fps':fps,'frames':count,'audio_channels':channels,
        'audio_lufs':float(levels['input_i']),'audio_true_peak':float(levels['input_tp']),
        'mp4_bytes':video.stat().st_size,'ogv_bytes':(repo/'assets/cinematics/epilogue.ogv').stat().st_size,
        'decode':'MP4 and OGV passed'}
(root/'verification-onward-90.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(report,indent=2))
