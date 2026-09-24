<?php
// https://stackoverflow.com/questions/17316873/convert-array-to-an-ini-file
// https://stackoverflow.com/a/17317168
function clean($array, &$array_cleaned) {
    $array_cleaned = $array;
    unset($array_cleaned['user']);
    unset($array_cleaned['group']);
    unset($array_cleaned['listen']);
    unset($array_cleaned['listen.owner']);
    unset($array_cleaned['listen.group']);
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
                }else{
                    if($indexed_root){
                        // root level indexed array becomes sectionless
                        $sectionless .= "{$rootkey}[] = $value" . PHP_EOL;
                    }else{
                        // plain values within root level sections
                        $out .= "$key = $value" . PHP_EOL;
                    }
                }
            }

        }else{
            // root level sectionless values
            $sectionless .= "$rootkey = $rootvalue" . PHP_EOL;
        }
    }
    return $sectionless.$out;
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

$mode = $_SERVER['argv'][1];
switch ($mode) {
    case 'is_different':
    case 'save':
        # Populate variable $is_different.
        $file = $_SERVER['argv'][2];
        $config_raw = parse_ini_file($file);
        clean($config_raw, $config_cleaned);
        $array_master_raw = unserialize($_SERVER['argv'][3]);
        clean($array_master_raw, $array_master_cleaned);
        // Tidak seperti rcm-roundcube-autoinstaller-nginx karena array master
        // hanya tambahan terhadap config utama.
        # $is_different = !empty(array_diff_assoc(array_map('serialize',$array_master_cleaned), array_map('serialize',$config_cleaned)));
        array_diff_assoc_recursive($array_master_cleaned, $config_cleaned, $result);
        $is_different = !empty($result);
        break;
    case 'create':
        $file = $_SERVER['argv'][2];
        $default_config = $_SERVER['argv'][3];
        $additional_config = $_SERVER['argv'][4];
        break;
}
switch ($mode) {
    case 'serialized_ini_string':
        // $sites_subdir = $_SERVER['argv'][2];
        $stdin = '';
        while (FALSE !== ($line = fgets(STDIN))) {
           $stdin .= $line;
        }
        $array = parse_ini_string($stdin);
        echo serialize($array);
        break;
    case 'is_different':
        $is_different ? exit(0) : exit(1);
        break;
    case 'save':
        if (!$is_different) {
            exit(0);
        }
        $section_name = $_SERVER['argv'][4];
        $config_new = array_replace_recursive($config_raw, $result);
        $config_new = array( $section_name => $config_new);
        $contents = build_ini_string($config_new);
        file_put_contents($file, $contents);
        break;
    case 'create':
        $file = $_SERVER['argv'][2];
        $section_name = $_SERVER['argv'][3];
        $default_config = $_SERVER['argv'][4];
        $additional_config = $_SERVER['argv'][5];
        $config = unserialize($default_config);
        if (!empty($additional_config)) {
            $additional_config_raw = unserialize($additional_config);
            clean($additional_config_raw, $additional_config);
            $config = array_replace_recursive($config, $additional_config);
        }
        $config = array( $section_name => $config);
        $content = build_ini_string($config);
        file_put_contents($file, trim($content)."\n");
        break;
    case 'is_exists':
        $file = $_SERVER['argv'][2];
        $section_name = $_SERVER['argv'][3];
        if (file_exists($file)) {
            $array = parse_ini_file($file, true);
            if (array_key_exists($section_name, $array)) {
                exit(0);
            }
        }
        exit(1);
        break;
}
