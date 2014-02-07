<?php header('Content-type: text/html; charset=utf-8'); ?>
<!DOCTYPE html>
<html>
<head>
<title>Akari grep</title>
</head>
<body>
<tt>
<?php
$path = '../log/activity.log';
$term = urldecode($_GET['t']);

$pattern = "/$term/i";

// via http://docstore.mik.ua/orelly/webprog/pcook/ch13_07.htm
$fh = fopen($path, 'r') or die($php_errormsg);
while (!feof($fh)) {
    $line = fgets($fh, 4096);
    if (preg_match($pattern, $line)) 
        echo $line . '<br/>';
}
fclose($fh);
?>
</tt>
</body>
</html>

