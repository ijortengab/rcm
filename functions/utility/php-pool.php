<?php

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
        ;;
}
