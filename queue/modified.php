<?php header('Content-type: text/html; charset=utf-8'); ?>
<!DOCTYPE html>
<html>
<head>
<title>Akari queue</title>
</head>
<body>

<tt>
<?php

function f($file) {
    $text = base64_decode(basename($file, '.jpg'));
    $text = $text ? $text : '-----';
    $timestamp = date('m/d/Y H:i', filemtime($file));
    return $timestamp . " <a href='$file'>$text</a>";
}


$files = glob('./*.jpg');
$lines = array_map('f', $files);
sort($lines, SORT_STRING);

foreach($lines as $line) { 
    echo $line . '<br/>';
} 
?>
</tt>
</body>
</html>

