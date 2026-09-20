#!/usr/bin/env bash
set -u

if php tests/run-local-test-suite.php; then
  scp *.html *.js *.css *.php *.pdf stefan@nas:/var/www/html/cuelens
  scp -r lib img stefan@nas:/var/www/html/cuelens
else
  echo 'Not deploying due to test failures'
fi
