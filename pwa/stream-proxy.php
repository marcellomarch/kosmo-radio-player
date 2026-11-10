<?php
// Lightweight HTTPS audio stream proxy for HTTP-only radio stations on iOS Safari
@ini_set('zlib.output_compression', 'Off');
@ini_set('output_buffering', 'Off');
@set_time_limit(0);

$url = isset($_GET['url']) ? trim($_GET['url']) : '';
if (!$url || !preg_match('#^https?://#i', $url)) {
    http_response_code(400);
    exit('Invalid stream URL');
}

$parsed = parse_url($url);
$host = isset($parsed['host']) ? strtolower($parsed['host']) : '';
// Block local/private network addresses for security (SSRF protection)
if (!$host || $host === 'localhost' || preg_match('/^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.)/', $host)) {
    http_response_code(403);
    exit('Forbidden host');
}

header('Content-Type: audio/mpeg');
header('Cache-Control: no-cache, no-store');
header('Pragma: no-cache');
header('Access-Control-Allow-Origin: *');

$ch = curl_init($url);
curl_setopt_array($ch, [
    CURLOPT_FOLLOWLOCATION => true,
    CURLOPT_MAXREDIRS => 5,
    CURLOPT_TIMEOUT => 0,
    CURLOPT_CONNECTTIMEOUT => 8,
    CURLOPT_USERAGENT => 'KosmoRadio-iOS/1.0',
    CURLOPT_SSL_VERIFYPEER => false,
    CURLOPT_BUFFERSIZE => 8192,
    CURLOPT_WRITEFUNCTION => function($ch, $data) {
        echo $data;
        if (ob_get_level() > 0) {
            @ob_flush();
        }
        flush();
        return connection_aborted() ? 0 : strlen($data);
    }
]);
curl_exec($ch);
curl_close($ch);
