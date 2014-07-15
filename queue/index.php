<?php header('Content-type: text/html; charset=utf-8'); ?>
<!DOCTYPE html>
<html>
<head>
<title>Akari queue</title>
</head>
<body>

<tt>
<?php

$secs = 20 * 60;
date_default_timezone_set('America/New_York');

function sortFiles($a, $b) {
    return filemtime($a) > filemtime($b);
}

function getWords($filename) {
    $text = base64_decode(basename($filename, '.jpg'));
    $text = $text ? $text : '-----';
    return $text;
}

$files = glob('./*.jpg');
usort($files, 'sortFiles');

$nextTime = ceil( time()/$secs ) * $secs;
foreach($files as $file) { 
    $timestamp = date('m/d/Y h:iA', $nextTime);
    $text = getWords($file);
    echo "[<a href='delete.php?file=$file' onclick=\"return confirm('Delete $text?')\">x</a>] ";
    echo "$timestamp <a href='$file'>$text</a><br/>";
    $nextTime += $secs;
} 
?>
</tt>
</body>
</html>

