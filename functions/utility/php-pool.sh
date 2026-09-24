#!/bin/bash

PHP_POOL_DIR="${__DIR__}"
php-pool() {
    php "${PHP_POOL_DIR}/php-pool.php" "$@"
}
