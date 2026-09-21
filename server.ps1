# server.ps1 - MEMORY HACK Mobile Local Server
$port = 8080
$rootDir = $PSScriptRoot

$ip = "192.168.100.40"

Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host " MEMORY HACK Mobile Server Running..." -ForegroundColor Yellow
Write-Host "=========================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " [PC Browser Preview]" -ForegroundColor Green
Write-Host "  URL: http://localhost:$port/index.html" -ForegroundColor White
Write-Host ""
Write-Host " [Android Smartphone URL]" -ForegroundColor Green
Write-Host "  URL: http://$ip`:$port/index.html" -ForegroundColor Yellow
Write-Host ""
Write-Host " To stop server, close this window or press Ctrl+C" -ForegroundColor Gray
Write-Host "-------------------------------------------------------------------------" -ForegroundColor Gray

Start-Process "http://localhost:$port/index.html"

$mimeTypes = @{
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".png"  = "image/png"
    ".ico"  = "image/x-icon"
    ".svg"  = "image/svg+xml"
}

$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $port)

try {
    $listener.Start()
} catch {
    Write-Host "Failed to start port $port : $_" -ForegroundColor Red
    exit 1
}

try {
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()
        $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::ASCII)
        $firstLine = $reader.ReadLine()

        if ([string]::IsNullOrWhiteSpace($firstLine)) {
            $client.Close()
            continue
        }

        $parts = $firstLine -split " "
        if ($parts.Length -lt 2) {
            $client.Close()
            continue
        }

        $rawPath = $parts[1].Split("?")[0]
        if ($rawPath -eq "/" -or $rawPath -eq "") {
            $rawPath = "/index.html"
        }

        $localRelPath = [System.Uri]::UnescapeDataString($rawPath.TrimStart("/")).Replace("/", "\")
        $filePath = Join-Path $rootDir $localRelPath

        if (Test-Path $filePath -PathType Leaf) {
            $ext = [System.IO.Path]::GetExtension($filePath).ToLower()
            $contentType = $mimeTypes[$ext]
            if (-not $contentType) { $contentType = "application/octet-stream" }

            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $header = "HTTP/1.1 200 OK`r`n" +
                      "Content-Type: $contentType`r`n" +
                      "Content-Length: $($bytes.Length)`r`n" +
                      "Access-Control-Allow-Origin: *`r`n" +
                      "Cache-Control: no-cache`r`n" +
                      "Connection: close`r`n`r`n"

            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($bytes, 0, $bytes.Length)
            $stream.Flush()
        } else {
            $msg = [System.Text.Encoding]::UTF8.GetBytes("404 Not Found")
            $header = "HTTP/1.1 404 Not Found`r`n" +
                      "Content-Type: text/plain; charset=utf-8`r`n" +
                      "Content-Length: $($msg.Length)`r`n" +
                      "Connection: close`r`n`r`n"
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
            $stream.Write($headerBytes, 0, $headerBytes.Length)
            $stream.Write($msg, 0, $msg.Length)
            $stream.Flush()
        }
        $client.Close()
    }
} finally {
    $listener.Stop()
}
