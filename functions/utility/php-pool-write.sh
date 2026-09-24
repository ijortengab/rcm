#!/bin/bash

PHP_POOL_WRITE_DIR="${__DIR__}"
php-pool-write() {
    php "${PHP_POOL_WRITE_DIR}/php-pool-write.php" "$@"
}
