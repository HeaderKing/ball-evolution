#!/usr/bin/env python3
# 生成游戏音效与背景音乐 WAV（运行于项目根目录；BGM 为紧张驱动风格 A 小调）
import os, random, struct, math, wave

SR = 22050
OUT = os.path.join('assets', 'audio')


def write(name, samples):
    path = os.path.join(OUT, name)
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-9, max(abs(s) for s in samples))
    scale = 0.82 / peak
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = max(-1.0, min(1.0, s * scale))
            frames += struct.pack('<h', int(v * 32767))
        w.writeframes(bytes(frames))


def tone(freq, dur, vol=0.5, decay=6.0, wavef=math.sin):
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        out.append(vol * math.exp(-decay * t) * wavef(2 * math.pi * freq * t))
    return out


def noise(dur, vol=0.3, decay=12.0, seed=7):
    r = random.Random(seed)
    n = int(SR * dur)
    out = []
    for i in range(n):
        t = i / SR
        out.append(vol * math.exp(-decay * t) * (r.random() * 2 - 1))
    return out


def seq(notes, step=0.15, vol=0.5, decay=3.5):
    out = []
    for f in notes:
        out += tone(f, step, vol=vol, decay=decay)
    return out


saw = lambda x: math.sin(x) + 0.5 * math.sin(2 * x)

# 命中：低频短促 + 微噪声点击
write('sfx_hit.wav', tone(130, 0.06, 0.7, 14) + noise(0.02, 0.18, 40))
# 击杀：厚实爆破 + 上滑
write('sfx_kill.wav', tone(180, 0.14, 0.7, 7) + tone(90, 0.16, 0.6, 8) + noise(0.05, 0.25, 20))
# 拾取/治疗/升级
write('sfx_pickup.wav', seq([660, 990], 0.09, vol=0.5))
write('sfx_heal.wav', seq([520, 660, 990], 0.1, vol=0.5))
write('sfx_levelup.wav', seq([523, 659, 784, 1046, 1318], 0.11, vol=0.6))
# 受击：下滑更戏剧化
write('sfx_hurt.wav', tone(240, 0.26, 0.7, 5) + tone(160, 0.30, 0.55, 5) + tone(95, 0.34, 0.4, 4) + noise(0.08, 0.2, 15))
# Boss 出场：低频轰鸣
write('sfx_boss.wav', tone(85, 0.7, 0.85, 1.5) + tone(110, 0.5, 0.6, 2) + noise(0.4, 0.2, 4))

# Boss 战 BGM：更快、更低沉、更压迫（输出 bgm_boss.wav；战斗 BGM 已用下载的 bgm.mp3）
step = 0.1
steps = 64
n = int(SR * step * steps)
samples = [0.0] * n
bass = [98, 0, 98, 0, 87, 0, 87, 0, 82, 0, 82, 0, 73, 0, 73, 0] * 4
lead = [494, 0, 587, 0, 494, 0, 587, 0,
        523, 0, 622, 0, 523, 0, 622, 0,
        466, 0, 554, 0, 466, 0, 554, 0,
        440, 0, 523, 0, 440, 0, 523, 0]
for i, f in enumerate(bass):
    if f == 0:
        continue
    seg = tone(f, step, 0.5, 3.5)
    base = int(i * step * SR)
    for j, s in enumerate(seg):
        if base + j < len(samples):
            samples[base + j] += s
for i, f in enumerate(lead):
    if f == 0:
        continue
    seg = tone(f, step, 0.18, 2)
    base = int(i * step * SR)
    for j, s in enumerate(seg):
        if base + j < len(samples):
            samples[base + j] += s
for i in range(steps):
    base = int(i * step * SR)
    if i % 4 == 0:
        seg = tone(55, 0.1, 0.6, 10)
        for j, s in enumerate(seg):
            if base + j < len(samples):
                samples[base + j] += s
    seg = noise(0.05, 0.14, 12, seed=i % 5)
    for j, s in enumerate(seg):
        if base + j < len(samples):
            samples[base + j] += s
write('bgm_boss.wav', samples)
print('audio generated:', os.listdir(OUT))
