<?php

// The builtin function die() is not write error to stderr, we create
// alternative function named _die().
function _die($string='', $code = 1) {
    fwrite(STDERR, $string.PHP_EOL);
    exit($code);
}

$mode = isset($_SERVER['argv'][1]) ? $_SERVER['argv'][1]: null;

switch ($mode) {
    case 'list':
        $stdin = '';
        while (FALSE !== ($line = fgets(STDIN))) {
           $stdin .= $line;
        }
        $array_master = parse_ini_string($stdin, true);
        $filter_user = isset($_SERVER['argv'][2]) ? $_SERVER['argv'][2]: null;
        if (isset($filter_user)) {
            $array_master = array_filter($array_master, function ($value) use ($filter_user) {
                return isset($value['user']) && $value['user'] == $filter_user;
            });
        }
        unset($array_master['global']);
        $keys = array_keys($array_master);
        foreach ($keys as $key) {
            echo $key.PHP_EOL;
        }
        break;
        ;;

    case 'get-info':
        $pool_name = isset($_SERVER['argv'][2]) ? $_SERVER['argv'][2]: null;
        if (!isset($pool_name)) {
            _die('Argument <pool_name> is required.');
        }
        $key = isset($_SERVER['argv'][3]) ? $_SERVER['argv'][3]: null;
        if (!isset($key)) {
            _die('Argument <key> is required.');
        }
        $stdin = '';
        while (FALSE !== ($line = fgets(STDIN))) {
           $stdin .= $line;
        }
        $array_master = parse_ini_string($stdin, true);
        if (!array_key_exists($pool_name, $array_master)) {
            _die('The pool is not exists: '.$pool_name);
        }
        if (!array_key_exists($key, $array_master[$pool_name])) {
            _die('The key is not exists: '.$key);
        }
        echo $array_master[$pool_name][$key].PHP_EOL;
        break;
        ;;
}
