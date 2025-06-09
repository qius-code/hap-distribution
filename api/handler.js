import fetch from 'node-fetch';

// Vercel Serverless Function, 支持鸿蒙分片下载
// Author: Gemini

export default async function handler(request, response) {
  const url = new URL(request.url, `http://${request.headers.host}`);
  
  // GitHub Raw文件基础URL
  const GITHUB_RAW_BASE = 'https://raw.githubusercontent.com/qius-code/hap-distribution/main';
  const githubUrl = GITHUB_RAW_BASE + url.pathname;

  console.log(`Request: ${request.method} ${url.pathname}`);
  console.log(`GitHub URL: ${githubUrl}`);

  // 为所有响应设置CORS头
  response.setHeader('Access-Control-Allow-Origin', '*');
  response.setHeader('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS');
  response.setHeader('Access-Control-Allow-Headers', 'Range, Content-Range, Authorization, Content-Type');
  response.setHeader('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges');

  // 处理CORS预检请求
  if (request.method === 'OPTIONS') {
    response.status(204).send('');
    return;
  }
  
  try {
    const rangeHeader = request.headers['range'];
    console.log(`Range header: ${rangeHeader}`);
    
    // 请求GitHub Raw文件
    const fetchResponse = await fetch(githubUrl, {
      method: request.method,
      headers: {
        'Range': rangeHeader || 'bytes=0-'
      }
    });

    console.log(`GitHub response status: ${fetchResponse.status}`);
    
    if (!fetchResponse.ok && fetchResponse.status !== 206) {
      response.status(fetchResponse.status).send('File not found');
      return;
    }
    
    const contentType = getContentType(url.pathname);
    response.setHeader('Content-Type', contentType);
    response.setHeader('Accept-Ranges', 'bytes');
    response.setHeader('Cache-Control', 'public, max-age=86400');

    // 将GitHub的响应头复制到Vercel的响应中
    // 这包括了 Content-Length 和 Content-Range
    fetchResponse.headers.forEach((value, name) => {
      if (['content-length', 'content-range'].includes(name.toLowerCase())) {
        response.setHeader(name, value);
      }
    });

    // 关键一步：设置正确的状态码
    // 如果GitHub返回206，我们也返回206，否则返回200
    response.status(fetchResponse.status);
    
    // 将文件内容流式传输到客户端
    fetchResponse.body.pipe(response);

  } catch (error) {
    console.error('Error:', error);
    response.status(500).send('Internal Server Error');
  }
}

function getContentType(pathname) {
  if (pathname.endsWith('.hap') || pathname.endsWith('.hsp')) {
    return 'application/octet-stream';
  } else if (pathname.endsWith('.json5') || pathname.endsWith('.json')) {
    return 'application/json; charset=utf-8';
  } else if (pathname.endsWith('.png')) {
    return 'image/png';
  } else if (pathname.endsWith('.jpg') || pathname.endsWith('.jpeg')) {
    return 'image/jpeg';
  } else if (pathname.endsWith('.webp')) {
    return 'image/webp';
  } else {
    return 'application/octet-stream';
  }
} 