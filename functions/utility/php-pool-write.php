<?php

// The builtin function die() is not write error to stderr, we create
// alternative function named _die().
function _die($string='', $code = 1) {
    fwrite(STDERR, $string.PHP_EOL);
    exit($code);
}

function build_ini_string(array $a) {
    $out = '';
    $sectionless = '';
    foreach($a as $rootkey => $rootvalue){
        if(is_array($rootvalue)){
            // find out if the root-level item is an indexed or associative array
            $indexed_root = array_keys($rootvalue) == range(0, count($rootvalue) - 1);
            // associative arrays at the root level have a section heading
            if(!$indexed_root) $out .= PHP_EOL."[$rootkey]".PHP_EOL;
            // loop through items under a section heading
            foreach($rootvalue as $key => $value){
                if(is_array($value)){
                    // indexed arrays under a section heading will have their key omitted
                    $indexed_item = array_keys($value) == range(0, count($value) - 1);
                    foreach($value as $subkey=>$subvalue){
                        // omit subkey for indexed arrays
                        if($indexed_item) $subkey = "";
                        // add this line under the section heading
                        $out .= "{$key}[$subkey] = $subvalue" . PHP_EOL;
                    }
                } else {
                    if($indexed_root){
                        // root level indexed array becomes sectionless
                        $sectionless .= "{$rootkey}[] = $value" . PHP_EOL;
                    } else {
                        // plain values within root level sections
                        $out .= "$key = $value" . PHP_EOL;
                    }
                }
            }

        } else {
            // root level sectionless values
            $sectionless .= "$rootkey = $rootvalue" . PHP_EOL;
        }
    }
    return $sectionless.$out;
}

function clean(&$array) {
    unset($array['user']);
    unset($array['group']);
    unset($array['listen']);
    unset($array['listen.owner']);
    unset($array['listen.group']);
}

// Reference: https://api.drupal.org/api/drupal/core%21lib%21Drupal%21Component%21Utility%21DiffArray.php/function/DiffArray%3A%3AdiffAssocRecursive/11.x
function array_diff_assoc_recursive(array $array1, array $array2) {
    $difference = [];
    foreach ($array1 as $key => $value) {
        if (is_array($value)) {
            if (!array_key_exists($key, $array2) || !is_array($array2[$key])) {
                $difference[$key] = $value;
            }
            else {
                $new_diff = array_diff_assoc_recursive($value, $array2[$key]);
                if (!empty($new_diff)) {
                    $difference[$key] = $new_diff;
                }
            }
        }
        elseif (!array_key_exists($key, $array2) || $array2[$key] !== $value) {
            $difference[$key] = $value;
        }
    }
    return $difference;
}

$mode = isset($_SERVER['argv'][1]) ? $_SERVER['argv'][1]: null;

$php_version = isset($_SERVER['argv'][2]) ? $_SERVER['argv'][2]: null;

$section_name = isset($_SERVER['argv'][3]) ? $_SERVER['argv'][3]: null;

if (!isset($mode)) {
    _die('Argument <mode> is required.');
}

if (!isset($php_version)) {
    _die('Argument <php_version> is required.');
}

if (!isset($section_name)) {
    _die('Argument <section_name> is required.');
}

switch ($mode) {
    case 'is_different':
    case 'save':

        # Populate variable $is_different.
        $file = isset($_SERVER['argv'][4]) ? $_SERVER['argv'][4]: null;
        $config = parse_ini_file($file, true);
        $additional_config_ini = isset($_SERVER['argv'][5]) ? $_SERVER['argv'][5]: null;
        if (!isset($additional_config_ini)) {
            _die('Argument <additional_config_ini> is required.');
        }
        $additional_config = (array) parse_ini_string($additional_config_ini, true);
        clean($additional_config[$section_name]);
        // Tidak seperti rcm-roundcube-autoinstaller-nginx karena array master
        // hanya tambahan terhadap config utama.
        # $is_different = !empty(array_diff_assoc(array_map('serialize',$array_master_cleaned), array_map('serialize',$config_cleaned)));
        $result = array_diff_assoc_recursive($additional_config[$section_name], $config[$section_name]);
        $is_different = !empty($result);
        break;

    case 'create':
        $config_file = isset($_SERVER['argv'][4]) ? $_SERVER['argv'][4]: null;
        if (!isset($config_file)) {
            _die('Argument <config_file> is required.');
        }
        $default_config_ini = isset($_SERVER['argv'][5]) ? $_SERVER['argv'][5]: null;
        if (!isset($default_config_ini)) {
            _die('Argument <default_config_ini> is required.');
        }
        $additional_config_ini = isset($_SERVER['argv'][6]) ? $_SERVER['argv'][6]: null;
        $is_exists = file_exists($config_file);
        break;
}

switch ($mode) {
    case 'is_different':
        $is_different ? exit(0) : exit(1);
        break;
    case 'save':
        if (!$is_different) {
            exit(0);
        }
        $result_new = array($section_name => $result);
        $config_new = array_replace_recursive($config, $result_new);
        $contents = build_ini_string($config_new);

        file_put_contents($file, $contents);
        break;

    case 'create':
        // Execute.
        $config = (array) parse_ini_string($default_config_ini, true);

        if (isset($additional_config_ini)) {
            $additional_config = (array) parse_ini_string($additional_config_ini, true);
            clean($additional_config[$section_name]);

            // Cleaning.
            $config = array_replace_recursive($config, $additional_config);

        }
        $content = build_ini_string($config);

        if ($is_exists) {
            file_put_contents($config_file, trim($content)."\n", FILE_APPEND);
        }
        else {
            file_put_contents($config_file, trim($content)."\n");
        }
        break;
        ;;
}
