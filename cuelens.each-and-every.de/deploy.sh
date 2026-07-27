if vendor/bin/phpunit tests; then
  cp *.html *.js *.css *.php *.pdf /var/www/html/cuelens
  cp -r lib img /var/www/html/cuelens
else
  echo 'Not deploying due to test failures'
fi
