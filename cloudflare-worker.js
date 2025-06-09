// 鸿蒙HAP包分发专用Cloudflare Worker
// 确保Range请求返回206 Partial Content状态码

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = new URL(request.url)
  
  // GitHub Raw文件基础URL
  const GITHUB_RAW_BASE = 'https://raw.githubusercontent.com/qius-code/hap-distribution/main'
  
  // 构建GitHub Raw URL
  const githubUrl = GITHUB_RAW_BASE + url.pathname
  
  console.log(`Request: ${request.method} ${url.pathname}`)
  console.log(`GitHub URL: ${githubUrl}`)
  
  // 处理CORS预检请求
  if (request.method === 'OPTIONS') {
    return new Response(null, {
      status: 200,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
        'Access-Control-Allow-Headers': 'Range, Content-Range, Authorization, Content-Type',
        'Access-Control-Max-Age': '86400',
      }
    })
  }
  
  try {
    // 获取原始请求的Range头
    const rangeHeader = request.headers.get('Range')
    console.log(`Range header: ${rangeHeader}`)
    
    // 构建请求头
    const requestHeaders = new Headers()
    if (rangeHeader) {
      requestHeaders.set('Range', rangeHeader)
    }
    
    // 请求GitHub Raw文件
    const response = await fetch(githubUrl, {
      method: request.method,
      headers: requestHeaders
    })
    
    console.log(`GitHub response status: ${response.status}`)
    
    if (!response.ok) {
      return new Response('File not found', { 
        status: 404,
        headers: {
          'Access-Control-Allow-Origin': '*'
        }
      })
    }
    
    // 获取文件信息
    const contentLength = response.headers.get('Content-Length')
    const contentType = getContentType(url.pathname)
    const totalSize = parseInt(contentLength) || 0
    
    console.log(`Content-Length: ${contentLength}, Content-Type: ${contentType}`)
    
    // 处理Range请求
    if (rangeHeader && rangeHeader.startsWith('bytes=')) {
      return handleRangeRequest(response, rangeHeader, totalSize, contentType)
    }
    
    // 处理完整文件请求
    const responseHeaders = new Headers()
    setCommonHeaders(responseHeaders, contentType)
    responseHeaders.set('Content-Length', contentLength)
    responseHeaders.set('Accept-Ranges', 'bytes')
    
    return new Response(response.body, {
      status: 200,
      headers: responseHeaders
    })
    
  } catch (error) {
    console.error('Error:', error)
    return new Response('Internal Server Error', { 
      status: 500,
      headers: {
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
}

async function handleRangeRequest(response, rangeHeader, totalSize, contentType) {
  // 解析Range头
  const ranges = parseRangeHeader(rangeHeader, totalSize)
  
  if (!ranges || ranges.length === 0) {
    return new Response('Invalid Range', { 
      status: 416,
      headers: {
        'Content-Range': `bytes */${totalSize}`,
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
  
  // 只处理单个range请求（鸿蒙通常使用单个range）
  const range = ranges[0]
  const { start, end } = range
  const chunkSize = end - start + 1
  
  console.log(`Range request: ${start}-${end}/${totalSize} (${chunkSize} bytes)`)
  
  // 读取响应数据
  const arrayBuffer = await response.arrayBuffer()
  const chunk = arrayBuffer.slice(start, end + 1)
  
  // 构建206响应头
  const responseHeaders = new Headers()
  setCommonHeaders(responseHeaders, contentType)
  responseHeaders.set('Content-Length', chunkSize.toString())
  responseHeaders.set('Content-Range', `bytes ${start}-${end}/${totalSize}`)
  responseHeaders.set('Accept-Ranges', 'bytes')
  
  console.log(`Returning 206 with Content-Range: bytes ${start}-${end}/${totalSize}`)
  
  return new Response(chunk, {
    status: 206, // 关键！返回206 Partial Content
    headers: responseHeaders
  })
}

function parseRangeHeader(rangeHeader, totalSize) {
  const ranges = []
  const rangeSpec = rangeHeader.replace('bytes=', '')
  
  for (const range of rangeSpec.split(',')) {
    const [startStr, endStr] = range.trim().split('-')
    
    let start, end
    
    if (startStr === '') {
      // -500 表示最后500字节
      start = Math.max(0, totalSize - parseInt(endStr))
      end = totalSize - 1
    } else if (endStr === '') {
      // 500- 表示从500字节到结尾
      start = parseInt(startStr)
      end = totalSize - 1
    } else {
      // 500-999 表示从500到999字节
      start = parseInt(startStr)
      end = parseInt(endStr)
    }
    
    // 验证范围
    if (start >= 0 && end < totalSize && start <= end) {
      ranges.push({ start, end })
    }
  }
  
  return ranges
}

function getContentType(pathname) {
  if (pathname.endsWith('.hap') || pathname.endsWith('.hsp')) {
    return 'application/octet-stream'
  } else if (pathname.endsWith('.json5') || pathname.endsWith('.json')) {
    return 'application/json; charset=utf-8'
  } else if (pathname.endsWith('.png')) {
    return 'image/png'
  } else if (pathname.endsWith('.jpg') || pathname.endsWith('.jpeg')) {
    return 'image/jpeg'
  } else if (pathname.endsWith('.webp')) {
    return 'image/webp'
  } else {
    return 'application/octet-stream'
  }
}

function setCommonHeaders(headers, contentType) {
  headers.set('Content-Type', contentType)
  headers.set('Access-Control-Allow-Origin', '*')
  headers.set('Access-Control-Allow-Methods', 'GET, HEAD, OPTIONS')
  headers.set('Access-Control-Allow-Headers', 'Range, Content-Range, Authorization, Content-Type')
  headers.set('Access-Control-Expose-Headers', 'Content-Length, Content-Range, Accept-Ranges, Last-Modified')
  headers.set('Cache-Control', 'public, max-age=86400')
  headers.set('X-Content-Type-Options', 'nosniff')
} 