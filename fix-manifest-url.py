#!/usr/bin/env python3

import json

# 正确的Worker URL
WORKER_URL = 'https://harmony-hap-distribution.q17626049428.workers.dev'

# 读取配置文件
with open('hap/manifest-jsdelivr.json5', 'r', encoding='utf-8') as f:
    data = json.load(f)

# 更新配置为正确的Cloudflare Workers URL
data['app']['deployDomain'] = 'harmony-hap-distribution.q17626049428.workers.dev'
data['app']['icons']['normal'] = f'{WORKER_URL}/asset/icon29.png'
data['app']['icons']['large'] = f'{WORKER_URL}/asset/icon1024.png'
data['app']['modules'][0]['packageUrl'] = f'{WORKER_URL}/hap/AppSigned.hap'

# 保存更新后的配置
with open('hap/manifest-jsdelivr.json5', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

# 复制到根目录
with open('manifest.json5', 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, separators=(',', ':'))

print('✅ Manifest配置已更新为正确的Worker URL')
print(f'🌐 Worker域名: harmony-hap-distribution.q17626049428.workers.dev')
print(f'📦 HAP包URL: {WORKER_URL}/hap/AppSigned.hap')
print(f'📋 Manifest URL: {WORKER_URL}/hap/manifest-jsdelivr.json5')

# 生成DeepLink
import urllib.parse
MANIFEST_URL = f'{WORKER_URL}/hap/manifest-jsdelivr.json5'
ENCODED_URL = urllib.parse.quote(MANIFEST_URL, safe='')
DEEPLINK = f'store://enterprise/manifest?url={ENCODED_URL}'

print(f'🔗 DeepLink: {DEEPLINK}') 