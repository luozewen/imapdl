#!/usr/bin/env python3

# 2017, Georg Sauthoff <mail@gms.tf>

import os
import subprocess
import shutil

ex_path = [ '/usr/include/*', 'unittest/*', 'lib*/*', 'example/*' ]

brflag = ['--rc', 'lcov_branch_coverage=1']

lcov = 'lcov'
base = os.path.abspath('.')

cov_init_raw = 'coverage_init_raw.info'
cov_post_raw = 'coverage_post_raw.info'
cov_init     = 'coverage_init.info'
cov_post     = 'coverage_post.info'
cov          = 'coverage.info'
report_dir   = 'coverage'

def run(*args, **kw):
  print('Executing: ' + ' '.join(map(lambda s:"'"+s+"'", args[0])))
  return subprocess.run(*args, **kw, check=True)

run([lcov, '--directory',  base, '--capture', '-o', cov_post_raw] + brflag )
run([lcov, '--directory',  base, '--capture', '--initial', '-o', cov_init_raw])

for i, o in [ (cov_init_raw, cov_init), (cov_post_raw, cov_post) ]:
  run([lcov, '--remove', i] + ex_path + [ '-o', o] + brflag)

run([lcov, '-a', cov_init, '-a', cov_post, '-o', cov] + brflag)

shutil.rmtree(report_dir, ignore_errors=True)
run(['genhtml', cov, '--branch-coverage', '-o', report_dir])
