<?php
$file = $_GET['file'] ? $_GET['file'] : '';
$file = './' . $file;
if (!file_exists($file))
    die('no such file');
if (pathinfo($file, PATHINFO_EXTENSION) != 'jpg')
    die('not an image');
if (unlink($file))
    header('Location: ' . $_SERVER['HTTP_REFERER']);
else
    echo "failed to delete $file";

