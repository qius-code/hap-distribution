export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    
    // 只处理HAP文件的请求
    if (url.pathname.endsWith('.hap')) {
      return handleRangeRequest(request, url);
    }
    
    // 其他请求直接转发
    return fetch(request);
  }
};

async function handleRangeRequest(request, url) {
  // 构造原始文件的URL (指向您的Cloudflare Pages)
  const originalUrl = `https://qius.hm-34r.pages.dev${url.pathname}`;
  
  // 获取原始文件 (不传递Range头)
  const fetchHeaders = {};
  for (const [key, value] of request.headers.entries()) {
    if (key.toLowerCase() !== 'range') {
      fetchHeaders[key] = value;
    }
  }
  
  const response = await fetch(originalUrl, {
    headers: fetchHeaders
  });

  if (!response.ok) {
    return response;
  }

  const rangeHeader = request.headers.get('range');
  
  // 如果没有Range请求，返回完整文件
  if (!rangeHeader) {
    return new Response(response.body, {
      status: 200,
      headers: {
        'Content-Type': 'application/octet-stream',
        'Accept-Ranges': 'bytes',
        'Content-Length': response.headers.get('content-length'),
        'Cache-Control': 'public, max-age=3600',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
        'Access-Control-Allow-Headers': 'Range, Content-Range',
        'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Accept-Ranges'
      }
    });
  }

  // 处理Range请求
  const fullContent = await response.arrayBuffer();
  const totalLength = fullContent.byteLength;
  
  // 解析Range头
  const match = rangeHeader.match(/bytes=(\d+)-(\d*)/);
  if (!match) {
    return new Response('Invalid Range', { status: 416 });
  }

  const start = parseInt(match[1]);
  const end = match[2] ? parseInt(match[2]) : totalLength - 1;

  // 验证范围
  if (start >= totalLength || end >= totalLength || start > end) {
    return new Response('Range Not Satisfiable', { 
      status: 416,
      headers: {
        'Content-Range': `bytes */${totalLength}`
      }
    });
  }

  // 提取请求的字节范围
  const chunk = fullContent.slice(start, end + 1);
  
  return new Response(chunk, {
    status: 206,
    headers: {
      'Content-Type': 'application/octet-stream',
      'Accept-Ranges': 'bytes',
      'Content-Range': `bytes ${start}-${end}/${totalLength}`,
      'Content-Length': chunk.byteLength.toString(),
      'Cache-Control': 'public, max-age=3600',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS', 
      'Access-Control-Allow-Headers': 'Range, Content-Range',
      'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Accept-Ranges'
    }
  });
} 