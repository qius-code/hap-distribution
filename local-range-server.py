#!/usr/bin/env python3
"""
本地Range请求测试服务器
演示鸿蒙HAP包分片下载功能
"""

import http.server
import socketserver
import os
import re
from urllib.parse import unquote

class RangeHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    
    def do_GET(self):
        """处理GET请求，支持Range请求"""
        
        # 解码URL路径
        path = unquote(self.path)
        
        # 如果是根路径，显示欢迎信息
        if path == '/':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            welcome_html = """
            <!DOCTYPE html>
            <html>
            <head>
                <title>🎉 鸿蒙HAP包分片下载测试服务器</title>
                <meta charset="utf-8">
            </head>
            <body>
                <h1>🎉 鸿蒙HAP包分片下载测试服务器</h1>
                <p>✅ 支持HTTP Range请求</p>
                <p>✅ 返回206 Partial Content状态码</p>
                <p>✅ 完全符合鸿蒙分发要求</p>
                
                <h2>📦 可用文件:</h2>
                <ul>
                    <li><a href="/hap/AppSigned.hap">HAP包文件</a></li>
                    <li><a href="/hap/manifest-jsdelivr.json5">配置文件</a></li>
                </ul>
                
                <h2>🧪 测试命令:</h2>
                <pre>
# 测试完整文件
curl -I "http://localhost:8000/hap/AppSigned.hap"

# 测试分片下载 (关键!)
curl -I -H "Range: bytes=0-1023" "http://localhost:8000/hap/AppSigned.hap"

# 应该返回: HTTP/1.0 206 Partial Content
                </pre>
            </body>
            </html>
            """
            self.wfile.write(welcome_html.encode('utf-8'))
            return
        
        # 获取文件路径
        if path.startswith('/'):
            file_path = '.' + path
        else:
            file_path = path
            
        # 检查文件是否存在
        if not os.path.exists(file_path) or not os.path.isfile(file_path):
            self.send_error(404, "文件未找到")
            return
        
        # 获取文件信息
        file_size = os.path.getsize(file_path)
        
        # 检查Range头
        range_header = self.headers.get('Range')
        
        print(f"📁 请求文件: {file_path}")
        print(f"📦 文件大小: {file_size} bytes")
        print(f"🎯 Range头: {range_header}")
        
        if range_header:
            # 处理Range请求
            self.handle_range_request(file_path, file_size, range_header)
        else:
            # 处理完整文件请求
            self.handle_full_request(file_path, file_size)
    
    def handle_range_request(self, file_path, file_size, range_header):
        """处理Range请求，返回206状态码"""
        
        # 解析Range头: bytes=start-end
        range_match = re.match(r'bytes=(\d*)-(\d*)', range_header)
        if not range_match:
            self.send_error(416, "Range格式错误")
            return
        
        start_str, end_str = range_match.groups()
        
        # 计算范围
        start = int(start_str) if start_str else 0
        end = int(end_str) if end_str else (file_size - 1)
        
        # 验证范围
        if start >= file_size or end >= file_size or start > end:
            self.send_error(416, "Range超出范围")
            self.send_header('Content-Range', f'bytes */{file_size}')
            self.end_headers()
            return
        
        chunk_size = end - start + 1
        
        print(f"✂️  分片范围: {start}-{end} ({chunk_size} bytes)")
        
        try:
            # 读取文件片段
            with open(file_path, 'rb') as f:
                f.seek(start)
                data = f.read(chunk_size)
            
            # 发送206响应 - 关键！
            self.send_response(206, "Partial Content")
            self.send_header('Content-Type', self.get_content_type(file_path))
            self.send_header('Content-Length', str(len(data)))
            self.send_header('Content-Range', f'bytes {start}-{end}/{file_size}')
            self.send_header('Accept-Ranges', 'bytes')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges')
            self.end_headers()
            
            self.wfile.write(data)
            
            print(f"✅ 成功返回206响应，发送 {len(data)} bytes")
            
        except Exception as e:
            print(f"❌ 读取文件失败: {e}")
            self.send_error(500, "读取文件失败")
    
    def handle_full_request(self, file_path, file_size):
        """处理完整文件请求"""
        
        print(f"📥 返回完整文件 ({file_size} bytes)")
        
        try:
            with open(file_path, 'rb') as f:
                data = f.read()
            
            self.send_response(200)
            self.send_header('Content-Type', self.get_content_type(file_path))
            self.send_header('Content-Length', str(file_size))
            self.send_header('Accept-Ranges', 'bytes')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            
            self.wfile.write(data)
            
            print(f"✅ 成功返回完整文件")
            
        except Exception as e:
            print(f"❌ 读取文件失败: {e}")
            self.send_error(500, "读取文件失败")
    
    def get_content_type(self, file_path):
        """获取文件的Content-Type"""
        if file_path.endswith('.hap'):
            return 'application/octet-stream'
        elif file_path.endswith('.json5') or file_path.endswith('.json'):
            return 'application/json; charset=utf-8'
        elif file_path.endswith('.png'):
            return 'image/png'
        elif file_path.endswith('.jpg') or file_path.endswith('.jpeg'):
            return 'image/jpeg'
        else:
            return 'application/octet-stream'

def main():
    PORT = 8000
    
    print("🚀 启动鸿蒙HAP包分片下载测试服务器")
    print("=" * 50)
    print(f"🌐 服务器地址: http://localhost:{PORT}")
    print("✅ 支持Range请求和206状态码")
    print("🎯 完全符合鸿蒙分发要求")
    print()
    print("📋 测试命令:")
    print(f"   curl -I http://localhost:{PORT}/hap/AppSigned.hap")
    print(f"   curl -I -H 'Range: bytes=0-1023' http://localhost:{PORT}/hap/AppSigned.hap")
    print()
    print("🛑 按 Ctrl+C 停止服务器")
    print("=" * 50)
    
    try:
        with socketserver.TCPServer(("", PORT), RangeHTTPRequestHandler) as httpd:
            httpd.serve_forever()
    except KeyboardInterrupt:
        print("\n🛑 服务器已停止")

if __name__ == "__main__":
    main() 