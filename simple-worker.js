// 简化版鸿蒙HAP分片下载Worker
// 专门解决206状态码问题

addEventListener('fetch', event => {
  event.respondWith(handleRequest(event.request))
})

async function handleRequest(request) {
  const url = new URL(request.url)
  
  // 如果是根路径，返回欢迎信息
  if (url.pathname === '/') {
    return new Response('🎉 鸿蒙HAP包分发服务运行中！支持Range请求和206状态码', {
      headers: {
        'Content-Type': 'text/plain; charset=utf-8',
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
  
  // GitHub Raw文件基础URL
  const GITHUB_RAW_BASE = 'https://raw.githubusercontent.com/qius-code/hap-distribution/main'
  const githubUrl = GITHUB_RAW_BASE + url.pathname
  
  console.log(`🔗 请求路径: ${url.pathname}`)
  console.log(`📦 GitHub URL: ${githubUrl}`)
  
  // 处理CORS预检
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
    // 先获取完整文件信息
    console.log('📊 获取文件信息...')
    const headResponse = await fetch(githubUrl, { method: 'HEAD' })
    
    if (!headResponse.ok) {
      console.log(`❌ 文件不存在: ${headResponse.status}`)
      return new Response('文件未找到', { 
        status: 404,
        headers: { 'Access-Control-Allow-Origin': '*' }
      })
    }
    
    const totalSize = parseInt(headResponse.headers.get('Content-Length') || '0')
    const contentType = getContentType(url.pathname)
    
    console.log(`📦 文件大小: ${totalSize} bytes`)
    console.log(`📄 文件类型: ${contentType}`)
    
    // 检查是否是Range请求
    const rangeHeader = request.headers.get('Range')
    console.log(`🎯 Range头: ${rangeHeader}`)
    
    if (rangeHeader && rangeHeader.startsWith('bytes=')) {
      // 处理Range请求 - 关键是这里！
      return await handleRangeRequest(githubUrl, rangeHeader, totalSize, contentType)
    } else {
      // 处理完整文件请求
      console.log('📥 处理完整文件请求')
      const response = await fetch(githubUrl)
      
      return new Response(response.body, {
        status: 200,
        headers: {
          'Content-Type': contentType,
          'Content-Length': totalSize.toString(),
          'Accept-Ranges': 'bytes',
          'Access-Control-Allow-Origin': '*',
          'Cache-Control': 'public, max-age=86400'
        }
      })
    }
    
  } catch (error) {
    console.error('💥 错误:', error)
    return new Response('服务器内部错误', { 
      status: 500,
      headers: { 'Access-Control-Allow-Origin': '*' }
    })
  }
}

async function handleRangeRequest(githubUrl, rangeHeader, totalSize, contentType) {
  console.log('🔍 处理Range请求...')
  
  // 解析Range: bytes=start-end
  const rangeMatch = rangeHeader.match(/bytes=(\d*)-(\d*)/)
  if (!rangeMatch) {
    console.log('❌ 无效的Range格式')
    return new Response('Range格式错误', { 
      status: 416,
      headers: {
        'Content-Range': `bytes */${totalSize}`,
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
  
  let start = parseInt(rangeMatch[1]) || 0
  let end = parseInt(rangeMatch[2]) || (totalSize - 1)
  
  // 验证范围
  if (start >= totalSize || end >= totalSize || start > end) {
    console.log(`❌ 无效范围: ${start}-${end}/${totalSize}`)
    return new Response('Range超出范围', { 
      status: 416,
      headers: {
        'Content-Range': `bytes */${totalSize}`,
        'Access-Control-Allow-Origin': '*'
      }
    })
  }
  
  const chunkSize = end - start + 1
  console.log(`✂️  分片范围: ${start}-${end} (${chunkSize} bytes)`)
  
  try {
    // 获取完整文件，然后切片（简单但有效的方法）
    console.log('📥 下载完整文件用于切片...')
    const fullResponse = await fetch(githubUrl)
    const arrayBuffer = await fullResponse.arrayBuffer()
    
    // 提取指定范围的数据
    const chunk = arrayBuffer.slice(start, end + 1)
    console.log(`✅ 成功提取 ${chunk.byteLength} bytes`)
    
    // 返回206响应 - 这是关键！
    return new Response(chunk, {
      status: 206, // Partial Content - 鸿蒙必需！
      headers: {
        'Content-Type': contentType,
        'Content-Length': chunkSize.toString(),
        'Content-Range': `bytes ${start}-${end}/${totalSize}`,
        'Accept-Ranges': 'bytes',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Expose-Headers': 'Content-Length, Content-Range, Accept-Ranges',
        'Cache-Control': 'public, max-age=86400'
      }
    })
    
  } catch (error) {
    console.error('💥 Range请求处理失败:', error)
    return new Response('Range请求处理失败', { 
      status: 500,
      headers: { 'Access-Control-Allow-Origin': '*' }
    })
  }
}

function getContentType(pathname) {
  if (pathname.endsWith('.hap')) {
    return 'application/octet-stream'
  } else if (pathname.endsWith('.json5') || pathname.endsWith('.json')) {
    return 'application/json; charset=utf-8'
  } else if (pathname.endsWith('.png')) {
    return 'image/png'
  } else if (pathname.endsWith('.jpg') || pathname.endsWith('.jpeg')) {
    return 'image/jpeg'
  } else {
    return 'application/octet-stream'
  }
} 