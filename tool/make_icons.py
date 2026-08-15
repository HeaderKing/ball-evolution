#!/usr/bin/env python3
# 用 球球进化.jpg 生成 Android 启动图标与 Web 图标
import os
from PIL import Image

SRC = '球球进化.jpg'


def square(img):
    w, h = img.size
    s = min(w, h)
    return img.crop(((w - s) // 2, (h - s) // 2, (w + s) // 2, (h + s) // 2))


def save(img, path, size):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.resize((size, size), Image.LANCZOS).save(path)
    print('wrote', path, size)


img = square(Image.open(SRC).convert('RGBA'))

# Android 启动图标
density = {'mdpi': 48, 'hdpi': 72, 'xhdpi': 96, 'xxhdpi': 144, 'xxxhdpi': 192}
for d, size in density.items():
    save(img, os.path.join('android/app/src/main/res', f'mipmap-{d}', 'ic_launcher.png'), size)

# Web favicon 与 PWA 图标
save(img, 'web/favicon.png', 64)
save(img, 'web/icons/Icon-192.png', 192)
save(img, 'web/icons/Icon-512.png', 512)
save(img, 'web/icons/Icon-maskable-192.png', 192)
save(img, 'web/icons/Icon-maskable-512.png', 512)
print('done')
